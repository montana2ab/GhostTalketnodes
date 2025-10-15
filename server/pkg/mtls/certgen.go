package mtls

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"fmt"
	"math/big"
	"net"
	"os"
	"time"
)

// CertConfig holds configuration for certificate generation
type CertConfig struct {
	Organization string
	CommonName   string
	DNSNames     []string
	IPAddresses  []net.IP
	ValidFor     time.Duration
	IsCA         bool
}

// GenerateCA generates a new Certificate Authority
func GenerateCA(config *CertConfig) (*x509.Certificate, *rsa.PrivateKey, error) {
	if config == nil {
		config = &CertConfig{
			Organization: "GhostTalk",
			CommonName:   "GhostTalk CA",
			ValidFor:     10 * 365 * 24 * time.Hour, // 10 years
			IsCA:         true,
		}
	}

	// Generate private key
	privateKey, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to generate private key: %w", err)
	}

	// Generate serial number
	serialNumber, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128))
	if err != nil {
		return nil, nil, fmt.Errorf("failed to generate serial number: %w", err)
	}

	// Create CA certificate template
	template := &x509.Certificate{
		SerialNumber: serialNumber,
		Subject: pkix.Name{
			Organization: []string{config.Organization},
			CommonName:   config.CommonName,
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().Add(config.ValidFor),
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth, x509.ExtKeyUsageClientAuth},
		BasicConstraintsValid: true,
		IsCA:                  true,
	}

	// Self-sign the CA certificate
	certDER, err := x509.CreateCertificate(rand.Reader, template, template, 
		&privateKey.PublicKey, privateKey)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create certificate: %w", err)
	}

	// Parse the certificate
	cert, err := x509.ParseCertificate(certDER)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to parse certificate: %w", err)
	}

	return cert, privateKey, nil
}

// GenerateNodeCert generates a certificate for a node signed by the CA
func GenerateNodeCert(caCert *x509.Certificate, caKey *rsa.PrivateKey, 
	config *CertConfig) (*x509.Certificate, *rsa.PrivateKey, error) {
	
	if config == nil {
		return nil, nil, fmt.Errorf("config cannot be nil")
	}

	// Generate private key for node
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to generate private key: %w", err)
	}

	// Generate serial number
	serialNumber, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128))
	if err != nil {
		return nil, nil, fmt.Errorf("failed to generate serial number: %w", err)
	}

	// Set default validity if not specified
	validFor := config.ValidFor
	if validFor == 0 {
		validFor = 365 * 24 * time.Hour // 1 year
	}

	// Create certificate template
	template := &x509.Certificate{
		SerialNumber: serialNumber,
		Subject: pkix.Name{
			Organization: []string{config.Organization},
			CommonName:   config.CommonName,
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().Add(validFor),
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth, x509.ExtKeyUsageClientAuth},
		BasicConstraintsValid: true,
		DNSNames:              config.DNSNames,
		IPAddresses:           config.IPAddresses,
	}

	// Sign the certificate with CA
	certDER, err := x509.CreateCertificate(rand.Reader, template, caCert, 
		&privateKey.PublicKey, caKey)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create certificate: %w", err)
	}

	// Parse the certificate
	cert, err := x509.ParseCertificate(certDER)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to parse certificate: %w", err)
	}

	return cert, privateKey, nil
}

// SaveCertificate saves a certificate to a PEM file
func SaveCertificate(cert *x509.Certificate, filename string) error {
	certOut, err := os.Create(filename)
	if err != nil {
		return fmt.Errorf("failed to create certificate file: %w", err)
	}
	defer certOut.Close()

	if err := pem.Encode(certOut, &pem.Block{
		Type:  "CERTIFICATE",
		Bytes: cert.Raw,
	}); err != nil {
		return fmt.Errorf("failed to encode certificate: %w", err)
	}

	return nil
}

// SavePrivateKey saves a private key to a PEM file
func SavePrivateKey(key *rsa.PrivateKey, filename string) error {
	keyOut, err := os.OpenFile(filename, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return fmt.Errorf("failed to create key file: %w", err)
	}
	defer keyOut.Close()

	privBytes := x509.MarshalPKCS1PrivateKey(key)
	if err := pem.Encode(keyOut, &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: privBytes,
	}); err != nil {
		return fmt.Errorf("failed to encode private key: %w", err)
	}

	return nil
}

// LoadCertificate loads a certificate from a PEM file
func LoadCertificate(filename string) (*x509.Certificate, error) {
	certPEM, err := os.ReadFile(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to read certificate file: %w", err)
	}

	block, _ := pem.Decode(certPEM)
	if block == nil {
		return nil, fmt.Errorf("failed to parse certificate PEM")
	}

	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("failed to parse certificate: %w", err)
	}

	return cert, nil
}

// LoadPrivateKey loads a private key from a PEM file
func LoadPrivateKey(filename string) (*rsa.PrivateKey, error) {
	keyPEM, err := os.ReadFile(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to read key file: %w", err)
	}

	block, _ := pem.Decode(keyPEM)
	if block == nil {
		return nil, fmt.Errorf("failed to parse key PEM")
	}

	key, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("failed to parse private key: %w", err)
	}

	return key, nil
}
