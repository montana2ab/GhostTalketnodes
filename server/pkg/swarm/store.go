package swarm

import (
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"sync"
	"time"

	"github.com/montana2ab/GhostTalketnodes/server/pkg/common"
)

// Store handles store-and-forward message storage with k-replication
type Store struct {
	storage      Storage
	replicaPeers []string
	replicaCount int
	ttl          time.Duration
	httpClient   *http.Client
	
	// Stats
	messagesStored   uint64
	messagesDelivered uint64
	messagesExpired  uint64
	
	mu sync.RWMutex
}

// Storage interface for pluggable backends
type Storage interface {
	Store(key string, value []byte) error
	Retrieve(key string) ([]byte, error)
	Delete(key string) error
	List(prefix string) ([]string, error)
	Close() error
}

// NewStore creates a new swarm store
func NewStore(storage Storage, replicaPeers []string, replicaCount int, ttlDays int) *Store {
	return &Store{
		storage:      storage,
		replicaPeers: replicaPeers,
		replicaCount: replicaCount,
		ttl:          time.Duration(ttlDays) * 24 * time.Hour,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
			Transport: &http.Transport{
				MaxIdleConns:        100,
				MaxIdleConnsPerHost: 10,
				IdleConnTimeout:     90 * time.Second,
			},
		},
	}
}

// StoreMessage stores a message for a recipient
func (s *Store) StoreMessage(msg *common.Message) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	// Set TTL if not set
	if msg.TTL.IsZero() {
		msg.TTL = time.Now().Add(s.ttl)
	}
	
	// Set replica count
	msg.ReplicaCount = s.replicaCount
	
	// Serialize message
	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("marshal error: %w", err)
	}
	
	// Store locally
	key := s.messageKey(msg.DestinationID, msg.ID)
	if err := s.storage.Store(key, data); err != nil {
		return fmt.Errorf("storage error: %w", err)
	}
	
	s.messagesStored++
	
	// Replicate to peers (async)
	go s.replicateToPeers(msg)
	
	return nil
}

// RetrieveMessages retrieves all messages for a session ID
func (s *Store) RetrieveMessages(sessionID string) ([]*common.Message, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	// List all message keys for this session
	prefix := s.sessionPrefix(sessionID)
	keys, err := s.storage.List(prefix)
	if err != nil {
		return nil, fmt.Errorf("list error: %w", err)
	}
	
	// Retrieve each message
	messages := make([]*common.Message, 0, len(keys))
	for _, key := range keys {
		data, err := s.storage.Retrieve(key)
		if err != nil {
			continue // Skip corrupted messages
		}
		
		var msg common.Message
		if err := json.Unmarshal(data, &msg); err != nil {
			continue // Skip corrupted messages
		}
		
		// Check TTL
		if time.Now().After(msg.TTL) {
			// Expired, delete it
			s.storage.Delete(key)
			s.messagesExpired++
			continue
		}
		
		messages = append(messages, &msg)
	}
	
	s.messagesDelivered += uint64(len(messages))
	
	return messages, nil
}

// DeleteMessage deletes a message after delivery
func (s *Store) DeleteMessage(sessionID, messageID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	key := s.messageKey(sessionID, messageID)
	if err := s.storage.Delete(key); err != nil {
		return fmt.Errorf("delete error: %w", err)
	}
	
	// Delete from replicas (async)
	go s.deleteFromPeers(sessionID, messageID)
	
	return nil
}

// CleanupExpired removes expired messages
func (s *Store) CleanupExpired() (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	// List all messages
	keys, err := s.storage.List("messages/")
	if err != nil {
		return 0, err
	}
	
	count := 0
	for _, key := range keys {
		data, err := s.storage.Retrieve(key)
		if err != nil {
			continue
		}
		
		var msg common.Message
		if err := json.Unmarshal(data, &msg); err != nil {
			continue
		}
		
		// Check TTL
		if time.Now().After(msg.TTL) {
			s.storage.Delete(key)
			s.messagesExpired++
			count++
		}
	}
	
	return count, nil
}

// GetStats returns store statistics
func (s *Store) GetStats() Stats {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	return Stats{
		MessagesStored:    s.messagesStored,
		MessagesDelivered: s.messagesDelivered,
		MessagesExpired:   s.messagesExpired,
	}
}

// messageKey generates storage key for a message
func (s *Store) messageKey(sessionID, messageID string) string {
	return fmt.Sprintf("messages/%s/%s", sessionID, messageID)
}

// sessionPrefix generates prefix for listing session messages
func (s *Store) sessionPrefix(sessionID string) string {
	return fmt.Sprintf("messages/%s/", sessionID)
}

// replicateToPeers replicates message to peer nodes
func (s *Store) replicateToPeers(msg *common.Message) {
	// Select k peers for replication using consistent hashing
	peers := s.selectReplicationPeers(msg.DestinationID)
	
	// Serialize message for replication
	data, err := json.Marshal(msg)
	if err != nil {
		// Log error but don't fail the operation
		return
	}
	
	// Replicate to each peer
	for _, peer := range peers {
		go func(peerAddr string) {
			url := fmt.Sprintf("https://%s/v1/swarm/replicate", peerAddr)
			
			// Create replication request
			req, err := http.NewRequest("POST", url, bytes.NewReader(data))
			if err != nil {
				return
			}
			req.Header.Set("Content-Type", "application/json")
			
			// Send replication request
			resp, err := s.httpClient.Do(req)
			if err != nil {
				// Log error but continue with other peers
				return
			}
			defer resp.Body.Close()
			
			// Check response status
			if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
				// Log warning but continue
				return
			}
		}(peer)
	}
}

// deleteFromPeers deletes message from replica nodes
func (s *Store) deleteFromPeers(sessionID, messageID string) {
	// Select same peers that were used for replication
	peers := s.selectReplicationPeers(sessionID)
	
	// Delete from each peer
	for _, peer := range peers {
		go func(peerAddr string) {
			url := fmt.Sprintf("https://%s/v1/swarm/messages/%s/%s", peerAddr, sessionID, messageID)
			
			// Create delete request
			req, err := http.NewRequest("DELETE", url, nil)
			if err != nil {
				return
			}
			
			// Send delete request
			resp, err := s.httpClient.Do(req)
			if err != nil {
				// Log error but continue with other peers
				return
			}
			defer resp.Body.Close()
			
			// Check response status (200 OK or 404 Not Found are both acceptable)
			if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNotFound {
				// Log warning but continue
				return
			}
		}(peer)
	}
}

// selectReplicationPeers selects k peers for replication using consistent hashing
func (s *Store) selectReplicationPeers(sessionID string) []string {
	if len(s.replicaPeers) == 0 {
		return []string{}
	}
	
	k := s.replicaCount
	if k > len(s.replicaPeers) {
		k = len(s.replicaPeers)
	}
	
	// Use consistent hashing to select peers
	// Hash the session ID to get a starting point on the ring
	hash := hashString(sessionID)
	
	// Create a sorted list of peers with their hash values
	type peerHash struct {
		peer string
		hash uint64
	}
	
	peerHashes := make([]peerHash, len(s.replicaPeers))
	for i, peer := range s.replicaPeers {
		peerHashes[i] = peerHash{
			peer: peer,
			hash: hashString(peer),
		}
	}
	
	// Sort by hash value
	sort.Slice(peerHashes, func(i, j int) bool {
		return peerHashes[i].hash < peerHashes[j].hash
	})
	
	// Find the starting position on the ring
	startIdx := 0
	for i, ph := range peerHashes {
		if ph.hash >= hash {
			startIdx = i
			break
		}
	}
	
	// Select k peers starting from that position (wrapping around)
	selected := make([]string, 0, k)
	for i := 0; i < k; i++ {
		idx := (startIdx + i) % len(peerHashes)
		selected = append(selected, peerHashes[idx].peer)
	}
	
	return selected
}

// hashString computes a consistent hash of a string
func hashString(s string) uint64 {
	h := sha256.Sum256([]byte(s))
	// Use first 8 bytes as uint64
	return binary.BigEndian.Uint64(h[:8])
}

// Stats contains store statistics
type Stats struct {
	MessagesStored    uint64
	MessagesDelivered uint64
	MessagesExpired   uint64
}

// MemoryStorage is an in-memory storage implementation for testing
type MemoryStorage struct {
	data map[string][]byte
	mu   sync.RWMutex
}

// NewMemoryStorage creates a new memory storage
func NewMemoryStorage() *MemoryStorage {
	return &MemoryStorage{
		data: make(map[string][]byte),
	}
}

func (m *MemoryStorage) Store(key string, value []byte) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.data[key] = value
	return nil
}

func (m *MemoryStorage) Retrieve(key string) ([]byte, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	
	value, ok := m.data[key]
	if !ok {
		return nil, errors.New("key not found")
	}
	
	return value, nil
}

func (m *MemoryStorage) Delete(key string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	delete(m.data, key)
	return nil
}

func (m *MemoryStorage) List(prefix string) ([]string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	
	keys := make([]string, 0)
	for key := range m.data {
		if len(key) >= len(prefix) && key[:len(prefix)] == prefix {
			keys = append(keys, key)
		}
	}
	
	return keys, nil
}

func (m *MemoryStorage) Close() error {
	return nil
}
