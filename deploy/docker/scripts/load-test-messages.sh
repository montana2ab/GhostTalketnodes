#!/bin/bash

# Load Test - Message Flow
# Tests realistic message store and retrieve cycles

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NODE1_URL="${NODE1_URL:-http://localhost:9001}"
NODE2_URL="${NODE2_URL:-http://localhost:9002}"
NODE3_URL="${NODE3_URL:-http://localhost:9003}"

# Test parameters
NUM_MESSAGES="${NUM_MESSAGES:-1000}"
CONCURRENT_SENDERS="${CONCURRENT_SENDERS:-10}"
SESSION_ID="test_session_$(date +%s)"

echo -e "${GREEN}=== GhostNodes Message Flow Load Test ===${NC}"
echo ""
echo "Configuration:"
echo "  Messages: $NUM_MESSAGES"
echo "  Concurrent senders: $CONCURRENT_SENDERS"
echo "  Session ID: $SESSION_ID"
echo "  Nodes: $NODE1_URL, $NODE2_URL, $NODE3_URL"
echo ""

# Check dependencies
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    exit 1
fi

# Create test data directory
TEST_DIR="/tmp/ghostnodes_load_test_$$"
mkdir -p "$TEST_DIR"

# Generate test messages
generate_message() {
    local msg_id=$1
    local timestamp=$(date +%s)
    
    cat <<EOF
{
  "id": "msg_${msg_id}_${timestamp}",
  "session_id": "${SESSION_ID}",
  "payload": "$(echo "Test message ${msg_id}" | base64)",
  "timestamp": ${timestamp},
  "type": "text"
}
EOF
}

# Store a single message
store_message() {
    local node_url=$1
    local message=$2
    local msg_id=$3
    
    local start=$(date +%s%N)
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$message" \
        "${node_url}/v1/swarm/messages" \
        -w "\n%{http_code}" 2>/dev/null)
    local end=$(date +%s%N)
    
    local http_code=$(echo "$response" | tail -1)
    local latency=$(( (end - start) / 1000000 )) # Convert to ms
    
    echo "${msg_id},${http_code},${latency}" >> "${TEST_DIR}/store_results.csv"
    
    if [ "$http_code" != "201" ]; then
        echo "ERROR,${msg_id},${http_code}" >> "${TEST_DIR}/errors.log"
    fi
}

# Retrieve messages
retrieve_messages() {
    local node_url=$1
    local session_id=$2
    
    local start=$(date +%s%N)
    local response=$(curl -s -X GET \
        "${node_url}/v1/swarm/messages/${session_id}" \
        -w "\n%{http_code}" 2>/dev/null)
    local end=$(date +%s%N)
    
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | head -n -1)
    local latency=$(( (end - start) / 1000000 )) # Convert to ms
    
    local count=0
    if [ "$http_code" = "200" ]; then
        count=$(echo "$body" | jq '. | length' 2>/dev/null || echo "0")
    fi
    
    echo "${http_code},${latency},${count}"
}

# Phase 1: Store messages
echo -e "${BLUE}Phase 1: Storing ${NUM_MESSAGES} messages${NC}"
echo "msg_id,http_code,latency_ms" > "${TEST_DIR}/store_results.csv"

# Distribute messages across nodes
nodes=("$NODE1_URL" "$NODE2_URL" "$NODE3_URL")
node_idx=0

store_count=0
for i in $(seq 1 $NUM_MESSAGES); do
    # Select node in round-robin fashion
    node_url=${nodes[$node_idx]}
    node_idx=$(( (node_idx + 1) % 3 ))
    
    # Generate and store message
    message=$(generate_message $i)
    store_message "$node_url" "$message" $i &
    
    # Limit concurrent processes
    if [ $(( i % CONCURRENT_SENDERS )) -eq 0 ]; then
        wait
        store_count=$i
        echo -ne "\r  Stored: ${store_count}/${NUM_MESSAGES} messages"
    fi
done
wait
echo -ne "\r  Stored: ${NUM_MESSAGES}/${NUM_MESSAGES} messages\n"

# Analyze store results
echo ""
echo -e "${YELLOW}Store Phase Results:${NC}"
total_stored=$(wc -l < "${TEST_DIR}/store_results.csv")
total_stored=$((total_stored - 1))  # Subtract header
successful=$(grep -c ",201," "${TEST_DIR}/store_results.csv" || echo "0")
failed=$((total_stored - successful))

# Calculate latency stats
tail -n +2 "${TEST_DIR}/store_results.csv" | cut -d',' -f3 | sort -n > "${TEST_DIR}/latencies.txt"
p50_line=$((total_stored / 2))
p95_line=$((total_stored * 95 / 100))
p99_line=$((total_stored * 99 / 100))

p50=$(sed -n "${p50_line}p" "${TEST_DIR}/latencies.txt")
p95=$(sed -n "${p95_line}p" "${TEST_DIR}/latencies.txt")
p99=$(sed -n "${p99_line}p" "${TEST_DIR}/latencies.txt")
mean=$(awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; else print 0 }' "${TEST_DIR}/latencies.txt")

echo "  Total messages: ${total_stored}"
echo "  Successful: ${successful}"
echo "  Failed: ${failed}"
echo "  Mean latency: ${mean} ms"
echo "  P50 latency: ${p50} ms"
echo "  P95 latency: ${p95} ms"
echo "  P99 latency: ${p99} ms"

# Phase 2: Wait for replication
echo ""
echo -e "${BLUE}Phase 2: Waiting for message replication (5 seconds)${NC}"
sleep 5

# Phase 3: Retrieve messages
echo ""
echo -e "${BLUE}Phase 3: Retrieving messages from all nodes${NC}"

echo "Retrieving from Node 1..."
result1=$(retrieve_messages "$NODE1_URL" "$SESSION_ID")
http_code1=$(echo "$result1" | cut -d',' -f1)
latency1=$(echo "$result1" | cut -d',' -f2)
count1=$(echo "$result1" | cut -d',' -f3)

echo "Retrieving from Node 2..."
result2=$(retrieve_messages "$NODE2_URL" "$SESSION_ID")
http_code2=$(echo "$result2" | cut -d',' -f1)
latency2=$(echo "$result2" | cut -d',' -f2)
count2=$(echo "$result2" | cut -d',' -f3)

echo "Retrieving from Node 3..."
result3=$(retrieve_messages "$NODE3_URL" "$SESSION_ID")
http_code3=$(echo "$result3" | cut -d',' -f1)
latency3=$(echo "$result3" | cut -d',' -f2)
count3=$(echo "$result3" | cut -d',' -f3)

echo ""
echo -e "${YELLOW}Retrieve Phase Results:${NC}"
echo "  Node 1: HTTP ${http_code1}, ${count1} messages, ${latency1} ms"
echo "  Node 2: HTTP ${http_code2}, ${count2} messages, ${latency2} ms"
echo "  Node 3: HTTP ${http_code3}, ${count3} messages, ${latency3} ms"

# Calculate throughput
echo ""
echo -e "${GREEN}=== Overall Results ===${NC}"

# Calculate duration from timestamps in CSV
first_time=$(head -2 "${TEST_DIR}/store_results.csv" | tail -1 | cut -d',' -f1 | sed 's/msg_//' | cut -d'_' -f2)
last_time=$(tail -1 "${TEST_DIR}/store_results.csv" | cut -d',' -f1 | sed 's/msg_//' | cut -d'_' -f2)
duration=$((last_time - first_time + 1))

if [ "$duration" -gt 0 ]; then
    throughput=$((successful / duration))
    echo "  Duration: ${duration} seconds"
    echo "  Throughput: ${throughput} msg/s"
else
    echo "  Duration: < 1 second"
    echo "  Throughput: Very high (${successful} messages)"
fi

echo "  Success rate: $(awk "BEGIN {printf \"%.2f%%\", ($successful / $total_stored * 100)}")"
echo "  Mean store latency: ${mean} ms"
echo "  P95 store latency: ${p95} ms"

# Check against targets
echo ""
echo -e "${YELLOW}Performance Targets:${NC}"
if [ "$p95" -lt 1000 ]; then
    echo -e "  ${GREEN}✓${NC} P95 latency < 1000ms (target met)"
else
    echo -e "  ${RED}✗${NC} P95 latency >= 1000ms (target not met)"
fi

if [ "${throughput:-0}" -ge 100 ]; then
    echo -e "  ${GREEN}✓${NC} Throughput >= 100 msg/s (target met)"
else
    echo -e "  ${YELLOW}!${NC} Throughput < 100 msg/s (acceptable for test)"
fi

# Cleanup
echo ""
echo "Cleaning up test data..."
rm -rf "$TEST_DIR"

echo -e "${GREEN}Message flow load test completed!${NC}"
