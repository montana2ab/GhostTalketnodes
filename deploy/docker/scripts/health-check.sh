#!/bin/bash

# Health check script for GhostNodes local test network

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== GhostNodes Health Check ==="
echo ""

check_node() {
    local node_name=$1
    local port=$2
    
    echo -n "Checking $node_name (port $port)... "
    
    response=$(curl -s -w "\n%{http_code}" http://localhost:$port/health 2>/dev/null)
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        echo "✓ Healthy"
        if [ -n "$body" ]; then
            echo "  Response: $body"
        fi
        return 0
    else
        echo "✗ Unhealthy (HTTP $http_code)"
        return 1
    fi
}

all_healthy=true

check_node "Node 1" 9001 || all_healthy=false
check_node "Node 2" 9002 || all_healthy=false
check_node "Node 3" 9003 || all_healthy=false

echo ""

if [ "$all_healthy" = true ]; then
    echo "Status: All nodes are healthy ✓"
    exit 0
else
    echo "Status: Some nodes are unhealthy ✗"
    exit 1
fi
