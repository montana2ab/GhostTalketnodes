// +build !rocksdb

package swarm

import (
	"errors"
)

// RocksDBStorage stub when RocksDB is not available
type RocksDBStorage struct{}

// NewRocksDBStorage returns an error when RocksDB is not compiled in
func NewRocksDBStorage(path string) (*RocksDBStorage, error) {
	return nil, errors.New("RocksDB support not compiled in. Rebuild with '-tags rocksdb' to enable RocksDB storage")
}

// Store stub
func (r *RocksDBStorage) Store(key string, value []byte) error {
	return errors.New("RocksDB not available")
}

// Retrieve stub
func (r *RocksDBStorage) Retrieve(key string) ([]byte, error) {
	return nil, errors.New("RocksDB not available")
}

// Delete stub
func (r *RocksDBStorage) Delete(key string) error {
	return errors.New("RocksDB not available")
}

// List stub
func (r *RocksDBStorage) List(prefix string) ([]string, error) {
	return nil, errors.New("RocksDB not available")
}

// Close stub
func (r *RocksDBStorage) Close() error {
	return nil
}
