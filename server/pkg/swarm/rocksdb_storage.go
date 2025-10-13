// +build rocksdb

package swarm

import (
	"errors"
	"strings"

	"github.com/tecbot/gorocksdb"
)

// RocksDBStorage implements Storage interface using RocksDB
type RocksDBStorage struct {
	db   *gorocksdb.DB
	opts *gorocksdb.Options
	ro   *gorocksdb.ReadOptions
	wo   *gorocksdb.WriteOptions
}

// NewRocksDBStorage creates a new RocksDB storage instance
func NewRocksDBStorage(path string) (*RocksDBStorage, error) {
	// Configure RocksDB options
	opts := gorocksdb.NewDefaultOptions()
	opts.SetCreateIfMissing(true)
	opts.SetCompression(gorocksdb.SnappyCompression)
	
	// Performance tuning
	opts.SetMaxBackgroundCompactions(4)
	opts.SetMaxOpenFiles(1000)
	
	// Write buffer
	opts.SetWriteBufferSize(64 * 1024 * 1024) // 64MB
	opts.SetMaxWriteBufferNumber(3)
	
	// Block cache
	bbto := gorocksdb.NewDefaultBlockBasedTableOptions()
	bbto.SetBlockCache(gorocksdb.NewLRUCache(256 * 1024 * 1024)) // 256MB
	bbto.SetFilterPolicy(gorocksdb.NewBloomFilter(10))
	opts.SetBlockBasedTableFactory(bbto)

	// Open database
	db, err := gorocksdb.OpenDb(opts, path)
	if err != nil {
		opts.Destroy()
		return nil, err
	}

	ro := gorocksdb.NewDefaultReadOptions()
	wo := gorocksdb.NewDefaultWriteOptions()
	wo.SetSync(false) // Async writes for better performance

	return &RocksDBStorage{
		db:   db,
		opts: opts,
		ro:   ro,
		wo:   wo,
	}, nil
}

// Store stores a key-value pair
func (r *RocksDBStorage) Store(key string, value []byte) error {
	if r.db == nil {
		return errors.New("database is closed")
	}
	
	return r.db.Put(r.wo, []byte(key), value)
}

// Retrieve retrieves a value by key
func (r *RocksDBStorage) Retrieve(key string) ([]byte, error) {
	if r.db == nil {
		return nil, errors.New("database is closed")
	}
	
	slice, err := r.db.Get(r.ro, []byte(key))
	if err != nil {
		return nil, err
	}
	defer slice.Free()
	
	if !slice.Exists() {
		return nil, errors.New("key not found")
	}
	
	// Copy data as slice will be freed
	data := make([]byte, slice.Size())
	copy(data, slice.Data())
	
	return data, nil
}

// Delete deletes a key
func (r *RocksDBStorage) Delete(key string) error {
	if r.db == nil {
		return errors.New("database is closed")
	}
	
	return r.db.Delete(r.wo, []byte(key))
}

// List lists all keys with a given prefix
func (r *RocksDBStorage) List(prefix string) ([]string, error) {
	if r.db == nil {
		return nil, errors.New("database is closed")
	}
	
	keys := make([]string, 0)
	
	it := r.db.NewIterator(r.ro)
	defer it.Close()
	
	prefixBytes := []byte(prefix)
	it.Seek(prefixBytes)
	
	for ; it.Valid(); it.Next() {
		keySlice := it.Key()
		key := string(keySlice.Data())
		keySlice.Free()
		
		// Check if key has the prefix
		if !strings.HasPrefix(key, prefix) {
			break
		}
		
		keys = append(keys, key)
	}
	
	if err := it.Err(); err != nil {
		return nil, err
	}
	
	return keys, nil
}

// Close closes the database
func (r *RocksDBStorage) Close() error {
	if r.db != nil {
		r.db.Close()
		r.db = nil
	}
	
	if r.ro != nil {
		r.ro.Destroy()
		r.ro = nil
	}
	
	if r.wo != nil {
		r.wo.Destroy()
		r.wo = nil
	}
	
	if r.opts != nil {
		r.opts.Destroy()
		r.opts = nil
	}
	
	return nil
}
