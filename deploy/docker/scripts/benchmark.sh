#!/bin/bash

# Performance Benchmark Script
# Collects comprehensive performance metrics from the GhostNodes network

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
NODES=("http://localhost:9001" "http://localhost:9002" "http://localhost:9003")
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/ghostnodes_benchmark_$(date +%Y%m%d_%H%M%S)}"

echo -e "${GREEN}=== GhostNodes Performance Benchmark ===${NC}"
echo ""
echo "Configuration:"
echo "  Prometheus: $PROMETHEUS_URL"
echo "  Output directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to query Prometheus
query_prometheus() {
    local query=$1
    local output_file=$2
    
    curl -s "${PROMETHEUS_URL}/api/v1/query?query=${query}" | jq -r '.data.result' > "$output_file"
}

# Function to get metrics from a node
get_node_metrics() {
    local node_url=$1
    local node_name=$2
    
    echo -e "${BLUE}Collecting metrics from ${node_name}${NC}"
    
    # Get raw metrics
    curl -s "${node_url}/metrics" > "${OUTPUT_DIR}/${node_name}_metrics.txt"
    
    # Parse key metrics
    local onion_packets=$(grep 'onion_packets_processed_total' "${OUTPUT_DIR}/${node_name}_metrics.txt" | awk '{print $2}' || echo "0")
    local onion_errors=$(grep 'onion_packets_errors_total' "${OUTPUT_DIR}/${node_name}_metrics.txt" | awk '{print $2}' || echo "0")
    local swarm_messages=$(grep 'swarm_messages_stored_total' "${OUTPUT_DIR}/${node_name}_metrics.txt" | awk '{print $2}' || echo "0")
    local swarm_retrieved=$(grep 'swarm_messages_retrieved_total' "${OUTPUT_DIR}/${node_name}_metrics.txt" | awk '{print $2}' || echo "0")
    
    echo "  Onion packets processed: ${onion_packets}"
    echo "  Onion errors: ${onion_errors}"
    echo "  Messages stored: ${swarm_messages}"
    echo "  Messages retrieved: ${swarm_retrieved}"
    echo ""
}

# Function to get Docker stats
get_docker_stats() {
    echo -e "${BLUE}Collecting Docker resource usage${NC}"
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo "  Docker not available, skipping resource stats"
        return
    fi
    
    # Get stats (one iteration)
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" \
        > "${OUTPUT_DIR}/docker_stats.txt" 2>/dev/null || echo "  Docker stats not available"
    
    if [ -f "${OUTPUT_DIR}/docker_stats.txt" ]; then
        cat "${OUTPUT_DIR}/docker_stats.txt"
    fi
    echo ""
}

# Function to calculate response time percentiles
benchmark_latency() {
    local node_url=$1
    local node_name=$2
    local endpoint=$3
    local iterations=100
    
    echo -e "${BLUE}Benchmarking latency for ${node_name} ${endpoint}${NC}"
    
    local latencies_file="${OUTPUT_DIR}/${node_name}_${endpoint}_latencies.txt"
    > "$latencies_file"  # Clear file
    
    for i in $(seq 1 $iterations); do
        local start=$(date +%s%N)
        curl -s -o /dev/null "${node_url}${endpoint}"
        local end=$(date +%s%N)
        local latency=$(( (end - start) / 1000000 ))  # Convert to ms
        echo "$latency" >> "$latencies_file"
    done
    
    # Calculate percentiles
    sort -n "$latencies_file" > "${latencies_file}.sorted"
    local count=$iterations
    local p50_idx=$((count / 2))
    local p95_idx=$((count * 95 / 100))
    local p99_idx=$((count * 99 / 100))
    
    local p50=$(sed -n "${p50_idx}p" "${latencies_file}.sorted")
    local p95=$(sed -n "${p95_idx}p" "${latencies_file}.sorted")
    local p99=$(sed -n "${p99_idx}p" "${latencies_file}.sorted")
    local min=$(head -1 "${latencies_file}.sorted")
    local max=$(tail -1 "${latencies_file}.sorted")
    local mean=$(awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; else print 0 }' "$latencies_file")
    
    echo "  Min: ${min} ms"
    echo "  Mean: ${mean} ms"
    echo "  P50: ${p50} ms"
    echo "  P95: ${p95} ms"
    echo "  P99: ${p99} ms"
    echo "  Max: ${max} ms"
    echo ""
    
    # Save summary
    cat >> "${OUTPUT_DIR}/latency_summary.txt" <<EOF
${node_name} ${endpoint}:
  Min: ${min} ms
  Mean: ${mean} ms
  P50: ${p50} ms
  P95: ${p95} ms
  P99: ${p99} ms
  Max: ${max} ms

EOF
}

# Function to test throughput
benchmark_throughput() {
    local node_url=$1
    local node_name=$2
    local duration=30
    
    echo -e "${BLUE}Benchmarking throughput for ${node_name} (${duration}s test)${NC}"
    
    local count=0
    local start=$(date +%s)
    local end=$((start + duration))
    
    while [ $(date +%s) -lt $end ]; do
        curl -s -o /dev/null "${node_url}/health" && count=$((count + 1))
    done
    
    local actual_duration=$(($(date +%s) - start))
    local rps=$((count / actual_duration))
    
    echo "  Requests: ${count}"
    echo "  Duration: ${actual_duration} seconds"
    echo "  Throughput: ${rps} req/s"
    echo ""
    
    # Save to summary
    echo "${node_name}: ${rps} req/s" >> "${OUTPUT_DIR}/throughput_summary.txt"
}

# Main benchmark execution
echo -e "${GREEN}Starting benchmark...${NC}"
echo ""

# 1. Collect current metrics from all nodes
echo -e "${YELLOW}=== Node Metrics ===${NC}"
for i in "${!NODES[@]}"; do
    node_url="${NODES[$i]}"
    node_name="node$((i+1))"
    get_node_metrics "$node_url" "$node_name"
done

# 2. Collect Docker stats
echo -e "${YELLOW}=== Resource Usage ===${NC}"
get_docker_stats

# 3. Benchmark latency
echo -e "${YELLOW}=== Latency Benchmarks ===${NC}"
> "${OUTPUT_DIR}/latency_summary.txt"
for i in "${!NODES[@]}"; do
    node_url="${NODES[$i]}"
    node_name="node$((i+1))"
    benchmark_latency "$node_url" "$node_name" "/health"
done

# 4. Benchmark throughput
echo -e "${YELLOW}=== Throughput Benchmarks ===${NC}"
> "${OUTPUT_DIR}/throughput_summary.txt"
for i in "${!NODES[@]}"; do
    node_url="${NODES[$i]}"
    node_name="node$((i+1))"
    benchmark_throughput "$node_url" "$node_name"
done

# 5. Check Prometheus metrics (if available)
echo -e "${YELLOW}=== Prometheus Metrics ===${NC}"
if curl -s "${PROMETHEUS_URL}/api/v1/query?query=up" > /dev/null 2>&1; then
    echo "Querying Prometheus for historical metrics..."
    
    # Query some key metrics
    query_prometheus "rate(onion_packets_processed_total[5m])" "${OUTPUT_DIR}/onion_rate.json"
    query_prometheus "rate(swarm_messages_stored_total[5m])" "${OUTPUT_DIR}/swarm_store_rate.json"
    query_prometheus "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))" "${OUTPUT_DIR}/http_p95.json"
    
    echo "  Metrics saved to ${OUTPUT_DIR}/*.json"
else
    echo "  Prometheus not available or not responding"
fi
echo ""

# 6. Generate summary report
echo -e "${GREEN}=== Benchmark Summary ===${NC}"
echo ""

cat > "${OUTPUT_DIR}/REPORT.md" <<'EOF'
# GhostNodes Performance Benchmark Report

## Test Configuration

- Date: $(date)
- Nodes: 3 (local Docker network)
- Test Duration: Various (see individual tests)

## Latency Results

EOF

cat "${OUTPUT_DIR}/latency_summary.txt" >> "${OUTPUT_DIR}/REPORT.md"

cat >> "${OUTPUT_DIR}/REPORT.md" <<'EOF'

## Throughput Results

EOF

cat "${OUTPUT_DIR}/throughput_summary.txt" >> "${OUTPUT_DIR}/REPORT.md"

cat >> "${OUTPUT_DIR}/REPORT.md" <<'EOF'

## Resource Usage

EOF

if [ -f "${OUTPUT_DIR}/docker_stats.txt" ]; then
    echo '```' >> "${OUTPUT_DIR}/REPORT.md"
    cat "${OUTPUT_DIR}/docker_stats.txt" >> "${OUTPUT_DIR}/REPORT.md"
    echo '```' >> "${OUTPUT_DIR}/REPORT.md"
fi

cat >> "${OUTPUT_DIR}/REPORT.md" <<'EOF'

## Performance Targets Comparison

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Message latency (p95, 3-hop) | < 1000ms | See latency results | TBD |
| Throughput per node | 1000 msg/s | See throughput results | TBD |
| Node availability | 99.9% | Manual check required | TBD |

## Recommendations

Based on the benchmark results:

1. Review latency percentiles - optimize if P95 > 1000ms
2. Check throughput - scale if needed
3. Monitor resource usage - optimize if CPU/memory high
4. Review error rates in metrics files

## Raw Data

All raw metrics and data are available in this directory:
- `*_metrics.txt` - Prometheus metrics from each node
- `*_latencies.txt` - Raw latency measurements
- `docker_stats.txt` - Docker resource usage
- `*.json` - Prometheus query results

EOF

echo "Benchmark report generated: ${OUTPUT_DIR}/REPORT.md"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  Latency summary: ${OUTPUT_DIR}/latency_summary.txt"
echo "  Throughput summary: ${OUTPUT_DIR}/throughput_summary.txt"
echo "  Full report: ${OUTPUT_DIR}/REPORT.md"
echo ""
echo -e "${GREEN}Benchmark completed successfully!${NC}"
echo "All results saved to: $OUTPUT_DIR"
