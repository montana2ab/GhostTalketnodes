package swarm

import (
	"testing"
	"time"

	"github.com/montana2ab/GhostTalketnodes/server/pkg/common"
)

func TestNewStore(t *testing.T) {
	storage := NewMemoryStorage()
	peers := []string{"peer1:9000", "peer2:9000", "peer3:9000"}
	replicaCount := 2
	ttlDays := 14

	store := NewStore(storage, peers, replicaCount, ttlDays)

	if store == nil {
		t.Fatal("NewStore returned nil")
	}

	if store.replicaCount != replicaCount {
		t.Errorf("Expected replica count %d, got %d", replicaCount, store.replicaCount)
	}

	if store.ttl != time.Duration(ttlDays)*24*time.Hour {
		t.Errorf("Expected TTL %v, got %v", time.Duration(ttlDays)*24*time.Hour, store.ttl)
	}
}

func TestStoreMessage(t *testing.T) {
	storage := NewMemoryStorage()
	peers := []string{"peer1:9000", "peer2:9000"}
	store := NewStore(storage, peers, 2, 14)

	msg := &common.Message{
		ID:            "msg1",
		DestinationID: "session123",
		Timestamp:     time.Now(),
	}

	err := store.StoreMessage(msg)
	if err != nil {
		t.Fatalf("StoreMessage failed: %v", err)
	}

	// Verify message was stored
	stats := store.GetStats()
	if stats.MessagesStored != 1 {
		t.Errorf("Expected 1 message stored, got %d", stats.MessagesStored)
	}
}

func TestRetrieveMessages(t *testing.T) {
	storage := NewMemoryStorage()
	peers := []string{"peer1:9000"}
	store := NewStore(storage, peers, 1, 14)

	sessionID := "session123"
	msg1 := &common.Message{
		ID:            "msg1",
		DestinationID: sessionID,
		Timestamp:     time.Now(),
	}
	msg2 := &common.Message{
		ID:            "msg2",
		DestinationID: sessionID,
		Timestamp:     time.Now(),
	}

	// Store messages
	if err := store.StoreMessage(msg1); err != nil {
		t.Fatalf("Failed to store msg1: %v", err)
	}
	if err := store.StoreMessage(msg2); err != nil {
		t.Fatalf("Failed to store msg2: %v", err)
	}

	// Retrieve messages
	messages, err := store.RetrieveMessages(sessionID)
	if err != nil {
		t.Fatalf("RetrieveMessages failed: %v", err)
	}

	if len(messages) != 2 {
		t.Errorf("Expected 2 messages, got %d", len(messages))
	}
}

func TestDeleteMessage(t *testing.T) {
	storage := NewMemoryStorage()
	peers := []string{"peer1:9000"}
	store := NewStore(storage, peers, 1, 14)

	sessionID := "session123"
	msg := &common.Message{
		ID:            "msg1",
		DestinationID: sessionID,
		Timestamp:     time.Now(),
	}

	// Store message
	if err := store.StoreMessage(msg); err != nil {
		t.Fatalf("Failed to store message: %v", err)
	}

	// Delete message
	if err := store.DeleteMessage(sessionID, msg.ID); err != nil {
		t.Fatalf("DeleteMessage failed: %v", err)
	}

	// Verify message was deleted
	messages, err := store.RetrieveMessages(sessionID)
	if err != nil {
		t.Fatalf("RetrieveMessages failed: %v", err)
	}

	if len(messages) != 0 {
		t.Errorf("Expected 0 messages after deletion, got %d", len(messages))
	}
}

func TestConsistentHashing(t *testing.T) {
	peers := []string{
		"peer1.example.com:9000",
		"peer2.example.com:9000",
		"peer3.example.com:9000",
		"peer4.example.com:9000",
		"peer5.example.com:9000",
	}
	storage := NewMemoryStorage()
	store := NewStore(storage, peers, 3, 14)

	// Test that the same session ID always gets the same peers
	sessionID := "session123"
	selected1 := store.selectReplicationPeers(sessionID)
	selected2 := store.selectReplicationPeers(sessionID)

	if len(selected1) != 3 {
		t.Errorf("Expected 3 peers, got %d", len(selected1))
	}

	// Verify consistency
	if len(selected1) != len(selected2) {
		t.Fatalf("Inconsistent peer selection lengths: %d vs %d", len(selected1), len(selected2))
	}

	for i := range selected1 {
		if selected1[i] != selected2[i] {
			t.Errorf("Inconsistent peer selection at index %d: %s vs %s", i, selected1[i], selected2[i])
		}
	}
}

func TestConsistentHashingDifferentSessions(t *testing.T) {
	peers := []string{
		"peer1.example.com:9000",
		"peer2.example.com:9000",
		"peer3.example.com:9000",
		"peer4.example.com:9000",
		"peer5.example.com:9000",
	}
	storage := NewMemoryStorage()
	store := NewStore(storage, peers, 3, 14)

	// Test that different session IDs can get different peers
	session1 := "session123"
	session2 := "session456"

	selected1 := store.selectReplicationPeers(session1)
	selected2 := store.selectReplicationPeers(session2)

	if len(selected1) != 3 || len(selected2) != 3 {
		t.Errorf("Expected 3 peers for each session")
	}

	// Note: Different sessions may or may not get different peers,
	// but the distribution should be relatively even
	// This test just verifies the selection is deterministic
	selected1_again := store.selectReplicationPeers(session1)
	selected2_again := store.selectReplicationPeers(session2)

	for i := range selected1 {
		if selected1[i] != selected1_again[i] {
			t.Errorf("Session1 peer selection not deterministic")
		}
	}

	for i := range selected2 {
		if selected2[i] != selected2_again[i] {
			t.Errorf("Session2 peer selection not deterministic")
		}
	}
}

func TestHashString(t *testing.T) {
	// Test that hash function is deterministic
	input := "test-session-id"
	hash1 := hashString(input)
	hash2 := hashString(input)

	if hash1 != hash2 {
		t.Errorf("Hash function not deterministic: %d vs %d", hash1, hash2)
	}

	// Test that different inputs produce different hashes
	hash3 := hashString("different-session-id")
	if hash1 == hash3 {
		t.Errorf("Different inputs produced same hash (collision)")
	}
}

func TestExpiredMessages(t *testing.T) {
	storage := NewMemoryStorage()
	peers := []string{"peer1:9000"}
	store := NewStore(storage, peers, 1, 14)

	sessionID := "session123"
	
	// Create an expired message
	expiredMsg := &common.Message{
		ID:            "msg1",
		DestinationID: sessionID,
		Timestamp:     time.Now(),
		TTL:           time.Now().Add(-1 * time.Hour), // Already expired
	}

	// Store expired message
	if err := store.StoreMessage(expiredMsg); err != nil {
		t.Fatalf("Failed to store message: %v", err)
	}

	// Retrieve messages - expired ones should be filtered out
	messages, err := store.RetrieveMessages(sessionID)
	if err != nil {
		t.Fatalf("RetrieveMessages failed: %v", err)
	}

	if len(messages) != 0 {
		t.Errorf("Expected 0 messages (expired should be filtered), got %d", len(messages))
	}

	// Verify expired count increased
	stats := store.GetStats()
	if stats.MessagesExpired != 1 {
		t.Errorf("Expected 1 expired message, got %d", stats.MessagesExpired)
	}
}

func TestCleanupExpired(t *testing.T) {
	storage := NewMemoryStorage()
	peers := []string{"peer1:9000"}
	store := NewStore(storage, peers, 1, 14)

	// Create messages with different expiry times
	sessionID := "session123"
	
	validMsg := &common.Message{
		ID:            "msg1",
		DestinationID: sessionID,
		Timestamp:     time.Now(),
		TTL:           time.Now().Add(1 * time.Hour), // Valid for 1 hour
	}
	
	expiredMsg := &common.Message{
		ID:            "msg2",
		DestinationID: sessionID,
		Timestamp:     time.Now(),
		TTL:           time.Now().Add(-1 * time.Hour), // Already expired
	}

	// Store both messages
	if err := store.StoreMessage(validMsg); err != nil {
		t.Fatalf("Failed to store valid message: %v", err)
	}
	if err := store.StoreMessage(expiredMsg); err != nil {
		t.Fatalf("Failed to store expired message: %v", err)
	}

	// Run cleanup
	count, err := store.CleanupExpired()
	if err != nil {
		t.Fatalf("CleanupExpired failed: %v", err)
	}

	if count != 1 {
		t.Errorf("Expected 1 message cleaned up, got %d", count)
	}

	// Verify only valid message remains
	messages, err := store.RetrieveMessages(sessionID)
	if err != nil {
		t.Fatalf("RetrieveMessages failed: %v", err)
	}

	if len(messages) != 1 {
		t.Errorf("Expected 1 valid message remaining, got %d", len(messages))
	}

	if messages[0].ID != validMsg.ID {
		t.Errorf("Expected valid message %s, got %s", validMsg.ID, messages[0].ID)
	}
}

func TestMemoryStorage(t *testing.T) {
	storage := NewMemoryStorage()

	// Test Store
	key := "test-key"
	value := []byte("test-value")
	if err := storage.Store(key, value); err != nil {
		t.Fatalf("Store failed: %v", err)
	}

	// Test Retrieve
	retrieved, err := storage.Retrieve(key)
	if err != nil {
		t.Fatalf("Retrieve failed: %v", err)
	}

	if string(retrieved) != string(value) {
		t.Errorf("Expected %s, got %s", value, retrieved)
	}

	// Test List
	storage.Store("prefix/key1", []byte("value1"))
	storage.Store("prefix/key2", []byte("value2"))
	storage.Store("other/key3", []byte("value3"))

	keys, err := storage.List("prefix/")
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}

	if len(keys) != 2 {
		t.Errorf("Expected 2 keys with prefix, got %d", len(keys))
	}

	// Test Delete
	if err := storage.Delete(key); err != nil {
		t.Fatalf("Delete failed: %v", err)
	}

	_, err = storage.Retrieve(key)
	if err == nil {
		t.Error("Expected error when retrieving deleted key")
	}
}
