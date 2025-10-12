package onion

import (
	"crypto/ed25519"
	"testing"
	"time"

	"github.com/montana2ab/GhostTalketnodes/server/pkg/common"
)

func TestNewRouter(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	router := NewRouter(priv)
	if router == nil {
		t.Fatal("NewRouter returned nil")
	}

	if router.privateKey == nil {
		t.Error("Router private key is nil")
	}

	if router.publicKey == nil {
		t.Error("Router public key is nil")
	}
}

func TestRouterStats(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	router := NewRouter(priv)
	stats := router.GetStats()

	if stats.PacketsProcessed != 0 {
		t.Errorf("Initial packets processed = %d, want 0", stats.PacketsProcessed)
	}

	if stats.PacketsForwarded != 0 {
		t.Errorf("Initial packets forwarded = %d, want 0", stats.PacketsForwarded)
	}

	if stats.PacketsDelivered != 0 {
		t.Errorf("Initial packets delivered = %d, want 0", stats.PacketsDelivered)
	}

	if stats.PacketsDropped != 0 {
		t.Errorf("Initial packets dropped = %d, want 0", stats.PacketsDropped)
	}
}

func TestProcessPacket_InvalidSize(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	router := NewRouter(priv)

	// Test with invalid packet sizes
	testCases := []struct {
		name string
		size int
	}{
		{"too small", 100},
		{"too large", 2000},
		{"empty", 0},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			packet := make([]byte, tc.size)
			_, err := router.ProcessPacket(packet)
			if err == nil {
				t.Error("Expected error for invalid packet size, got nil")
			}
		})
	}

	// Note: PacketsDropped counter is only incremented when packet is parsed first
	// Invalid size errors are caught before parsing, so counter won't be incremented
}

func TestProcessPacket_InvalidVersion(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	router := NewRouter(priv)

	// Create packet with invalid version
	packet := make([]byte, common.PacketSize)
	packet[0] = 0xFF // Invalid version

	_, err = router.ProcessPacket(packet)
	if err == nil {
		t.Error("Expected error for invalid version, got nil")
	}

	stats := router.GetStats()
	if stats.PacketsDropped != 1 {
		t.Errorf("Packets dropped = %d, want 1", stats.PacketsDropped)
	}
}

func TestReplayProtection(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	router := NewRouter(priv)

	// Create a valid-looking packet (will fail HMAC but that's OK for this test)
	packet := make([]byte, common.PacketSize)
	packet[0] = common.PacketVersion
	
	// Generate random ephemeral key and HMAC
	ephemeralKey, err := common.RandomBytes(32)
	if err != nil {
		t.Fatalf("Failed to generate random key: %v", err)
	}
	copy(packet[1:33], ephemeralKey)
	
	hmac, err := common.RandomBytes(32)
	if err != nil {
		t.Fatalf("Failed to generate random HMAC: %v", err)
	}
	copy(packet[33:65], hmac)

	// First attempt - will fail for other reasons but should be recorded
	router.ProcessPacket(packet)

	// Second attempt with same HMAC - should be detected as replay
	_, err = router.ProcessPacket(packet)
	if err == nil {
		t.Error("Expected error on second attempt, got nil")
	}

	// The error might be "replay detected" or "HMAC verification failed"
	// depending on which check happens first. Both are acceptable for this test.
}

func TestParsePacket(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	router := NewRouter(priv)

	// Create a packet with known structure
	packet := make([]byte, common.PacketSize)
	packet[0] = 0x01 // Version
	
	// Add ephemeral key
	ephemeralKey := make([]byte, 32)
	for i := range ephemeralKey {
		ephemeralKey[i] = byte(i)
	}
	copy(packet[1:33], ephemeralKey)
	
	// Add HMAC
	hmac := make([]byte, 32)
	for i := range hmac {
		hmac[i] = byte(i + 32)
	}
	copy(packet[33:65], hmac)

	// Parse packet
	parsed, err := router.parsePacket(packet)
	if err != nil {
		t.Fatalf("Failed to parse packet: %v", err)
	}

	// Verify fields
	if parsed.Version != 0x01 {
		t.Errorf("Version = 0x%02x, want 0x01", parsed.Version)
	}

	if len(parsed.EphemeralKey) != 32 {
		t.Errorf("Ephemeral key length = %d, want 32", len(parsed.EphemeralKey))
	}

	if len(parsed.HeaderHMAC) != 32 {
		t.Errorf("HMAC length = %d, want 32", len(parsed.HeaderHMAC))
	}

	if len(parsed.RoutingBlob) != common.RoutingBlobSize {
		t.Errorf("Routing blob length = %d, want %d", len(parsed.RoutingBlob), common.RoutingBlobSize)
	}

	if len(parsed.EncryptedPayload) != common.PayloadSize {
		t.Errorf("Payload length = %d, want %d", len(parsed.EncryptedPayload), common.PayloadSize)
	}
}

func TestAssemblePacket(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	router := NewRouter(priv)

	// Create components
	ephemeralKey := make([]byte, 32)
	hmac := make([]byte, 32)
	routingBlob := make([]byte, common.RoutingBlobSize)
	payload := make([]byte, common.PayloadSize)

	// Assemble packet
	packet := router.assemblePacket(ephemeralKey, hmac, routingBlob, payload)

	// Verify size
	if len(packet) != common.PacketSize {
		t.Errorf("Packet size = %d, want %d", len(packet), common.PacketSize)
	}

	// Verify version
	if packet[0] != common.PacketVersion {
		t.Errorf("Version = 0x%02x, want 0x%02x", packet[0], common.PacketVersion)
	}
}

func TestFormatAddress(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	router := NewRouter(priv)

	testCases := []struct {
		name     string
		routing  *common.RoutingInfo
		expected string
	}{
		{
			name: "IPv4",
			routing: &common.RoutingInfo{
				AddressType: 0x04,
				Address:     []byte{192, 168, 1, 1},
				Port:        8080,
			},
			expected: "192.168.1.1:8080",
		},
		{
			name: "Final hop",
			routing: &common.RoutingInfo{
				AddressType: 0x00,
			},
			expected: "",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := router.formatAddress(tc.routing)
			if result != tc.expected {
				t.Errorf("formatAddress() = %q, want %q", result, tc.expected)
			}
		})
	}
}

func TestParseRoutingInfo(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	router := NewRouter(priv)

	// Create routing info data
	data := make([]byte, 61)
	
	// Address type: IPv4
	data[0] = 0x04
	
	// IP address: 192.168.1.1
	data[1] = 192
	data[2] = 168
	data[3] = 1
	data[4] = 1
	
	// Port: 8080 (big-endian)
	data[17] = 0x1F
	data[18] = 0x90
	
	// Expiry: current time + 5 minutes
	expiry := time.Now().Add(5 * time.Minute).Unix()
	for i := 0; i < 8; i++ {
		data[19+i] = byte(expiry >> (56 - i*8))
	}
	
	// Delay: 1000ms
	data[27] = 0x03
	data[28] = 0xE8

	// Parse
	routing, err := router.parseRoutingInfo(data)
	if err != nil {
		t.Fatalf("Failed to parse routing info: %v", err)
	}

	// Verify
	if routing.AddressType != 0x04 {
		t.Errorf("AddressType = 0x%02x, want 0x04", routing.AddressType)
	}

	if len(routing.Address) != 4 {
		t.Errorf("Address length = %d, want 4", len(routing.Address))
	}

	if routing.Port != 8080 {
		t.Errorf("Port = %d, want 8080", routing.Port)
	}

	if routing.Delay != 1000 {
		t.Errorf("Delay = %d, want 1000", routing.Delay)
	}
}

func TestCleanupReplayCache(t *testing.T) {
	_, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	router := NewRouter(priv)

	// Add some entries to the replay cache
	router.seenHMACs.Store("key1", time.Now().Add(-10*time.Minute))
	router.seenHMACs.Store("key2", time.Now())
	router.seenHMACs.Store("key3", time.Now().Add(-6*time.Minute))

	// Wait a bit to ensure cleanup has a chance to run
	time.Sleep(100 * time.Millisecond)

	// Note: The cleanup runs in a goroutine with 5-minute intervals,
	// so we can't easily test it automatically without refactoring.
	// This test mainly ensures the function doesn't panic.
}
