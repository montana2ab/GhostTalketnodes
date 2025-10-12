package common

import (
	"crypto/ed25519"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"io"

	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/hkdf"
)

// GenerateKeypair generates an Ed25519 keypair
func GenerateKeypair() (ed25519.PublicKey, ed25519.PrivateKey, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, nil, err
	}
	return pub, priv, nil
}

// X25519KeyPair generates a Curve25519 keypair for ECDH
func X25519KeyPair() (publicKey, privateKey []byte, err error) {
	privateKey = make([]byte, 32)
	if _, err := rand.Read(privateKey); err != nil {
		return nil, nil, err
	}
	
	publicKey, err = curve25519.X25519(privateKey, curve25519.Basepoint)
	if err != nil {
		return nil, nil, err
	}
	
	return publicKey, privateKey, nil
}

// X25519ECDH performs Curve25519 ECDH
func X25519ECDH(privateKey, publicKey []byte) ([]byte, error) {
	if len(privateKey) != 32 || len(publicKey) != 32 {
		return nil, errors.New("invalid key length")
	}
	
	sharedSecret, err := curve25519.X25519(privateKey, publicKey)
	if err != nil {
		return nil, err
	}
	
	return sharedSecret, nil
}

// DeriveKeys derives encryption, HMAC, and blinding keys from shared secret
func DeriveKeys(sharedSecret []byte, salt string) (encKey, hmacKey, blindingFactor []byte, err error) {
	hkdfReader := hkdf.New(sha256.New, sharedSecret, []byte(salt), []byte("GhostTalk-v1-hop-keys"))
	
	// Derive 96 bytes: 32 for encryption, 32 for HMAC, 32 for blinding
	derived := make([]byte, 96)
	if _, err := io.ReadFull(hkdfReader, derived); err != nil {
		return nil, nil, nil, err
	}
	
	encKey = derived[0:32]
	hmacKey = derived[32:64]
	blindingFactor = derived[64:96]
	
	return encKey, hmacKey, blindingFactor, nil
}

// ComputeHMAC computes HMAC-SHA256
func ComputeHMAC(key, message []byte) []byte {
	mac := hmac.New(sha256.New, key)
	mac.Write(message)
	return mac.Sum(nil)
}

// VerifyHMAC verifies HMAC in constant time
func VerifyHMAC(expected, computed []byte) bool {
	return hmac.Equal(expected, computed)
}

// BlindPrivateKey blinds a Curve25519 private key with a blinding factor
func BlindPrivateKey(privateKey, blindingFactor []byte) ([]byte, error) {
	if len(privateKey) != 32 || len(blindingFactor) != 32 {
		return nil, errors.New("invalid key length")
	}
	
	// Scalar multiplication modulo the curve order
	// For simplicity, we use multiplication in the field
	// In production, use proper scalar multiplication
	blinded := make([]byte, 32)
	copy(blinded, privateKey)
	
	// XOR for simplicity (replace with proper scalar mult in production)
	for i := 0; i < 32; i++ {
		blinded[i] ^= blindingFactor[i]
	}
	
	return blinded, nil
}

// BlindPublicKey blinds a Curve25519 public key
func BlindPublicKey(publicKey, blindingFactor []byte) ([]byte, error) {
	if len(publicKey) != 32 || len(blindingFactor) != 32 {
		return nil, errors.New("invalid key length")
	}
	
	// Compute basepoint * blinding_factor
	blindedBase, err := curve25519.X25519(blindingFactor, curve25519.Basepoint)
	if err != nil {
		return nil, err
	}
	
	// Add to public key (simplified, replace with proper EC addition)
	blinded := make([]byte, 32)
	for i := 0; i < 32; i++ {
		blinded[i] = publicKey[i] ^ blindedBase[i]
	}
	
	return blinded, nil
}

// RandomBytes generates cryptographically secure random bytes
func RandomBytes(n int) ([]byte, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	return b, nil
}

// Hash256 computes SHA-256 hash
func Hash256(data []byte) []byte {
	hash := sha256.Sum256(data)
	return hash[:]
}
