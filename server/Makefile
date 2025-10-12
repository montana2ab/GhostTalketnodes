.PHONY: build test lint clean docker run

BINARY_NAME=ghostnodes
DOCKER_IMAGE=ghostnodes
VERSION?=1.0.0

all: lint test build

build:
	@echo "Building $(BINARY_NAME)..."
	go build -o bin/$(BINARY_NAME) -ldflags="-X main.Version=$(VERSION)" ./cmd/ghostnodes

test:
	@echo "Running tests..."
	go test -v -race -cover ./...

test-coverage:
	@echo "Running tests with coverage..."
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

lint:
	@echo "Running linters..."
	@which golangci-lint > /dev/null 2>&1 || (echo "golangci-lint not installed. Run: curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin" && exit 1)
	golangci-lint run ./...

fmt:
	@echo "Formatting code..."
	go fmt ./...
	goimports -w .

vet:
	@echo "Running go vet..."
	go vet ./...

clean:
	@echo "Cleaning..."
	rm -rf bin/
	rm -f coverage.out coverage.html

docker:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE):$(VERSION) -t $(DOCKER_IMAGE):latest .

docker-run:
	docker run -p 9000:9000 -v $(PWD)/config.yaml:/etc/ghostnodes/config.yaml $(DOCKER_IMAGE):latest

run:
	@echo "Running $(BINARY_NAME)..."
	go run ./cmd/ghostnodes --config config.yaml

deps:
	@echo "Downloading dependencies..."
	go mod download
	go mod verify

tidy:
	@echo "Tidying go.mod..."
	go mod tidy

install:
	@echo "Installing $(BINARY_NAME)..."
	go install ./cmd/ghostnodes

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build          - Build the binary"
	@echo "  test           - Run tests"
	@echo "  test-coverage  - Run tests with coverage report"
	@echo "  lint           - Run linters"
	@echo "  fmt            - Format code"
	@echo "  vet            - Run go vet"
	@echo "  clean          - Clean build artifacts"
	@echo "  docker         - Build Docker image"
	@echo "  docker-run     - Run Docker container"
	@echo "  run            - Run locally"
	@echo "  deps           - Download dependencies"
	@echo "  tidy           - Tidy go.mod"
	@echo "  install        - Install binary"
