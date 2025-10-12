package common

import (
	"crypto/ed25519"
	"time"
)

// NodeInfo represents information about a service node
type NodeInfo struct {
	ID         string           `json:"id"`
	PublicKey  ed25519.PublicKey `json:"public_key"`
	Address    string           `json:"address"`
	Port       uint16           `json:"port"`
	LastSeen   time.Time        `json:"last_seen"`
	Version    string           `json:"version"`
	Healthy    bool             `json:"healthy"`
}

// OnionPacket represents a Sphinx-like onion packet
type OnionPacket struct {
	Version        byte   `json:"version"`
	EphemeralKey   []byte `json:"ephemeral_key"`   // 32 bytes
	HeaderHMAC     []byte `json:"header_hmac"`     // 32 bytes
	RoutingBlob    []byte `json:"routing_blob"`    // 615 bytes
	EncryptedPayload []byte `json:"encrypted_payload"` // 600 bytes
}

// RoutingInfo contains routing information for one hop
type RoutingInfo struct {
	AddressType byte      `json:"address_type"` // 0x04=IPv4, 0x06=IPv6
	Address     []byte    `json:"address"`
	Port        uint16    `json:"port"`
	Expiry      time.Time `json:"expiry"`
	Delay       uint16    `json:"delay"` // milliseconds
	HMAC        []byte    `json:"hmac"`
}

// Message represents an E2EE encrypted message
type Message struct {
	ID              string    `json:"id"`
	DestinationID   string    `json:"destination_id"` // SessionID (public key)
	Timestamp       time.Time `json:"timestamp"`
	MessageType     byte      `json:"message_type"`
	EncryptedContent []byte   `json:"encrypted_content"`
	TTL             time.Time `json:"ttl"`
	ReplicaCount    int       `json:"replica_count"`
}

// MessageType constants
const (
	MessageTypeText            byte = 0x01
	MessageTypeAttachment      byte = 0x02
	MessageTypeTypingIndicator byte = 0x03
	MessageTypeReadReceipt     byte = 0x04
	MessageTypeDeliveryReceipt byte = 0x05
)

// SwarmInfo represents information about a swarm
type SwarmInfo struct {
	SwarmID   string   `json:"swarm_id"`
	Nodes     []string `json:"nodes"` // Node IDs
	Replicas  int      `json:"replicas"`
	MessageCount int   `json:"message_count"`
}

// BootstrapSet is a signed list of bootstrap nodes
type BootstrapSet struct {
	Version   int        `json:"version"`
	Timestamp time.Time  `json:"timestamp"`
	Nodes     []NodeInfo `json:"nodes"`
	Signature []byte     `json:"signature"`
}

// Config represents the service node configuration
type Config struct {
	NodeID         string `yaml:"node_id"`
	PrivateKeyFile string `yaml:"private_key_file"`
	
	ListenAddress  string `yaml:"listen_address"`
	PublicAddress  string `yaml:"public_address"`
	
	BootstrapNodes []string `yaml:"bootstrap_nodes"`
	
	TLS struct {
		CertFile string `yaml:"cert_file"`
		KeyFile  string `yaml:"key_file"`
	} `yaml:"tls"`
	
	MTLS struct {
		Enabled  bool   `yaml:"enabled"`
		CAFile   string `yaml:"ca_file"`
		CertFile string `yaml:"cert_file"`
		KeyFile  string `yaml:"key_file"`
	} `yaml:"mtls"`
	
	Storage struct {
		Backend   string `yaml:"backend"` // "rocksdb" or "postgres"
		Path      string `yaml:"path"`
		MaxSizeGB int    `yaml:"max_size_gb"`
	} `yaml:"storage"`
	
	Swarm struct {
		ReplicationFactor int `yaml:"replication_factor"`
		TTLDays           int `yaml:"ttl_days"`
	} `yaml:"swarm"`
	
	RateLimit struct {
		Enabled            bool `yaml:"enabled"`
		RequestsPerSecond  int  `yaml:"requests_per_second"`
		Burst              int  `yaml:"burst"`
	} `yaml:"rate_limit"`
	
	PoW struct {
		Enabled    bool `yaml:"enabled"`
		Difficulty int  `yaml:"difficulty"` // bits
	} `yaml:"pow"`
	
	Metrics struct {
		Enabled       bool   `yaml:"enabled"`
		ListenAddress string `yaml:"listen_address"`
	} `yaml:"metrics"`
	
	Logging struct {
		Level  string `yaml:"level"`
		Format string `yaml:"format"`
		Output string `yaml:"output"`
	} `yaml:"logging"`
}

// Constants for packet format
const (
	PacketVersion       byte = 0x01
	PacketSize               = 1280
	HeaderSize               = 65
	RoutingBlobSize          = 615
	PayloadSize              = 600
	EphemeralKeySize         = 32
	HMACSize                 = 32
	PerHopRoutingSize        = 205
)
