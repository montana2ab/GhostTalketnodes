package main

import (
	"crypto/ed25519"
	"crypto/tls"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/montana2ab/GhostTalketnodes/server/pkg/common"
	"github.com/montana2ab/GhostTalketnodes/server/pkg/directory"
	"github.com/montana2ab/GhostTalketnodes/server/pkg/onion"
	"github.com/montana2ab/GhostTalketnodes/server/pkg/swarm"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"gopkg.in/yaml.v3"
)

var (
	Version   = "1.0.0"
	BuildTime = "unknown"
)

type Server struct {
	config    *common.Config
	router    *onion.Router
	swarm     *swarm.Store
	directory *directory.Service
	httpServer *http.Server
}

func main() {
	configFile := flag.String("config", "config.yaml", "Configuration file path")
	version := flag.Bool("version", false, "Show version")
	flag.Parse()

	if *version {
		fmt.Printf("GhostNodes %s (built %s)\n", Version, BuildTime)
		return
	}

	// Load configuration
	config, err := loadConfig(*configFile)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Load private key
	privateKey, err := loadPrivateKey(config.PrivateKeyFile)
	if err != nil {
		log.Fatalf("Failed to load private key: %v", err)
	}

	// Initialize components
	onionRouter := onion.NewRouter(privateKey)
	
	storage := swarm.NewMemoryStorage() // Use RocksDB in production
	swarmStore := swarm.NewStore(
		storage,
		config.BootstrapNodes,
		config.Swarm.ReplicationFactor,
		config.Swarm.TTLDays,
	)
	
	directoryService := directory.NewService(privateKey)

	server := &Server{
		config:    config,
		router:    onionRouter,
		swarm:     swarmStore,
		directory: directoryService,
	}

	// Start HTTP server
	if err := server.Start(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}

	// Wait for shutdown signal
	server.WaitForShutdown()
}

func (s *Server) Start() error {
	// Create router
	r := mux.NewRouter()

	// API routes
	api := r.PathPrefix("/v1").Subrouter()
	
	// Onion routing
	api.HandleFunc("/onion", s.handleOnionPacket).Methods("POST")
	
	// Swarm store-and-forward
	api.HandleFunc("/swarm/messages/{sessionID}", s.handleRetrieveMessages).Methods("GET")
	api.HandleFunc("/swarm/messages", s.handleStoreMessage).Methods("POST")
	api.HandleFunc("/swarm/messages/{sessionID}/{messageID}", s.handleDeleteMessage).Methods("DELETE")
	
	// Directory service
	api.HandleFunc("/nodes/bootstrap", s.handleGetBootstrap).Methods("GET")
	api.HandleFunc("/nodes/swarm/{sessionID}", s.handleGetSwarmNodes).Methods("GET")
	api.HandleFunc("/nodes/register", s.handleRegisterNode).Methods("POST")
	
	// Health and metrics
	r.HandleFunc("/health", s.handleHealth).Methods("GET")
	r.HandleFunc("/metrics", promhttp.Handler().ServeHTTP).Methods("GET")

	// Configure TLS
	tlsConfig := &tls.Config{
		MinVersion: tls.VersionTLS13,
		CipherSuites: []uint16{
			tls.TLS_CHACHA20_POLY1305_SHA256,
			tls.TLS_AES_256_GCM_SHA384,
			tls.TLS_AES_128_GCM_SHA256,
		},
	}

	s.httpServer = &http.Server{
		Addr:         s.config.ListenAddress,
		Handler:      r,
		TLSConfig:    tlsConfig,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	log.Printf("Starting GhostNodes %s on %s", Version, s.config.ListenAddress)

	// Start server (TLS)
	go func() {
		var err error
		if s.config.TLS.CertFile != "" && s.config.TLS.KeyFile != "" {
			err = s.httpServer.ListenAndServeTLS(s.config.TLS.CertFile, s.config.TLS.KeyFile)
		} else {
			log.Println("WARNING: Running without TLS (use for testing only)")
			err = s.httpServer.ListenAndServe()
		}
		if err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	// Start cleanup goroutine
	go s.cleanupLoop()

	return nil
}

func (s *Server) WaitForShutdown() {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	
	<-sigChan
	log.Println("Shutting down...")
	
	// Graceful shutdown
	if err := s.httpServer.Close(); err != nil {
		log.Printf("Error closing server: %v", err)
	}
}

// Handler functions

func (s *Server) handleOnionPacket(w http.ResponseWriter, r *http.Request) {
	// Read packet
	packet, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Failed to read packet", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// Process packet
	decision, err := s.router.ProcessPacket(packet)
	if err != nil {
		log.Printf("Packet processing error: %v", err)
		http.Error(w, "Invalid packet", http.StatusBadRequest)
		return
	}

	// Apply delay (timing obfuscation)
	if decision.Delay > 0 {
		time.Sleep(decision.Delay)
	}

	switch decision.Action {
	case onion.ActionForward:
		// Forward to next hop
		// TODO: Implement actual forwarding
		log.Printf("Forwarding to %s", decision.NextAddress)
		w.WriteHeader(http.StatusAccepted)
		
	case onion.ActionDeliver:
		// Deliver to swarm
		var msg common.Message
		if err := json.Unmarshal(decision.Payload, &msg); err != nil {
			http.Error(w, "Invalid payload", http.StatusBadRequest)
			return
		}
		
		if err := s.swarm.StoreMessage(&msg); err != nil {
			http.Error(w, "Failed to store message", http.StatusInternalServerError)
			return
		}
		
		w.WriteHeader(http.StatusOK)
	}
}

func (s *Server) handleStoreMessage(w http.ResponseWriter, r *http.Request) {
	var msg common.Message
	if err := json.NewDecoder(r.Body).Decode(&msg); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	if err := s.swarm.StoreMessage(&msg); err != nil {
		http.Error(w, "Failed to store message", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"status": "stored"})
}

func (s *Server) handleRetrieveMessages(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	sessionID := vars["sessionID"]

	messages, err := s.swarm.RetrieveMessages(sessionID)
	if err != nil {
		http.Error(w, "Failed to retrieve messages", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(messages)
}

func (s *Server) handleDeleteMessage(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	sessionID := vars["sessionID"]
	messageID := vars["messageID"]

	if err := s.swarm.DeleteMessage(sessionID, messageID); err != nil {
		http.Error(w, "Failed to delete message", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleGetBootstrap(w http.ResponseWriter, r *http.Request) {
	bootstrap, err := s.directory.GetBootstrapSet()
	if err != nil {
		http.Error(w, "Failed to get bootstrap set", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(bootstrap)
}

func (s *Server) handleGetSwarmNodes(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	sessionID := vars["sessionID"]

	nodes, err := s.directory.GetSwarmNodes(sessionID, s.config.Swarm.ReplicationFactor)
	if err != nil {
		http.Error(w, "Failed to get swarm nodes", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"session_id": sessionID,
		"nodes":      nodes,
	})
}

func (s *Server) handleRegisterNode(w http.ResponseWriter, r *http.Request) {
	var node common.NodeInfo
	if err := json.NewDecoder(r.Body).Decode(&node); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	if err := s.directory.RegisterNode(&node); err != nil {
		http.Error(w, "Failed to register node", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"status": "registered"})
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "healthy",
		"version": Version,
		"uptime":  time.Since(time.Now()).Seconds(),
	})
}

func (s *Server) cleanupLoop() {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	for range ticker.C {
		count, err := s.swarm.CleanupExpired()
		if err != nil {
			log.Printf("Cleanup error: %v", err)
		} else {
			log.Printf("Cleaned up %d expired messages", count)
		}

		// Health check nodes
		s.directory.HealthCheck()
	}
}

func loadConfig(filename string) (*common.Config, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var config common.Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	return &config, nil
}

func loadPrivateKey(filename string) (ed25519.PrivateKey, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		// Generate new key if file doesn't exist
		_, priv, err := common.GenerateKeypair()
		if err != nil {
			return nil, err
		}
		
		// Save key
		if err := os.WriteFile(filename, priv, 0600); err != nil {
			log.Printf("Warning: Failed to save private key: %v", err)
		}
		
		return priv, nil
	}

	if len(data) != ed25519.PrivateKeySize {
		return nil, fmt.Errorf("invalid private key size: %d", len(data))
	}

	return ed25519.PrivateKey(data), nil
}
