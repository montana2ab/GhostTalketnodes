#!/bin/bash
set -e

# Setup script for GhostNodes local test network
# This script generates:
# - Node private keys
# - mTLS CA certificate
# - mTLS node certificates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
NODES_DIR="$DEPLOY_DIR/nodes"

echo "=== GhostNodes Local Test Network Setup ==="
echo ""

# Check if Go is installed (needed for key generation)
if ! command -v go &> /dev/null; then
    echo "Error: Go is required but not installed."
    echo "Please install Go 1.21+ and try again."
    exit 1
fi

# Check if openssl is installed (needed for certificate generation)
if ! command -v openssl &> /dev/null; then
    echo "Error: OpenSSL is required but not installed."
    exit 1
fi

echo "Step 1: Generating node private keys..."
for node in node1 node2 node3; do
    KEY_DIR="$NODES_DIR/$node/keys"
    mkdir -p "$KEY_DIR"
    
    if [ -f "$KEY_DIR/$node.key" ]; then
        echo "  - $node.key already exists, skipping"
    else
        # Generate Ed25519 private key using OpenSSL
        # Note: For production, use the actual GhostNodes key generation utility
        openssl genpkey -algorithm Ed25519 -out "$KEY_DIR/$node.key" 2>/dev/null || {
            # Fallback to random hex for compatibility
            openssl rand -hex 32 > "$KEY_DIR/$node.key"
        }
        echo "  - Generated $node.key"
    fi
done

echo ""
echo "Step 2: Generating mTLS certificates..."

# Generate CA private key and certificate
echo "  - Generating CA certificate..."
CERT_DIR="$NODES_DIR/node1/certs"
mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_DIR/ca.key" ]; then
    openssl genrsa -out "$CERT_DIR/ca.key" 4096
    openssl req -new -x509 -days 3650 -key "$CERT_DIR/ca.key" -out "$CERT_DIR/ca.crt" \
        -subj "/C=US/ST=State/L=City/O=GhostNodes/CN=GhostNodes CA"
    echo "    ✓ CA certificate generated"
else
    echo "    - CA certificate already exists"
fi

# Generate node certificates
for node in node1 node2 node3; do
    CERT_DIR="$NODES_DIR/$node/certs"
    mkdir -p "$CERT_DIR"
    
    # Copy CA cert to all nodes (skip if same directory)
    if [ -f "$NODES_DIR/node1/certs/ca.crt" ] && [ "$node" != "node1" ]; then
        cp "$NODES_DIR/node1/certs/ca.crt" "$CERT_DIR/" 
    fi
    
    if [ ! -f "$CERT_DIR/$node.key" ]; then
        echo "  - Generating certificate for $node..."
        
        # Generate private key
        openssl genrsa -out "$CERT_DIR/$node.key" 2048
        
        # Generate CSR
        openssl req -new -key "$CERT_DIR/$node.key" -out "$CERT_DIR/$node.csr" \
            -subj "/C=US/ST=State/L=City/O=GhostNodes/CN=$node"
        
        # Sign with CA
        openssl x509 -req -in "$CERT_DIR/$node.csr" \
            -CA "$NODES_DIR/node1/certs/ca.crt" \
            -CAkey "$NODES_DIR/node1/certs/ca.key" \
            -CAcreateserial -out "$CERT_DIR/$node.crt" \
            -days 365 -sha256
        
        # Clean up CSR
        rm "$CERT_DIR/$node.csr"
        
        echo "    ✓ Certificate for $node generated"
    else
        echo "    - Certificate for $node already exists"
    fi
done

echo ""
echo "Step 3: Setting permissions..."
chmod 600 "$NODES_DIR"/*/keys/* 2>/dev/null || true
chmod 600 "$NODES_DIR"/*/certs/*.key 2>/dev/null || true
chmod 644 "$NODES_DIR"/*/certs/*.crt 2>/dev/null || true

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "To start the network:"
echo "  cd $DEPLOY_DIR"
echo "  docker compose up -d"
echo ""
echo "To check node health:"
echo "  curl http://localhost:9001/health  # node1"
echo "  curl http://localhost:9002/health  # node2"
echo "  curl http://localhost:9003/health  # node3"
echo ""
echo "To view logs:"
echo "  docker compose logs -f"
echo ""
echo "To stop the network:"
echo "  docker compose down"
echo ""
echo "Monitoring:"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana: http://localhost:3000 (admin/admin)"
echo ""
