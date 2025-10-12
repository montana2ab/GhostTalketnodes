package directory

import (
	"crypto/ed25519"
	"encoding/json"
	"errors"
	"hash/crc32"
	"sort"
	"sync"
	"time"

	"github.com/montana2ab/GhostTalketnodes/server/pkg/common"
)

// Service manages node directory and swarm assignment
type Service struct {
	nodes      map[string]*common.NodeInfo
	hashRing   *ConsistentHashRing
	signingKey ed25519.PrivateKey
	mu         sync.RWMutex
}

// NewService creates a new directory service
func NewService(signingKey ed25519.PrivateKey) *Service {
	return &Service{
		nodes:      make(map[string]*common.NodeInfo),
		hashRing:   NewConsistentHashRing(3), // 3 virtual nodes per physical node
		signingKey: signingKey,
	}
}

// RegisterNode registers a node in the directory
func (s *Service) RegisterNode(node *common.NodeInfo) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	node.LastSeen = time.Now()
	node.Healthy = true
	
	s.nodes[node.ID] = node
	s.hashRing.AddNode(node.ID)
	
	return nil
}

// UnregisterNode removes a node from the directory
func (s *Service) UnregisterNode(nodeID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	delete(s.nodes, nodeID)
	s.hashRing.RemoveNode(nodeID)
	
	return nil
}

// GetNode retrieves node information
func (s *Service) GetNode(nodeID string) (*common.NodeInfo, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	node, ok := s.nodes[nodeID]
	if !ok {
		return nil, errors.New("node not found")
	}
	
	return node, nil
}

// ListNodes returns all registered nodes
func (s *Service) ListNodes() []*common.NodeInfo {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	nodes := make([]*common.NodeInfo, 0, len(s.nodes))
	for _, node := range s.nodes {
		nodes = append(nodes, node)
	}
	
	return nodes
}

// GetBootstrapSet returns a signed bootstrap set
func (s *Service) GetBootstrapSet() (*common.BootstrapSet, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	// Get healthy nodes only
	nodes := make([]common.NodeInfo, 0)
	for _, node := range s.nodes {
		if node.Healthy {
			nodes = append(nodes, *node)
		}
	}
	
	if len(nodes) == 0 {
		return nil, errors.New("no healthy nodes available")
	}
	
	bootstrap := &common.BootstrapSet{
		Version:   1,
		Timestamp: time.Now(),
		Nodes:     nodes,
	}
	
	// Sign the bootstrap set
	data, err := json.Marshal(bootstrap)
	if err != nil {
		return nil, err
	}
	
	signature := ed25519.Sign(s.signingKey, data)
	bootstrap.Signature = signature
	
	return bootstrap, nil
}

// GetSwarmNodes returns nodes responsible for a session ID (k replicas)
func (s *Service) GetSwarmNodes(sessionID string, k int) ([]string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	if len(s.nodes) < k {
		k = len(s.nodes)
	}
	
	if k == 0 {
		return nil, errors.New("no nodes available")
	}
	
	// Use consistent hashing to find k nodes
	nodeIDs := s.hashRing.GetNodes(sessionID, k)
	
	return nodeIDs, nil
}

// UpdateNodeHealth updates node health status
func (s *Service) UpdateNodeHealth(nodeID string, healthy bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	node, ok := s.nodes[nodeID]
	if !ok {
		return errors.New("node not found")
	}
	
	node.Healthy = healthy
	node.LastSeen = time.Now()
	
	return nil
}

// HealthCheck performs health checks on all nodes
func (s *Service) HealthCheck() {
	s.mu.Lock()
	defer s.mu.Unlock()
	
	cutoff := time.Now().Add(-5 * time.Minute)
	
	for _, node := range s.nodes {
		if node.LastSeen.Before(cutoff) {
			node.Healthy = false
		}
	}
}

// ConsistentHashRing implements consistent hashing for swarm assignment
type ConsistentHashRing struct {
	ring          []uint32
	nodeMap       map[uint32]string
	virtualNodes  int
	mu            sync.RWMutex
}

// NewConsistentHashRing creates a new hash ring
func NewConsistentHashRing(virtualNodes int) *ConsistentHashRing {
	return &ConsistentHashRing{
		ring:         make([]uint32, 0),
		nodeMap:      make(map[uint32]string),
		virtualNodes: virtualNodes,
	}
}

// AddNode adds a node to the ring
func (r *ConsistentHashRing) AddNode(nodeID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	// Add virtual nodes
	for i := 0; i < r.virtualNodes; i++ {
		hash := r.hash(nodeID + ":" + string(rune(i)))
		r.ring = append(r.ring, hash)
		r.nodeMap[hash] = nodeID
	}
	
	// Sort ring
	sort.Slice(r.ring, func(i, j int) bool {
		return r.ring[i] < r.ring[j]
	})
}

// RemoveNode removes a node from the ring
func (r *ConsistentHashRing) RemoveNode(nodeID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	// Remove virtual nodes
	for i := 0; i < r.virtualNodes; i++ {
		hash := r.hash(nodeID + ":" + string(rune(i)))
		
		// Remove from nodeMap
		delete(r.nodeMap, hash)
		
		// Remove from ring
		for j, h := range r.ring {
			if h == hash {
				r.ring = append(r.ring[:j], r.ring[j+1:]...)
				break
			}
		}
	}
}

// GetNodes returns k nodes for a given key
func (r *ConsistentHashRing) GetNodes(key string, k int) []string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	
	if len(r.ring) == 0 {
		return nil
	}
	
	hash := r.hash(key)
	
	// Find position in ring
	idx := sort.Search(len(r.ring), func(i int) bool {
		return r.ring[i] >= hash
	})
	
	// Wrap around if necessary
	if idx >= len(r.ring) {
		idx = 0
	}
	
	// Collect k unique nodes
	seen := make(map[string]bool)
	nodes := make([]string, 0, k)
	
	for i := 0; i < len(r.ring) && len(nodes) < k; i++ {
		ringIdx := (idx + i) % len(r.ring)
		nodeID := r.nodeMap[r.ring[ringIdx]]
		
		if !seen[nodeID] {
			seen[nodeID] = true
			nodes = append(nodes, nodeID)
		}
	}
	
	return nodes
}

// hash computes CRC32 hash
func (r *ConsistentHashRing) hash(key string) uint32 {
	return crc32.ChecksumIEEE([]byte(key))
}
