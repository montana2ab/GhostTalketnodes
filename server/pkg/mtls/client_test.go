package mtls

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"
)

func setupTestCerts(t *testing.T) (string, string, string, string) {
	tmpDir := t.TempDir()

	// Generate CA
	caCert, caKey, err := GenerateCA(&CertConfig{
		Organization: "Test",
		CommonName:   "Test CA",
		ValidFor:     24 * time.Hour,
	})
	if err != nil {
		t.Fatalf("Failed to generate CA: %v", err)
	}

	// Save CA
	caFile := filepath.Join(tmpDir, "ca.crt")
	if err := SaveCertificate(caCert, caFile); err != nil {
		t.Fatalf("Failed to save CA: %v", err)
	}

	// Generate client cert
	clientCert, clientKey, err := GenerateNodeCert(caCert, caKey, &CertConfig{
		Organization: "Test",
		CommonName:   "client",
		ValidFor:     24 * time.Hour,
	})
	if err != nil {
		t.Fatalf("Failed to generate client cert: %v", err)
	}

	// Save client cert and key
	certFile := filepath.Join(tmpDir, "client.crt")
	keyFile := filepath.Join(tmpDir, "client.key")

	if err := SaveCertificate(clientCert, certFile); err != nil {
		t.Fatalf("Failed to save client cert: %v", err)
	}

	if err := SavePrivateKey(clientKey, keyFile); err != nil {
		t.Fatalf("Failed to save client key: %v", err)
	}

	return caFile, certFile, keyFile, tmpDir
}

func TestNewClient(t *testing.T) {
	caFile, certFile, keyFile, _ := setupTestCerts(t)

	config := &Config{
		CAFile:   caFile,
		CertFile: certFile,
		KeyFile:  keyFile,
		Timeout:  10 * time.Second,
	}

	client, err := NewClient(config)
	if err != nil {
		t.Fatalf("Failed to create client: %v", err)
	}

	if client == nil {
		t.Fatal("Client is nil")
	}

	if client.httpClient == nil {
		t.Fatal("HTTP client is nil")
	}

	// Clean up
	client.Close()
}

func TestNewClient_NilConfig(t *testing.T) {
	_, err := NewClient(nil)
	if err == nil {
		t.Error("Expected error for nil config, got nil")
	}
}

func TestNewClient_InvalidCAFile(t *testing.T) {
	_, certFile, keyFile, _ := setupTestCerts(t)

	config := &Config{
		CAFile:   "/nonexistent/ca.crt",
		CertFile: certFile,
		KeyFile:  keyFile,
	}

	_, err := NewClient(config)
	if err == nil {
		t.Error("Expected error for invalid CA file, got nil")
	}
}

func TestNewClient_InvalidCertFile(t *testing.T) {
	caFile, _, keyFile, _ := setupTestCerts(t)

	config := &Config{
		CAFile:   caFile,
		CertFile: "/nonexistent/cert.crt",
		KeyFile:  keyFile,
	}

	_, err := NewClient(config)
	if err == nil {
		t.Error("Expected error for invalid cert file, got nil")
	}
}

func TestNewClient_DefaultTimeout(t *testing.T) {
	caFile, certFile, keyFile, _ := setupTestCerts(t)

	config := &Config{
		CAFile:   caFile,
		CertFile: certFile,
		KeyFile:  keyFile,
		// No timeout specified
	}

	client, err := NewClient(config)
	if err != nil {
		t.Fatalf("Failed to create client: %v", err)
	}
	defer client.Close()

	// Verify default timeout is set
	if client.httpClient.Timeout != 30*time.Second {
		t.Errorf("Expected default timeout 30s, got %v", client.httpClient.Timeout)
	}
}

func TestByteReader(t *testing.T) {
	data := []byte("test data")
	reader := &byteReader{data: data}

	// Test reading all data
	buf := make([]byte, len(data))
	n, err := reader.Read(buf)
	if err != nil {
		t.Fatalf("Failed to read: %v", err)
	}

	if n != len(data) {
		t.Errorf("Expected to read %d bytes, got %d", len(data), n)
	}

	if string(buf) != string(data) {
		t.Errorf("Expected '%s', got '%s'", string(data), string(buf))
	}

	// Test EOF
	n, err = reader.Read(buf)
	if n != 0 {
		t.Errorf("Expected 0 bytes on EOF, got %d", n)
	}
	if err.Error() != "EOF" {
		t.Errorf("Expected EOF error, got %v", err)
	}
}

func TestByteReader_PartialReads(t *testing.T) {
	data := []byte("test data with more content")
	reader := &byteReader{data: data}

	// Read in chunks
	buf := make([]byte, 5)
	
	n, err := reader.Read(buf)
	if err != nil {
		t.Fatalf("Failed first read: %v", err)
	}
	if n != 5 {
		t.Errorf("Expected 5 bytes, got %d", n)
	}

	n, err = reader.Read(buf)
	if err != nil {
		t.Fatalf("Failed second read: %v", err)
	}
	if n != 5 {
		t.Errorf("Expected 5 bytes, got %d", n)
	}
}

func TestHealthCheck_Success(t *testing.T) {
	// Create a test server
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health" {
			w.WriteHeader(http.StatusOK)
			fmt.Fprint(w, `{"status":"healthy"}`)
		}
	}))
	defer server.Close()

	// Create client that trusts the test server
	config := &Config{
		Timeout: 5 * time.Second,
	}

	client := &Client{
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{
					InsecureSkipVerify: true, // Only for testing
				},
			},
		},
		config: config,
	}
	defer client.Close()

	// Extract address from test server
	// httptest server URL is like "https://127.0.0.1:port"
	address := server.URL[8:] // Remove "https://"

	err := client.HealthCheck(address)
	if err != nil {
		t.Errorf("Health check failed: %v", err)
	}
}

func TestHealthCheck_Failure(t *testing.T) {
	// Create a test server that returns unhealthy status
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer server.Close()

	config := &Config{
		Timeout: 5 * time.Second,
	}

	client := &Client{
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{
					InsecureSkipVerify: true,
				},
			},
		},
		config: config,
	}
	defer client.Close()

	address := server.URL[8:]

	err := client.HealthCheck(address)
	if err == nil {
		t.Error("Expected health check to fail, got nil error")
	}
}

func TestClose(t *testing.T) {
	caFile, certFile, keyFile, _ := setupTestCerts(t)

	config := &Config{
		CAFile:   caFile,
		CertFile: certFile,
		KeyFile:  keyFile,
	}

	client, err := NewClient(config)
	if err != nil {
		t.Fatalf("Failed to create client: %v", err)
	}

	// Close should not return an error
	if err := client.Close(); err != nil {
		t.Errorf("Close returned error: %v", err)
	}
}
