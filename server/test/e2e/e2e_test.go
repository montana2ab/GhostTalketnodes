package e2e

import (
	"bytes"
	"crypto/ed25519"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gorilla/mux"
	"github.com/montana2ab/GhostTalketnodes/server/pkg/common"
	"github.com/montana2ab/GhostTalketnodes/server/pkg/directory"
	"github.com/montana2ab/GhostTalketnodes/server/pkg/onion"
	"github.com/montana2ab/GhostTalketnodes/server/pkg/swarm"
)

// TestNode represents a test service node
type TestNode struct {
	ID         string
	PrivateKey ed25519.PrivateKey
	Router     *onion.Router
	Swarm      *swarm.Store
	Directory  *directory.Service
	Server     *httptest.Server
}

// SetupTestNode creates a test node for E2E testing
func SetupTestNode(t *testing.T, id string) *TestNode {
	// Generate key pair
	_, priv, err := common.GenerateKeypair()
	if err != nil {
		t.Fatalf("Failed to generate keypair: %v", err)
	}

	// Initialize components
	router := onion.NewRouter(priv)
	storage := swarm.NewMemoryStorage()
	swarmStore := swarm.NewStore(storage, []string{}, 3, 14)
	directoryService := directory.NewService(priv)

	// Create HTTP server
	r := mux.NewRouter()
	
	node := &TestNode{
		ID:         id,
		PrivateKey: priv,
		Router:     router,
		Swarm:      swarmStore,
		Directory:  directoryService,
	}

	// Register handlers
	r.HandleFunc("/v1/onion", node.handleOnionPacket).Methods("POST")
	r.HandleFunc("/v1/swarm/messages/{sessionID}", node.handleRetrieveMessages).Methods("GET")
	r.HandleFunc("/v1/swarm/messages", node.handleStoreMessage).Methods("POST")
	r.HandleFunc("/health", node.handleHealth).Methods("GET")

	node.Server = httptest.NewServer(r)
	
	return node
}

func (n *TestNode) handleOnionPacket(w http.ResponseWriter, r *http.Request) {
	packet := make([]byte, common.PacketSize)
	_, err := r.Body.Read(packet)
	if err != nil && err.Error() != "EOF" {
		http.Error(w, "Failed to read packet", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	decision, err := n.Router.ProcessPacket(packet)
	if err != nil {
		http.Error(w, "Invalid packet", http.StatusBadRequest)
		return
	}

	switch decision.Action {
	case onion.ActionDeliver:
		var msg common.Message
		if err := json.Unmarshal(decision.Payload, &msg); err == nil {
			n.Swarm.StoreMessage(&msg)
		}
		w.WriteHeader(http.StatusOK)
	case onion.ActionForward:
		w.WriteHeader(http.StatusAccepted)
	}
}

func (n *TestNode) handleStoreMessage(w http.ResponseWriter, r *http.Request) {
	var msg common.Message
	if err := json.NewDecoder(r.Body).Decode(&msg); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	if err := n.Swarm.StoreMessage(&msg); err != nil {
		http.Error(w, "Failed to store message", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"status": "stored"})
}

func (n *TestNode) handleRetrieveMessages(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	sessionID := vars["sessionID"]

	messages, err := n.Swarm.RetrieveMessages(sessionID)
	if err != nil {
		http.Error(w, "Failed to retrieve messages", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(messages)
}

func (n *TestNode) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func (n *TestNode) Close() {
	if n.Server != nil {
		n.Server.Close()
	}
}

// TestMessageStoreAndRetrieve tests basic store and forward functionality
func TestMessageStoreAndRetrieve(t *testing.T) {
	node := SetupTestNode(t, "node1")
	defer node.Close()

	// Create a test message
	msg := &common.Message{
		ID:               "msg-001",
		DestinationID:    "destination-session-id",
		Timestamp:        time.Now(),
		MessageType:      common.MessageTypeText,
		EncryptedContent: []byte("encrypted content"),
		TTL:              time.Now().Add(24 * time.Hour),
		ReplicaCount:     1,
	}

	// Store message
	msgJSON, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Failed to marshal message: %v", err)
	}

	resp, err := http.Post(
		fmt.Sprintf("%s/v1/swarm/messages", node.Server.URL),
		"application/json",
		bytes.NewReader(msgJSON),
	)
	if err != nil {
		t.Fatalf("Failed to store message: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		t.Errorf("Expected status 201, got %d", resp.StatusCode)
	}

	// Retrieve messages
	resp, err = http.Get(
		fmt.Sprintf("%s/v1/swarm/messages/%s", node.Server.URL, msg.DestinationID),
	)
	if err != nil {
		t.Fatalf("Failed to retrieve messages: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Expected status 200, got %d", resp.StatusCode)
	}

	var messages []*common.Message
	if err := json.NewDecoder(resp.Body).Decode(&messages); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if len(messages) != 1 {
		t.Errorf("Expected 1 message, got %d", len(messages))
	}

	if len(messages) > 0 && messages[0].ID != msg.ID {
		t.Errorf("Expected message ID %s, got %s", msg.ID, messages[0].ID)
	}
}

// TestMultiNodeCoordination tests coordination between multiple nodes
func TestMultiNodeCoordination(t *testing.T) {
	// Setup 3 nodes
	node1 := SetupTestNode(t, "node1")
	node2 := SetupTestNode(t, "node2")
	node3 := SetupTestNode(t, "node3")
	defer node1.Close()
	defer node2.Close()
	defer node3.Close()

	// Test message distribution across nodes
	msg := &common.Message{
		ID:               "msg-multi-001",
		DestinationID:    "test-session-id",
		Timestamp:        time.Now(),
		MessageType:      common.MessageTypeText,
		EncryptedContent: []byte("test message"),
		TTL:              time.Now().Add(24 * time.Hour),
		ReplicaCount:     3,
	}

	// Store message on node1
	msgJSON, _ := json.Marshal(msg)
	resp, err := http.Post(
		fmt.Sprintf("%s/v1/swarm/messages", node1.Server.URL),
		"application/json",
		bytes.NewReader(msgJSON),
	)
	if err != nil {
		t.Fatalf("Failed to store message: %v", err)
	}
	resp.Body.Close()

	// Verify message is stored on node1
	resp, err = http.Get(
		fmt.Sprintf("%s/v1/swarm/messages/%s", node1.Server.URL, msg.DestinationID),
	)
	if err != nil {
		t.Fatalf("Failed to retrieve from node1: %v", err)
	}
	
	var messages []*common.Message
	json.NewDecoder(resp.Body).Decode(&messages)
	resp.Body.Close()

	if len(messages) == 0 {
		t.Error("Message not found on node1")
	}

	// Note: In a real implementation, messages would be replicated to other nodes
	// This test verifies the basic storage mechanism is working
}

// TestHealthCheck tests node health checking
func TestHealthCheck(t *testing.T) {
	node := SetupTestNode(t, "node1")
	defer node.Close()

	resp, err := http.Get(fmt.Sprintf("%s/health", node.Server.URL))
	if err != nil {
		t.Fatalf("Health check failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Expected status 200, got %d", resp.StatusCode)
	}

	var result map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if result["status"] != "healthy" {
		t.Errorf("Expected status 'healthy', got '%s'", result["status"])
	}
}

// TestMessageExpiration tests that messages expire after TTL
func TestMessageExpiration(t *testing.T) {
	node := SetupTestNode(t, "node1")
	defer node.Close()

	// Create a message with short TTL
	msg := &common.Message{
		ID:               "msg-expire-001",
		DestinationID:    "test-session",
		Timestamp:        time.Now(),
		MessageType:      common.MessageTypeText,
		EncryptedContent: []byte("will expire"),
		TTL:              time.Now().Add(100 * time.Millisecond), // Short TTL
		ReplicaCount:     1,
	}

	// Store message
	msgJSON, _ := json.Marshal(msg)
	resp, _ := http.Post(
		fmt.Sprintf("%s/v1/swarm/messages", node.Server.URL),
		"application/json",
		bytes.NewReader(msgJSON),
	)
	resp.Body.Close()

	// Wait for expiration
	time.Sleep(200 * time.Millisecond)

	// Trigger cleanup
	node.Swarm.CleanupExpired()

	// Try to retrieve - should be empty or not found
	resp, _ = http.Get(
		fmt.Sprintf("%s/v1/swarm/messages/%s", node.Server.URL, msg.DestinationID),
	)
	defer resp.Body.Close()

	var messages []*common.Message
	json.NewDecoder(resp.Body).Decode(&messages)

	// After cleanup, expired messages should be removed
	if len(messages) > 0 && messages[0].TTL.Before(time.Now()) {
		t.Error("Expired message was not cleaned up")
	}
}

// TestConcurrentMessageStorage tests storing messages concurrently
func TestConcurrentMessageStorage(t *testing.T) {
	node := SetupTestNode(t, "node1")
	defer node.Close()

	const numMessages = 10
	done := make(chan bool, numMessages)

	// Store messages concurrently
	for i := 0; i < numMessages; i++ {
		go func(id int) {
			msg := &common.Message{
				ID:               fmt.Sprintf("msg-concurrent-%d", id),
				DestinationID:    "concurrent-session",
				Timestamp:        time.Now(),
				MessageType:      common.MessageTypeText,
				EncryptedContent: []byte(fmt.Sprintf("message %d", id)),
				TTL:              time.Now().Add(24 * time.Hour),
				ReplicaCount:     1,
			}

			msgJSON, _ := json.Marshal(msg)
			resp, err := http.Post(
				fmt.Sprintf("%s/v1/swarm/messages", node.Server.URL),
				"application/json",
				bytes.NewReader(msgJSON),
			)
			if err == nil {
				resp.Body.Close()
			}
			done <- true
		}(i)
	}

	// Wait for all goroutines
	for i := 0; i < numMessages; i++ {
		<-done
	}

	// Retrieve all messages
	resp, err := http.Get(
		fmt.Sprintf("%s/v1/swarm/messages/concurrent-session", node.Server.URL),
	)
	if err != nil {
		t.Fatalf("Failed to retrieve messages: %v", err)
	}
	defer resp.Body.Close()

	var messages []*common.Message
	json.NewDecoder(resp.Body).Decode(&messages)

	if len(messages) != numMessages {
		t.Errorf("Expected %d messages, got %d", numMessages, len(messages))
	}
}

// TestInvalidPacket tests handling of invalid onion packets
func TestInvalidPacket(t *testing.T) {
	node := SetupTestNode(t, "node1")
	defer node.Close()

	tests := []struct {
		name   string
		packet []byte
	}{
		{"empty packet", []byte{}},
		{"too small", make([]byte, 100)},
		{"invalid version", append([]byte{0xFF}, make([]byte, common.PacketSize-1)...)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := http.Post(
				fmt.Sprintf("%s/v1/onion", node.Server.URL),
				"application/octet-stream",
				bytes.NewReader(tt.packet),
			)
			if err != nil {
				t.Fatalf("Request failed: %v", err)
			}
			defer resp.Body.Close()

			if resp.StatusCode == http.StatusOK {
				t.Error("Expected error for invalid packet, got 200 OK")
			}
		})
	}
}

// TestMessageTypes tests different message types
func TestMessageTypes(t *testing.T) {
	node := SetupTestNode(t, "node1")
	defer node.Close()

	messageTypes := []struct {
		msgType byte
		name    string
	}{
		{common.MessageTypeText, "text"},
		{common.MessageTypeAttachment, "attachment"},
		{common.MessageTypeTypingIndicator, "typing"},
		{common.MessageTypeReadReceipt, "read receipt"},
		{common.MessageTypeDeliveryReceipt, "delivery receipt"},
	}

	for _, mt := range messageTypes {
		t.Run(mt.name, func(t *testing.T) {
			msg := &common.Message{
				ID:               fmt.Sprintf("msg-%s", mt.name),
				DestinationID:    "type-test-session",
				Timestamp:        time.Now(),
				MessageType:      mt.msgType,
				EncryptedContent: []byte("test content"),
				TTL:              time.Now().Add(24 * time.Hour),
				ReplicaCount:     1,
			}

			msgJSON, _ := json.Marshal(msg)
			resp, err := http.Post(
				fmt.Sprintf("%s/v1/swarm/messages", node.Server.URL),
				"application/json",
				bytes.NewReader(msgJSON),
			)
			if err != nil {
				t.Fatalf("Failed to store message: %v", err)
			}
			resp.Body.Close()

			if resp.StatusCode != http.StatusCreated {
				t.Errorf("Expected status 201, got %d", resp.StatusCode)
			}
		})
	}
}
