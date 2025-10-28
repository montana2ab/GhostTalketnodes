# Multi-stage build for GhostNodes

# Stage 1: Build
FROM golang:1.21-alpine AS builder

# Install dependencies
RUN apk add --no-cache git make gcc musl-dev

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.Version=1.0.0 -X main.BuildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -o ghostnodes \
    ./cmd/ghostnodes

# Stage 2: Runtime
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata wget

# Create non-root user
RUN addgroup -g 1000 ghostnodes && \
    adduser -D -u 1000 -G ghostnodes ghostnodes

# Create directories
RUN mkdir -p /etc/ghostnodes/keys /etc/ghostnodes/certs \
    /var/lib/ghostnodes/data /var/log/ghostnodes && \
    chown -R ghostnodes:ghostnodes /etc/ghostnodes /var/lib/ghostnodes /var/log/ghostnodes

# Copy binary from builder
COPY --from=builder /build/ghostnodes /usr/local/bin/ghostnodes
RUN chmod +x /usr/local/bin/ghostnodes

# Copy default config
COPY config.yaml /etc/ghostnodes/config.yaml
RUN chown ghostnodes:ghostnodes /etc/ghostnodes/config.yaml

# Switch to non-root user
USER ghostnodes

# Expose ports
EXPOSE 9000 9090

# Set working directory
WORKDIR /var/lib/ghostnodes

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9000/health || exit 1

# Run
ENTRYPOINT ["/usr/local/bin/ghostnodes"]
CMD ["--config", "/etc/ghostnodes/config.yaml"]
