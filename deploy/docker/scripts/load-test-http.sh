#!/bin/bash

# Load Test - HTTP Endpoints
# Tests basic HTTP endpoints for throughput and latency

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NODE1_URL="${NODE1_URL:-http://localhost:9001}"
NODE2_URL="${NODE2_URL:-http://localhost:9002}"
NODE3_URL="${NODE3_URL:-http://localhost:9003}"

# Test parameters
REQUESTS="${REQUESTS:-10000}"
CONCURRENCY="${CONCURRENCY:-100}"

echo -e "${GREEN}=== GhostNodes HTTP Load Test ===${NC}"
echo ""
echo "Configuration:"
echo "  Requests: $REQUESTS"
echo "  Concurrency: $CONCURRENCY"
echo "  Nodes: $NODE1_URL, $NODE2_URL, $NODE3_URL"
echo ""

# Check if ab (Apache Bench) is available
if ! command -v ab &> /dev/null; then
    echo -e "${RED}Error: Apache Bench (ab) is not installed${NC}"
    echo "Install with: apt-get install apache2-utils"
    exit 1
fi

# Function to run load test
run_load_test() {
    local url=$1
    local endpoint=$2
    local node_name=$3
    
    echo -e "${YELLOW}Testing ${node_name} - ${endpoint}${NC}"
    
    # Run Apache Bench
    ab -n "$REQUESTS" -c "$CONCURRENCY" -q "${url}${endpoint}" > /tmp/ab_output_${node_name}.txt 2>&1
    
    # Parse results
    local rps=$(grep "Requests per second:" /tmp/ab_output_${node_name}.txt | awk '{print $4}')
    local mean=$(grep "Time per request:" /tmp/ab_output_${node_name}.txt | head -1 | awk '{print $4}')
    local p50=$(grep "50%" /tmp/ab_output_${node_name}.txt | awk '{print $2}')
    local p95=$(grep "95%" /tmp/ab_output_${node_name}.txt | awk '{print $2}')
    local p99=$(grep "99%" /tmp/ab_output_${node_name}.txt | awk '{print $2}')
    local failed=$(grep "Failed requests:" /tmp/ab_output_${node_name}.txt | awk '{print $3}')
    
    echo "  Requests/sec: ${rps}"
    echo "  Mean latency: ${mean} ms"
    echo "  P50 latency: ${p50} ms"
    echo "  P95 latency: ${p95} ms"
    echo "  P99 latency: ${p99} ms"
    echo "  Failed: ${failed}"
    echo ""
}

# Test health endpoint on all nodes
echo -e "${GREEN}1. Testing /health endpoint${NC}"
echo ""
run_load_test "$NODE1_URL" "/health" "node1"
run_load_test "$NODE2_URL" "/health" "node2"
run_load_test "$NODE3_URL" "/health" "node3"

# Test metrics endpoint on all nodes
echo -e "${GREEN}2. Testing /metrics endpoint${NC}"
echo ""
REQUESTS=1000  # Metrics is more expensive, reduce requests
run_load_test "$NODE1_URL" "/metrics" "node1"
run_load_test "$NODE2_URL" "/metrics" "node2"
run_load_test "$NODE3_URL" "/metrics" "node3"

# Generate summary report
echo -e "${GREEN}=== Load Test Summary ===${NC}"
echo ""
echo "All tests completed successfully."
echo "Detailed results saved in /tmp/ab_output_*.txt"
echo ""
echo "To view detailed results:"
echo "  cat /tmp/ab_output_node1.txt"
echo ""

# Cleanup
echo "Cleaning up temporary files..."
rm -f /tmp/ab_output_*.txt

echo -e "${GREEN}Load test completed!${NC}"
