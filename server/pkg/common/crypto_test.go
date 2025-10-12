package common

import (
	"bytes"
	"testing"
)

func TestGenerateKeypair(t *testing.T) {
	pub, priv, err := GenerateKeypair()
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}
	
	if len(pub) != 32 {
		t.Errorf("Public key length = %d, want 32", len(pub))
	}
	
	if len(priv) != 64 {
		t.Errorf("Private key length = %d, want 64", len(priv))
	}
}

func TestX25519KeyPair(t *testing.T) {
	pub, priv, err := X25519KeyPair()
	if err != nil {
		t.Fatalf("Failed to generate X25519 keypair: %v", err)
	}
	
	if len(pub) != 32 {
		t.Errorf("Public key length = %d, want 32", len(pub))
	}
	
	if len(priv) != 32 {
		t.Errorf("Private key length = %d, want 32", len(priv))
	}
}

func TestX25519ECDH(t *testing.T) {
	// Alice generates keypair
	alicePub, alicePriv, err := X25519KeyPair()
	if err != nil {
		t.Fatalf("Failed to generate Alice's keypair: %v", err)
	}
	
	// Bob generates keypair
	bobPub, bobPriv, err := X25519KeyPair()
	if err != nil {
		t.Fatalf("Failed to generate Bob's keypair: %v", err)
	}
	
	// Alice computes shared secret with Bob's public key
	aliceShared, err := X25519ECDH(alicePriv, bobPub)
	if err != nil {
		t.Fatalf("Alice's ECDH failed: %v", err)
	}
	
	// Bob computes shared secret with Alice's public key
	bobShared, err := X25519ECDH(bobPriv, alicePub)
	if err != nil {
		t.Fatalf("Bob's ECDH failed: %v", err)
	}
	
	// Shared secrets should match
	if !bytes.Equal(aliceShared, bobShared) {
		t.Error("Shared secrets don't match")
	}
}

func TestDeriveKeys(t *testing.T) {
	secret := []byte("test-shared-secret-32-bytes!!")
	salt := "test-salt"
	
	encKey, hmacKey, blindingFactor, err := DeriveKeys(secret, salt)
	if err != nil {
		t.Fatalf("Failed to derive keys: %v", err)
	}
	
	if len(encKey) != 32 {
		t.Errorf("Encryption key length = %d, want 32", len(encKey))
	}
	
	if len(hmacKey) != 32 {
		t.Errorf("HMAC key length = %d, want 32", len(hmacKey))
	}
	
	if len(blindingFactor) != 32 {
		t.Errorf("Blinding factor length = %d, want 32", len(blindingFactor))
	}
	
	// Keys should be different
	if bytes.Equal(encKey, hmacKey) {
		t.Error("Encryption key and HMAC key are the same")
	}
}

func TestComputeHMAC(t *testing.T) {
	key := []byte("test-key-32-bytes-long-enough")
	message := []byte("test message")
	
	hmac1 := ComputeHMAC(key, message)
	hmac2 := ComputeHMAC(key, message)
	
	if !bytes.Equal(hmac1, hmac2) {
		t.Error("HMAC is not deterministic")
	}
	
	if len(hmac1) != 32 {
		t.Errorf("HMAC length = %d, want 32", len(hmac1))
	}
	
	// Different message should produce different HMAC
	hmac3 := ComputeHMAC(key, []byte("different message"))
	if bytes.Equal(hmac1, hmac3) {
		t.Error("Different messages produced same HMAC")
	}
}

func TestVerifyHMAC(t *testing.T) {
	key := []byte("test-key-32-bytes-long-enough")
	message := []byte("test message")
	
	hmac := ComputeHMAC(key, message)
	
	if !VerifyHMAC(hmac, hmac) {
		t.Error("HMAC verification failed for same HMAC")
	}
	
	wrongHMAC := make([]byte, 32)
	if VerifyHMAC(hmac, wrongHMAC) {
		t.Error("HMAC verification succeeded for different HMAC")
	}
}

func TestRandomBytes(t *testing.T) {
	bytes1, err := RandomBytes(32)
	if err != nil {
		t.Fatalf("Failed to generate random bytes: %v", err)
	}
	
	bytes2, err := RandomBytes(32)
	if err != nil {
		t.Fatalf("Failed to generate random bytes: %v", err)
	}
	
	if len(bytes1) != 32 {
		t.Errorf("Random bytes length = %d, want 32", len(bytes1))
	}
	
	if bytes.Equal(bytes1, bytes2) {
		t.Error("Random bytes are not random (collision)")
	}
}

func TestHash256(t *testing.T) {
	data := []byte("test data")
	hash1 := Hash256(data)
	hash2 := Hash256(data)
	
	if !bytes.Equal(hash1, hash2) {
		t.Error("Hash is not deterministic")
	}
	
	if len(hash1) != 32 {
		t.Errorf("Hash length = %d, want 32", len(hash1))
	}
	
	// Different data should produce different hash
	hash3 := Hash256([]byte("different data"))
	if bytes.Equal(hash1, hash3) {
		t.Error("Different data produced same hash")
	}
}
