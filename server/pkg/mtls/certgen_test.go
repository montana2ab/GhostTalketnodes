package mtls

import (
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestGenerateCA(t *testing.T) {
	cert, key, err := GenerateCA(nil)
	if err != nil {
		t.Fatalf("Failed to generate CA: %v", err)
	}

	if cert == nil {
		t.Fatal("Certificate is nil")
	}

	if key == nil {
		t.Fatal("Private key is nil")
	}

	if !cert.IsCA {
		t.Error("Certificate is not marked as CA")
	}

	if cert.Subject.CommonName != "GhostTalk CA" {
		t.Errorf("Expected CN 'GhostTalk CA', got '%s'", cert.Subject.CommonName)
	}
}

func TestGenerateCA_CustomConfig(t *testing.T) {
	config := &CertConfig{
		Organization: "Test Org",
		CommonName:   "Test CA",
		ValidFor:     24 * time.Hour,
		IsCA:         true,
	}

	cert, key, err := GenerateCA(config)
	if err != nil {
		t.Fatalf("Failed to generate CA: %v", err)
	}

	if cert.Subject.CommonName != "Test CA" {
		t.Errorf("Expected CN 'Test CA', got '%s'", cert.Subject.CommonName)
	}

	if len(cert.Subject.Organization) == 0 || cert.Subject.Organization[0] != "Test Org" {
		t.Errorf("Expected organization 'Test Org', got %v", cert.Subject.Organization)
	}

	if key == nil {
		t.Fatal("Private key is nil")
	}
}

func TestGenerateNodeCert(t *testing.T) {
	// Generate CA first
	caCert, caKey, err := GenerateCA(nil)
	if err != nil {
		t.Fatalf("Failed to generate CA: %v", err)
	}

	// Generate node certificate
	config := &CertConfig{
		Organization: "GhostTalk",
		CommonName:   "node1.example.com",
		DNSNames:     []string{"node1.example.com", "localhost"},
		IPAddresses:  []net.IP{net.ParseIP("127.0.0.1")},
		ValidFor:     365 * 24 * time.Hour,
	}

	nodeCert, nodeKey, err := GenerateNodeCert(caCert, caKey, config)
	if err != nil {
		t.Fatalf("Failed to generate node certificate: %v", err)
	}

	if nodeCert == nil {
		t.Fatal("Node certificate is nil")
	}

	if nodeKey == nil {
		t.Fatal("Node private key is nil")
	}

	if nodeCert.IsCA {
		t.Error("Node certificate should not be marked as CA")
	}

	if nodeCert.Subject.CommonName != "node1.example.com" {
		t.Errorf("Expected CN 'node1.example.com', got '%s'", nodeCert.Subject.CommonName)
	}

	// Verify DNS names
	if len(nodeCert.DNSNames) != 2 {
		t.Errorf("Expected 2 DNS names, got %d", len(nodeCert.DNSNames))
	}

	// Verify IP addresses
	if len(nodeCert.IPAddresses) != 1 {
		t.Errorf("Expected 1 IP address, got %d", len(nodeCert.IPAddresses))
	}
}

func TestGenerateNodeCert_NilConfig(t *testing.T) {
	caCert, caKey, err := GenerateCA(nil)
	if err != nil {
		t.Fatalf("Failed to generate CA: %v", err)
	}

	_, _, err = GenerateNodeCert(caCert, caKey, nil)
	if err == nil {
		t.Error("Expected error for nil config, got nil")
	}
}

func TestSaveAndLoadCertificate(t *testing.T) {
	// Generate a test certificate
	cert, _, err := GenerateCA(nil)
	if err != nil {
		t.Fatalf("Failed to generate CA: %v", err)
	}

	// Create temp directory
	tmpDir := t.TempDir()
	certFile := filepath.Join(tmpDir, "test.crt")

	// Save certificate
	if err := SaveCertificate(cert, certFile); err != nil {
		t.Fatalf("Failed to save certificate: %v", err)
	}

	// Verify file exists
	if _, err := os.Stat(certFile); os.IsNotExist(err) {
		t.Fatal("Certificate file was not created")
	}

	// Load certificate
	loadedCert, err := LoadCertificate(certFile)
	if err != nil {
		t.Fatalf("Failed to load certificate: %v", err)
	}

	// Verify loaded certificate matches original
	if !loadedCert.Equal(cert) {
		t.Error("Loaded certificate does not match original")
	}
}

func TestSaveAndLoadPrivateKey(t *testing.T) {
	// Generate a test key
	_, key, err := GenerateCA(nil)
	if err != nil {
		t.Fatalf("Failed to generate CA: %v", err)
	}

	// Create temp directory
	tmpDir := t.TempDir()
	keyFile := filepath.Join(tmpDir, "test.key")

	// Save private key
	if err := SavePrivateKey(key, keyFile); err != nil {
		t.Fatalf("Failed to save private key: %v", err)
	}

	// Verify file exists and has correct permissions
	info, err := os.Stat(keyFile)
	if os.IsNotExist(err) {
		t.Fatal("Key file was not created")
	}

	// Check file permissions (should be 0600)
	if info.Mode().Perm() != 0600 {
		t.Errorf("Expected file permissions 0600, got %v", info.Mode().Perm())
	}

	// Load private key
	loadedKey, err := LoadPrivateKey(keyFile)
	if err != nil {
		t.Fatalf("Failed to load private key: %v", err)
	}

	// Verify loaded key matches original
	if loadedKey.N.Cmp(key.N) != 0 {
		t.Error("Loaded key does not match original")
	}
}

func TestLoadCertificate_InvalidFile(t *testing.T) {
	_, err := LoadCertificate("/nonexistent/file.crt")
	if err == nil {
		t.Error("Expected error for nonexistent file, got nil")
	}
}

func TestLoadPrivateKey_InvalidFile(t *testing.T) {
	_, err := LoadPrivateKey("/nonexistent/file.key")
	if err == nil {
		t.Error("Expected error for nonexistent file, got nil")
	}
}

func TestLoadCertificate_InvalidPEM(t *testing.T) {
	tmpDir := t.TempDir()
	certFile := filepath.Join(tmpDir, "invalid.crt")

	// Write invalid data
	if err := os.WriteFile(certFile, []byte("not a pem file"), 0644); err != nil {
		t.Fatalf("Failed to write test file: %v", err)
	}

	_, err := LoadCertificate(certFile)
	if err == nil {
		t.Error("Expected error for invalid PEM, got nil")
	}
}

func TestFullCertificateChain(t *testing.T) {
	tmpDir := t.TempDir()

	// 1. Generate CA
	caCert, caKey, err := GenerateCA(&CertConfig{
		Organization: "Test",
		CommonName:   "Test CA",
		ValidFor:     365 * 24 * time.Hour,
	})
	if err != nil {
		t.Fatalf("Failed to generate CA: %v", err)
	}

	// 2. Save CA certificate and key
	caFile := filepath.Join(tmpDir, "ca.crt")
	caKeyFile := filepath.Join(tmpDir, "ca.key")

	if err := SaveCertificate(caCert, caFile); err != nil {
		t.Fatalf("Failed to save CA certificate: %v", err)
	}

	if err := SavePrivateKey(caKey, caKeyFile); err != nil {
		t.Fatalf("Failed to save CA key: %v", err)
	}

	// 3. Generate node certificate
	nodeCert, nodeKey, err := GenerateNodeCert(caCert, caKey, &CertConfig{
		Organization: "Test",
		CommonName:   "node1.test.com",
		DNSNames:     []string{"node1.test.com"},
		ValidFor:     30 * 24 * time.Hour,
	})
	if err != nil {
		t.Fatalf("Failed to generate node certificate: %v", err)
	}

	// 4. Save node certificate and key
	nodeFile := filepath.Join(tmpDir, "node.crt")
	nodeKeyFile := filepath.Join(tmpDir, "node.key")

	if err := SaveCertificate(nodeCert, nodeFile); err != nil {
		t.Fatalf("Failed to save node certificate: %v", err)
	}

	if err := SavePrivateKey(nodeKey, nodeKeyFile); err != nil {
		t.Fatalf("Failed to save node key: %v", err)
	}

	// 5. Load and verify
	loadedCA, err := LoadCertificate(caFile)
	if err != nil {
		t.Fatalf("Failed to load CA: %v", err)
	}

	loadedNode, err := LoadCertificate(nodeFile)
	if err != nil {
		t.Fatalf("Failed to load node certificate: %v", err)
	}

	// 6. Verify chain
	if !loadedCA.IsCA {
		t.Error("Loaded CA should be marked as CA")
	}

	if loadedNode.IsCA {
		t.Error("Loaded node certificate should not be marked as CA")
	}

	// Verify node cert was signed by CA
	if err := loadedNode.CheckSignatureFrom(loadedCA); err != nil {
		t.Errorf("Node certificate signature verification failed: %v", err)
	}
}
