package common

import (
	"testing"
)

// Benchmark crypto operations

func BenchmarkGenerateKeypair(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_, _, err := GenerateKeypair()
		if err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkX25519KeyPair(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_, _, err := X25519KeyPair()
		if err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkX25519ECDH(b *testing.B) {
	// Generate keypairs once
	alicePub, _, err := X25519KeyPair()
	if err != nil {
		b.Fatal(err)
	}
	_, bobPriv, err := X25519KeyPair()
	if err != nil {
		b.Fatal(err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := X25519ECDH(bobPriv, alicePub)
		if err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkDeriveKeys(b *testing.B) {
	// Generate shared secret
	alicePub, _, _ := X25519KeyPair()
	_, bobPriv, _ := X25519KeyPair()
	sharedSecret, _ := X25519ECDH(bobPriv, alicePub)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _, _, err := DeriveKeys(sharedSecret, "test")
		if err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkComputeHMAC(b *testing.B) {
	key := make([]byte, 32)
	data := make([]byte, 1024) // 1KB message

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = ComputeHMAC(key, data)
	}
}

func BenchmarkVerifyHMAC(b *testing.B) {
	key := make([]byte, 32)
	data := make([]byte, 1024)
	mac := ComputeHMAC(key, data)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if !VerifyHMAC(mac, ComputeHMAC(key, data)) {
			b.Fatal("HMAC verification failed")
		}
	}
}

func BenchmarkRandomBytes(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_, err := RandomBytes(32)
		if err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkHash256(b *testing.B) {
	data := make([]byte, 1024)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = Hash256(data)
	}
}

// Benchmark with different message sizes
func BenchmarkComputeHMAC_100B(b *testing.B) {
	key := make([]byte, 32)
	data := make([]byte, 100)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = ComputeHMAC(key, data)
	}
}

func BenchmarkComputeHMAC_1KB(b *testing.B) {
	key := make([]byte, 32)
	data := make([]byte, 1024)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = ComputeHMAC(key, data)
	}
}

func BenchmarkComputeHMAC_10KB(b *testing.B) {
	key := make([]byte, 32)
	data := make([]byte, 10*1024)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = ComputeHMAC(key, data)
	}
}

func BenchmarkHash256_100B(b *testing.B) {
	data := make([]byte, 100)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = Hash256(data)
	}
}

func BenchmarkHash256_1KB(b *testing.B) {
	data := make([]byte, 1024)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = Hash256(data)
	}
}

func BenchmarkHash256_10KB(b *testing.B) {
	data := make([]byte, 10*1024)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = Hash256(data)
	}
}
