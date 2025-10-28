package onion

import (
	"testing"

	"github.com/montana2ab/GhostTalketnodes/server/pkg/common"
)

// Benchmark onion routing operations

func BenchmarkNewRouter(b *testing.B) {
	_, priv, _ := common.GenerateKeypair()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = NewRouter(priv)
	}
}

func BenchmarkProcessPacket_InvalidSize(b *testing.B) {
	_, priv, _ := common.GenerateKeypair()
	router := NewRouter(priv)

	// Create invalid packet (too small)
	packet := make([]byte, 100)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = router.ProcessPacket(packet)
	}
}

func BenchmarkGetStats(b *testing.B) {
	_, priv, _ := common.GenerateKeypair()
	router := NewRouter(priv)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = router.GetStats()
	}
}

// Benchmark crypto operations used in routing
func BenchmarkEd25519ToCurve25519(b *testing.B) {
	_, priv, _ := common.GenerateKeypair()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = ed25519PrivateKeyToCurve25519(priv)
	}
}

// Benchmark hash operations
func BenchmarkComputePacketHash(b *testing.B) {
	data := make([]byte, 1024)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = common.Hash256(data)
	}
}

// Benchmark HMAC operations for packet verification
func BenchmarkPacketHMACVerification(b *testing.B) {
	key := make([]byte, 32)
	data := make([]byte, 1024)
	mac := common.ComputeHMAC(key, data)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = common.VerifyHMAC(mac, common.ComputeHMAC(key, data))
	}
}

// Benchmark key derivation for hop processing
func BenchmarkHopKeyDerivation(b *testing.B) {
	alicePub, _, _ := common.X25519KeyPair()
	_, bobPriv, _ := common.X25519KeyPair()
	sharedSecret, _ := common.X25519ECDH(bobPriv, alicePub)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _, _, _ = common.DeriveKeys(sharedSecret, "hop-1")
	}
}

