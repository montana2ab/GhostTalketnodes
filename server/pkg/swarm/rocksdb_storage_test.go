// +build rocksdb

package swarm

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNewRocksDBStorage(t *testing.T) {
	// Create temp directory for test
	tmpDir, err := os.MkdirTemp("", "rocksdb-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	storage, err := NewRocksDBStorage(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("Failed to create RocksDB storage: %v", err)
	}
	defer storage.Close()

	if storage.db == nil {
		t.Error("Database is nil")
	}
}

func TestRocksDBStorage_Store(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "rocksdb-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	storage, err := NewRocksDBStorage(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("Failed to create storage: %v", err)
	}
	defer storage.Close()

	key := "test-key"
	value := []byte("test-value")

	err = storage.Store(key, value)
	if err != nil {
		t.Errorf("Store failed: %v", err)
	}
}

func TestRocksDBStorage_Retrieve(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "rocksdb-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	storage, err := NewRocksDBStorage(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("Failed to create storage: %v", err)
	}
	defer storage.Close()

	key := "test-key"
	value := []byte("test-value")

	// Store first
	err = storage.Store(key, value)
	if err != nil {
		t.Fatalf("Store failed: %v", err)
	}

	// Retrieve
	retrieved, err := storage.Retrieve(key)
	if err != nil {
		t.Errorf("Retrieve failed: %v", err)
	}

	if string(retrieved) != string(value) {
		t.Errorf("Retrieved value = %s, want %s", string(retrieved), string(value))
	}
}

func TestRocksDBStorage_RetrieveNotFound(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "rocksdb-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	storage, err := NewRocksDBStorage(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("Failed to create storage: %v", err)
	}
	defer storage.Close()

	_, err = storage.Retrieve("nonexistent-key")
	if err == nil {
		t.Error("Expected error for nonexistent key, got nil")
	}
}

func TestRocksDBStorage_Delete(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "rocksdb-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	storage, err := NewRocksDBStorage(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("Failed to create storage: %v", err)
	}
	defer storage.Close()

	key := "test-key"
	value := []byte("test-value")

	// Store first
	err = storage.Store(key, value)
	if err != nil {
		t.Fatalf("Store failed: %v", err)
	}

	// Delete
	err = storage.Delete(key)
	if err != nil {
		t.Errorf("Delete failed: %v", err)
	}

	// Verify deletion
	_, err = storage.Retrieve(key)
	if err == nil {
		t.Error("Expected error after deletion, got nil")
	}
}

func TestRocksDBStorage_List(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "rocksdb-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	storage, err := NewRocksDBStorage(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("Failed to create storage: %v", err)
	}
	defer storage.Close()

	// Store multiple keys with same prefix
	prefix := "messages/"
	testData := map[string][]byte{
		"messages/user1/msg1": []byte("data1"),
		"messages/user1/msg2": []byte("data2"),
		"messages/user2/msg1": []byte("data3"),
		"other/key":           []byte("data4"),
	}

	for key, value := range testData {
		err = storage.Store(key, value)
		if err != nil {
			t.Fatalf("Store failed for %s: %v", key, err)
		}
	}

	// List with prefix
	keys, err := storage.List(prefix)
	if err != nil {
		t.Errorf("List failed: %v", err)
	}

	if len(keys) != 3 {
		t.Errorf("List returned %d keys, want 3", len(keys))
	}

	// Verify all keys have the prefix
	for _, key := range keys {
		if len(key) < len(prefix) || key[:len(prefix)] != prefix {
			t.Errorf("Key %s doesn't have prefix %s", key, prefix)
		}
	}
}

func TestRocksDBStorage_ListEmpty(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "rocksdb-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	storage, err := NewRocksDBStorage(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("Failed to create storage: %v", err)
	}
	defer storage.Close()

	keys, err := storage.List("nonexistent/")
	if err != nil {
		t.Errorf("List failed: %v", err)
	}

	if len(keys) != 0 {
		t.Errorf("List returned %d keys, want 0", len(keys))
	}
}

func TestRocksDBStorage_Close(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "rocksdb-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	storage, err := NewRocksDBStorage(filepath.Join(tmpDir, "test.db"))
	if err != nil {
		t.Fatalf("Failed to create storage: %v", err)
	}

	err = storage.Close()
	if err != nil {
		t.Errorf("Close failed: %v", err)
	}

	// Operations after close should fail
	err = storage.Store("key", []byte("value"))
	if err == nil {
		t.Error("Expected error after close, got nil")
	}
}
