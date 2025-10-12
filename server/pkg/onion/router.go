package onion

import (
	"crypto/ed25519"
	"encoding/binary"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/montana2ab/GhostTalketnodes/server/pkg/common"
	"golang.org/x/crypto/chacha20poly1305"
)

// Router handles onion packet processing
type Router struct {
	privateKey ed25519.PrivateKey
	publicKey  ed25519.PublicKey
	
	// Replay protection cache
	seenHMACs sync.Map // map[string]time.Time
	
	// Stats
	packetsProcessed uint64
	packetsForwarded uint64
	packetsDelivered uint64
	packetsDropped   uint64
}

// NewRouter creates a new onion router
func NewRouter(privateKey ed25519.PrivateKey) *Router {
	publicKey := privateKey.Public().(ed25519.PublicKey)
	
	r := &Router{
		privateKey: privateKey,
		publicKey:  publicKey,
	}
	
	// Start cleanup goroutine for replay cache
	go r.cleanupReplayCache()
	
	return r
}

// ProcessPacket processes an onion packet and returns routing decision
func (r *Router) ProcessPacket(packet []byte) (*RoutingDecision, error) {
	if len(packet) != common.PacketSize {
		return nil, fmt.Errorf("invalid packet size: %d", len(packet))
	}
	
	// Parse packet
	onionPkt, err := r.parsePacket(packet)
	if err != nil {
		r.packetsDropped++
		return nil, fmt.Errorf("parse error: %w", err)
	}
	
	// Check version
	if onionPkt.Version != common.PacketVersion {
		r.packetsDropped++
		return nil, fmt.Errorf("unsupported version: 0x%02x", onionPkt.Version)
	}
	
	// Check replay (HMAC must be unique)
	hmacKey := fmt.Sprintf("%x", onionPkt.HeaderHMAC)
	if _, exists := r.seenHMACs.LoadOrStore(hmacKey, time.Now()); exists {
		r.packetsDropped++
		return nil, errors.New("replay detected")
	}
	
	// Derive shared secret using ECDH
	// Convert Ed25519 private key to Curve25519 for ECDH
	curve25519PrivKey := ed25519PrivateKeyToCurve25519(r.privateKey)
	
	sharedSecret, err := common.X25519ECDH(curve25519PrivKey, onionPkt.EphemeralKey)
	if err != nil {
		r.packetsDropped++
		return nil, fmt.Errorf("ECDH failed: %w", err)
	}
	
	// Derive keys
	encKey, hmacKeyBytes, blindingFactor, err := common.DeriveKeys(sharedSecret, "GhostTalk-v1")
	if err != nil {
		r.packetsDropped++
		return nil, fmt.Errorf("key derivation failed: %w", err)
	}
	
	// Verify HMAC
	computedHMAC := common.ComputeHMAC(hmacKeyBytes, append(onionPkt.EphemeralKey, onionPkt.RoutingBlob...))
	if !common.VerifyHMAC(onionPkt.HeaderHMAC, computedHMAC) {
		r.packetsDropped++
		return nil, errors.New("HMAC verification failed")
	}
	
	// Decrypt routing info
	routingInfo, err := r.decryptRoutingBlob(encKey, onionPkt.RoutingBlob)
	if err != nil {
		r.packetsDropped++
		return nil, fmt.Errorf("routing decryption failed: %w", err)
	}
	
	// Parse routing info
	routing, err := r.parseRoutingInfo(routingInfo)
	if err != nil {
		r.packetsDropped++
		return nil, fmt.Errorf("routing parse failed: %w", err)
	}
	
	// Check expiry
	if time.Now().After(routing.Expiry) {
		r.packetsDropped++
		return nil, errors.New("packet expired")
	}
	
	r.packetsProcessed++
	
	// Determine action
	if routing.AddressType == 0x00 {
		// Final hop - deliver locally
		r.packetsDelivered++
		
		// Decrypt payload
		payload, err := r.decryptPayload(encKey, onionPkt.EncryptedPayload)
		if err != nil {
			return nil, fmt.Errorf("payload decryption failed: %w", err)
		}
		
		return &RoutingDecision{
			Action:  ActionDeliver,
			Payload: payload,
			Delay:   time.Duration(routing.Delay) * time.Millisecond,
		}, nil
	}
	
	// Forward to next hop
	r.packetsForwarded++
	
	// Blind ephemeral key for next hop
	nextEphemeralKey, err := common.BlindPublicKey(onionPkt.EphemeralKey, blindingFactor)
	if err != nil {
		return nil, fmt.Errorf("key blinding failed: %w", err)
	}
	
	// Shift routing blob (remove our layer, pad with zeros)
	nextRoutingBlob := make([]byte, common.RoutingBlobSize)
	copy(nextRoutingBlob, routingInfo[common.PerHopRoutingSize:])
	// Rest is already zeros
	
	// Compute new HMAC for next hop
	nextHMAC := common.ComputeHMAC(hmacKeyBytes, append(nextEphemeralKey, nextRoutingBlob...))
	
	// Reassemble packet
	nextPacket := r.assemblePacket(nextEphemeralKey, nextHMAC, nextRoutingBlob, onionPkt.EncryptedPayload)
	
	// Build next address
	nextAddress := r.formatAddress(routing)
	
	return &RoutingDecision{
		Action:      ActionForward,
		NextAddress: nextAddress,
		NextPacket:  nextPacket,
		Delay:       time.Duration(routing.Delay) * time.Millisecond,
	}, nil
}

// parsePacket parses raw bytes into OnionPacket
func (r *Router) parsePacket(data []byte) (*common.OnionPacket, error) {
	if len(data) != common.PacketSize {
		return nil, errors.New("invalid packet size")
	}
	
	pkt := &common.OnionPacket{
		Version:          data[0],
		EphemeralKey:     data[1:33],
		HeaderHMAC:       data[33:65],
		RoutingBlob:      data[65:680],
		EncryptedPayload: data[680:1280],
	}
	
	return pkt, nil
}

// decryptRoutingBlob decrypts the routing blob
func (r *Router) decryptRoutingBlob(key, ciphertext []byte) ([]byte, error) {
	aead, err := chacha20poly1305.New(key)
	if err != nil {
		return nil, err
	}
	
	// Use first 12 bytes of ciphertext as nonce
	if len(ciphertext) < 12 {
		return nil, errors.New("ciphertext too short")
	}
	
	nonce := ciphertext[:12]
	
	// Decrypt (no AAD for routing blob)
	plaintext, err := aead.Open(nil, nonce, ciphertext[12:], nil)
	if err != nil {
		return nil, err
	}
	
	return plaintext, nil
}

// decryptPayload decrypts the payload
func (r *Router) decryptPayload(key, ciphertext []byte) ([]byte, error) {
	aead, err := chacha20poly1305.New(key)
	if err != nil {
		return nil, err
	}
	
	if len(ciphertext) < 12 {
		return nil, errors.New("ciphertext too short")
	}
	
	nonce := ciphertext[:12]
	
	plaintext, err := aead.Open(nil, nonce, ciphertext[12:], nil)
	if err != nil {
		return nil, err
	}
	
	return plaintext, nil
}

// parseRoutingInfo parses routing information
func (r *Router) parseRoutingInfo(data []byte) (*common.RoutingInfo, error) {
	if len(data) < 31 {
		return nil, errors.New("routing info too short")
	}
	
	info := &common.RoutingInfo{
		AddressType: data[0],
		Port:        binary.BigEndian.Uint16(data[17:19]),
		Delay:       binary.BigEndian.Uint16(data[27:29]),
	}
	
	// Parse address based on type
	switch info.AddressType {
	case 0x04: // IPv4
		info.Address = data[1:5]
	case 0x06: // IPv6
		info.Address = data[1:17]
	case 0x00: // Final hop
		info.Address = nil
	default:
		return nil, fmt.Errorf("unknown address type: 0x%02x", info.AddressType)
	}
	
	// Parse expiry timestamp
	expiryUnix := int64(binary.BigEndian.Uint64(data[19:27]))
	info.Expiry = time.Unix(expiryUnix, 0)
	
	// Extract HMAC
	if len(data) >= 61 {
		info.HMAC = data[29:61]
	}
	
	return info, nil
}

// formatAddress formats routing info into address string
func (r *Router) formatAddress(routing *common.RoutingInfo) string {
	if routing.AddressType == 0x04 { // IPv4
		return fmt.Sprintf("%d.%d.%d.%d:%d",
			routing.Address[0], routing.Address[1],
			routing.Address[2], routing.Address[3],
			routing.Port)
	} else if routing.AddressType == 0x06 { // IPv6
		return fmt.Sprintf("[%x:%x:%x:%x:%x:%x:%x:%x]:%d",
			binary.BigEndian.Uint16(routing.Address[0:2]),
			binary.BigEndian.Uint16(routing.Address[2:4]),
			binary.BigEndian.Uint16(routing.Address[4:6]),
			binary.BigEndian.Uint16(routing.Address[6:8]),
			binary.BigEndian.Uint16(routing.Address[8:10]),
			binary.BigEndian.Uint16(routing.Address[10:12]),
			binary.BigEndian.Uint16(routing.Address[12:14]),
			binary.BigEndian.Uint16(routing.Address[14:16]),
			routing.Port)
	}
	return ""
}

// assemblePacket assembles a new packet for forwarding
func (r *Router) assemblePacket(ephemeralKey, hmac, routingBlob, payload []byte) []byte {
	packet := make([]byte, common.PacketSize)
	packet[0] = common.PacketVersion
	copy(packet[1:33], ephemeralKey)
	copy(packet[33:65], hmac)
	copy(packet[65:680], routingBlob)
	copy(packet[680:1280], payload)
	return packet
}

// cleanupReplayCache periodically removes old entries
func (r *Router) cleanupReplayCache() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	
	for range ticker.C {
		cutoff := time.Now().Add(-5 * time.Minute)
		
		r.seenHMACs.Range(func(key, value interface{}) bool {
			if timestamp, ok := value.(time.Time); ok {
				if timestamp.Before(cutoff) {
					r.seenHMACs.Delete(key)
				}
			}
			return true
		})
	}
}

// GetStats returns router statistics
func (r *Router) GetStats() Stats {
	return Stats{
		PacketsProcessed: r.packetsProcessed,
		PacketsForwarded: r.packetsForwarded,
		PacketsDelivered: r.packetsDelivered,
		PacketsDropped:   r.packetsDropped,
	}
}

// RoutingDecision represents the result of packet processing
type RoutingDecision struct {
	Action      Action
	NextAddress string // For forwarding
	NextPacket  []byte // For forwarding
	Payload     []byte // For delivery
	Delay       time.Duration
}

// Action defines what to do with packet
type Action int

const (
	ActionForward Action = iota
	ActionDeliver
)

// Stats contains router statistics
type Stats struct {
	PacketsProcessed uint64
	PacketsForwarded uint64
	PacketsDelivered uint64
	PacketsDropped   uint64
}

// ed25519PrivateKeyToCurve25519 converts Ed25519 private key to Curve25519
// This is a simplified conversion; production should use proper conversion
func ed25519PrivateKeyToCurve25519(edPriv ed25519.PrivateKey) []byte {
	// In production, use proper Ed25519->Curve25519 conversion
	// For now, use the seed (first 32 bytes)
	seed := edPriv.Seed()
	curve25519Priv := make([]byte, 32)
	copy(curve25519Priv, seed)
	return curve25519Priv
}
