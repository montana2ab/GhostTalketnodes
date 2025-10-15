package mtls

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

// Client provides mutual TLS communication between nodes
type Client struct {
	httpClient *http.Client
	config     *Config
}

// Config holds mTLS configuration
type Config struct {
	CAFile   string // Path to CA certificate
	CertFile string // Path to client certificate
	KeyFile  string // Path to client private key
	Timeout  time.Duration
}

// NewClient creates a new mTLS client for inter-node communication
func NewClient(config *Config) (*Client, error) {
	if config == nil {
		return nil, fmt.Errorf("config cannot be nil")
	}

	// Load CA certificate
	caCert, err := os.ReadFile(config.CAFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read CA certificate: %w", err)
	}

	caCertPool := x509.NewCertPool()
	if !caCertPool.AppendCertsFromPEM(caCert) {
		return nil, fmt.Errorf("failed to append CA certificate")
	}

	// Load client certificate and key
	cert, err := tls.LoadX509KeyPair(config.CertFile, config.KeyFile)
	if err != nil {
		return nil, fmt.Errorf("failed to load client certificate: %w", err)
	}

	// Configure TLS
	tlsConfig := &tls.Config{
		RootCAs:      caCertPool,
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS13,
		CipherSuites: []uint16{
			tls.TLS_CHACHA20_POLY1305_SHA256,
			tls.TLS_AES_256_GCM_SHA384,
			tls.TLS_AES_128_GCM_SHA256,
		},
	}

	// Set default timeout if not specified
	timeout := config.Timeout
	if timeout == 0 {
		timeout = 30 * time.Second
	}

	// Create HTTP client with mTLS
	httpClient := &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			TLSClientConfig:     tlsConfig,
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 10,
			IdleConnTimeout:     90 * time.Second,
		},
	}

	return &Client{
		httpClient: httpClient,
		config:     config,
	}, nil
}

// ForwardPacket forwards an onion packet to another node
func (c *Client) ForwardPacket(nodeAddress string, packet []byte) error {
	url := fmt.Sprintf("https://%s/v1/onion", nodeAddress)
	
	resp, err := c.httpClient.Post(url, "application/octet-stream", 
		&byteReader{data: packet})
	if err != nil {
		return fmt.Errorf("failed to forward packet: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("forwarding failed with status %d: %s", 
			resp.StatusCode, string(body))
	}

	return nil
}

// ReplicateMessage sends a message to another node for replication
func (c *Client) ReplicateMessage(nodeAddress string, messageData []byte) error {
	url := fmt.Sprintf("https://%s/v1/swarm/replicate", nodeAddress)
	
	resp, err := c.httpClient.Post(url, "application/json", 
		&byteReader{data: messageData})
	if err != nil {
		return fmt.Errorf("failed to replicate message: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("replication failed with status %d: %s", 
			resp.StatusCode, string(body))
	}

	return nil
}

// HealthCheck checks if a node is healthy
func (c *Client) HealthCheck(nodeAddress string) error {
	url := fmt.Sprintf("https://%s/health", nodeAddress)
	
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return fmt.Errorf("health check failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("node unhealthy: status %d", resp.StatusCode)
	}

	return nil
}

// Close closes the client and cleans up resources
func (c *Client) Close() error {
	c.httpClient.CloseIdleConnections()
	return nil
}

// byteReader is a simple io.Reader for byte slices
type byteReader struct {
	data []byte
	pos  int
}

func (r *byteReader) Read(p []byte) (n int, err error) {
	if r.pos >= len(r.data) {
		return 0, io.EOF
	}
	n = copy(p, r.data[r.pos:])
	r.pos += n
	return n, nil
}
