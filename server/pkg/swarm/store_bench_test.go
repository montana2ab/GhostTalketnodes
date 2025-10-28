package swarm

import (
	"fmt"
	"testing"
	"time"

	"github.com/montana2ab/GhostTalketnodes/server/pkg/common"
)

// Benchmark swarm storage operations

func BenchmarkNewStore(b *testing.B) {
	storage := NewMemoryStorage()
	bootstrapNodes := []string{"node1", "node2", "node3"}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = NewStore(storage, bootstrapNodes, 2, 7)
	}
}

func BenchmarkStoreMessage(b *testing.B) {
	storage := NewMemoryStorage()
	store := NewStore(storage, []string{}, 2, 7)

	msg := &common.Message{
		ID:            "test_msg",
		DestinationID: "session_123",
		Timestamp:     time.Now(),
		MessageType:   1,
		EncryptedContent: []byte("test payload"),
		TTL:           time.Now().Add(7 * 24 * time.Hour),
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if err := store.StoreMessage(msg); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkRetrieveMessages(b *testing.B) {
	storage := NewMemoryStorage()
	store := NewStore(storage, []string{}, 2, 7)

	// Pre-populate with messages
	sessionID := "session_123"
	for i := 0; i < 100; i++ {
		msg := &common.Message{
			ID:            fmt.Sprintf("msg_%d", i),
			DestinationID: sessionID,
			Timestamp:     time.Now(),
			MessageType:   1,
			EncryptedContent: []byte(fmt.Sprintf("payload %d", i)),
			TTL:           time.Now().Add(7 * 24 * time.Hour),
		}
		store.StoreMessage(msg)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := store.RetrieveMessages(sessionID)
		if err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkDeleteMessage(b *testing.B) {
	storage := NewMemoryStorage()
	store := NewStore(storage, []string{}, 2, 7)

	sessionID := "session_123"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		// Store a message
		msgID := fmt.Sprintf("msg_%d", i)
		msg := &common.Message{
			ID:            msgID,
			DestinationID: sessionID,
			Timestamp:     time.Now(),
			MessageType:   1,
			EncryptedContent: []byte("test"),
			TTL:           time.Now().Add(7 * 24 * time.Hour),
		}
		store.StoreMessage(msg)

		// Delete it
		if err := store.DeleteMessage(sessionID, msgID); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkConsistentHashing(b *testing.B) {
	storage := NewMemoryStorage()
	store := NewStore(storage, []string{"node1", "node2", "node3"}, 2, 7)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		// Test message storage which uses consistent hashing internally
		msg := &common.Message{
			ID:            fmt.Sprintf("msg_%d", i),
			DestinationID: fmt.Sprintf("session_%d", i%1000),
			Timestamp:     time.Now(),
			MessageType:   1,
			EncryptedContent: []byte("test"),
			TTL:           time.Now().Add(7 * 24 * time.Hour),
		}
		store.StoreMessage(msg)
	}
}

func BenchmarkCleanupExpired(b *testing.B) {
	storage := NewMemoryStorage()
	store := NewStore(storage, []string{}, 2, 7)

	// Pre-populate with expired and non-expired messages
	sessionID := "session_123"
	expiredTime := time.Now().Add(-8 * 24 * time.Hour) // 8 days ago
	for i := 0; i < 50; i++ {
		msg := &common.Message{
			ID:            fmt.Sprintf("expired_%d", i),
			DestinationID: sessionID,
			Timestamp:     expiredTime,
			MessageType:   1,
			EncryptedContent: []byte("expired"),
			TTL:           expiredTime,
		}
		store.StoreMessage(msg)
	}
	for i := 0; i < 50; i++ {
		msg := &common.Message{
			ID:            fmt.Sprintf("valid_%d", i),
			DestinationID: sessionID,
			Timestamp:     time.Now(),
			MessageType:   1,
			EncryptedContent: []byte("valid"),
			TTL:           time.Now().Add(7 * 24 * time.Hour),
		}
		store.StoreMessage(msg)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := store.CleanupExpired()
		if err != nil {
			b.Fatal(err)
		}
	}
}

// Benchmark with different numbers of messages
func BenchmarkRetrieveMessages_10(b *testing.B) {
	benchmarkRetrieveWithCount(b, 10)
}

func BenchmarkRetrieveMessages_100(b *testing.B) {
	benchmarkRetrieveWithCount(b, 100)
}

func BenchmarkRetrieveMessages_1000(b *testing.B) {
	benchmarkRetrieveWithCount(b, 1000)
}

func benchmarkRetrieveWithCount(b *testing.B, count int) {
	storage := NewMemoryStorage()
	store := NewStore(storage, []string{}, 2, 7)

	sessionID := "session_123"
	for i := 0; i < count; i++ {
		msg := &common.Message{
			ID:            fmt.Sprintf("msg_%d", i),
			DestinationID: sessionID,
			Timestamp:     time.Now(),
			MessageType:   1,
			EncryptedContent: []byte(fmt.Sprintf("payload %d", i)),
			TTL:           time.Now().Add(7 * 24 * time.Hour),
		}
		store.StoreMessage(msg)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := store.RetrieveMessages(sessionID)
		if err != nil {
			b.Fatal(err)
		}
	}
}

// Benchmark concurrent operations
func BenchmarkStoreMessage_Concurrent(b *testing.B) {
	storage := NewMemoryStorage()
	store := NewStore(storage, []string{}, 2, 7)

	b.RunParallel(func(pb *testing.PB) {
		i := 0
		for pb.Next() {
			msg := &common.Message{
				ID:            fmt.Sprintf("msg_%d", i),
				DestinationID: fmt.Sprintf("session_%d", i%10),
				Timestamp:     time.Now(),
				MessageType:   1,
				EncryptedContent: []byte(fmt.Sprintf("payload %d", i)),
				TTL:           time.Now().Add(7 * 24 * time.Hour),
			}
			if err := store.StoreMessage(msg); err != nil {
				b.Fatal(err)
			}
			i++
		}
	})
}

func BenchmarkRetrieveMessages_Concurrent(b *testing.B) {
	storage := NewMemoryStorage()
	store := NewStore(storage, []string{}, 2, 7)

	// Pre-populate
	for i := 0; i < 10; i++ {
		sessionID := fmt.Sprintf("session_%d", i)
		for j := 0; j < 50; j++ {
			msg := &common.Message{
				ID:            fmt.Sprintf("msg_%d_%d", i, j),
				DestinationID: sessionID,
				Timestamp:     time.Now(),
				MessageType:   1,
				EncryptedContent: []byte("test"),
				TTL:           time.Now().Add(7 * 24 * time.Hour),
			}
			store.StoreMessage(msg)
		}
	}

	b.RunParallel(func(pb *testing.PB) {
		i := 0
		for pb.Next() {
			sessionID := fmt.Sprintf("session_%d", i%10)
			_, err := store.RetrieveMessages(sessionID)
			if err != nil {
				b.Fatal(err)
			}
			i++
		}
	})
}

// Benchmark memory storage indirectly through Store
func BenchmarkMemoryStorage_Save(b *testing.B) {
	storage := NewMemoryStorage()
	store := NewStore(storage, []string{}, 2, 7)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		msg := &common.Message{
			ID:            fmt.Sprintf("msg_%d", i),
			DestinationID: "session_123",
			Timestamp:     time.Now(),
			MessageType:   1,
			EncryptedContent: []byte("test"),
			TTL:           time.Now().Add(7 * 24 * time.Hour),
		}
		if err := store.StoreMessage(msg); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkMemoryStorage_Get(b *testing.B) {
	storage := NewMemoryStorage()
	store := NewStore(storage, []string{}, 2, 7)
	sessionID := "session_123"

	// Pre-populate
	for i := 0; i < 100; i++ {
		msg := &common.Message{
			ID:            fmt.Sprintf("msg_%d", i),
			DestinationID: sessionID,
			Timestamp:     time.Now(),
			MessageType:   1,
			EncryptedContent: []byte("test"),
			TTL:           time.Now().Add(7 * 24 * time.Hour),
		}
		store.StoreMessage(msg)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, err := store.RetrieveMessages(sessionID)
		if err != nil {
			b.Fatal(err)
		}
	}
}

