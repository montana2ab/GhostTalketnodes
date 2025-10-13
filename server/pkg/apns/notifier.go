package apns

import (
	"context"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/sideshow/apns2"
	"github.com/sideshow/apns2/token"
)

// NotificationPayload represents the data sent in a push notification
type NotificationPayload struct {
	SessionID   string    `json:"session_id"`
	MessageID   string    `json:"message_id"`
	Timestamp   time.Time `json:"timestamp"`
	Encrypted   bool      `json:"encrypted"`
	HasAttachment bool    `json:"has_attachment"`
}

// DeviceRegistration represents an iOS device registered for push notifications
type DeviceRegistration struct {
	SessionID   string
	DeviceToken string
	RegisteredAt time.Time
	LastSeen    time.Time
}

// Notifier sends push notifications to iOS devices via APNs
type Notifier struct {
	client       *apns2.Client
	topic        string // Bundle ID
	registrations map[string]*DeviceRegistration // sessionID -> registration
	mu           sync.RWMutex
	production   bool
}

// Config contains APNs configuration
type Config struct {
	// Authentication: Either Token-based or Certificate-based
	
	// Token-based authentication (recommended)
	KeyID      string // APNs Key ID
	TeamID     string // Apple Developer Team ID
	P8KeyPath  string // Path to .p8 private key file
	P8KeyData  []byte // Or provide key data directly
	
	// Certificate-based authentication (legacy)
	CertPath   string // Path to .p12 or .pem certificate
	CertData   []byte // Or provide certificate data directly
	CertPassword string // Certificate password
	
	// Common
	Topic      string // App bundle ID (e.g., com.ghosttalk.app)
	Production bool   // Use production APNs server
}

// NewNotifier creates a new APNs notifier
func NewNotifier(config Config) (*Notifier, error) {
	var client *apns2.Client
	
	// Token-based authentication (preferred)
	if config.KeyID != "" && config.TeamID != "" {
		var keyData []byte
		var err error
		
		if len(config.P8KeyData) > 0 {
			keyData = config.P8KeyData
		} else if config.P8KeyPath != "" {
			// In production, read from file
			return nil, fmt.Errorf("P8KeyPath file reading not implemented in this example")
		} else {
			return nil, errors.New("either P8KeyData or P8KeyPath must be provided")
		}
		
		// Parse the P8 key
		block, _ := pem.Decode(keyData)
		if block == nil {
			return nil, errors.New("failed to decode P8 key")
		}
		
		key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
		if err != nil {
			return nil, fmt.Errorf("failed to parse P8 key: %w", err)
		}
		
		ecdsaKey, ok := key.(*ecdsa.PrivateKey)
		if !ok {
			return nil, errors.New("key is not ECDSA")
		}
		
		authKey := &token.Token{
			AuthKey: ecdsaKey,
			KeyID:   config.KeyID,
			TeamID:  config.TeamID,
		}
		
		if config.Production {
			client = apns2.NewTokenClient(authKey).Production()
		} else {
			client = apns2.NewTokenClient(authKey).Development()
		}
		
	} else if len(config.CertData) > 0 || config.CertPath != "" {
		// Certificate-based authentication
		return nil, errors.New("certificate-based authentication not implemented in this example")
	} else {
		return nil, errors.New("no authentication method provided")
	}
	
	return &Notifier{
		client:       client,
		topic:        config.Topic,
		registrations: make(map[string]*DeviceRegistration),
		production:   config.Production,
	}, nil
}

// RegisterDevice registers a device token for push notifications
func (n *Notifier) RegisterDevice(sessionID, deviceToken string) error {
	n.mu.Lock()
	defer n.mu.Unlock()
	
	now := time.Now()
	n.registrations[sessionID] = &DeviceRegistration{
		SessionID:   sessionID,
		DeviceToken: deviceToken,
		RegisteredAt: now,
		LastSeen:    now,
	}
	
	log.Printf("[APNs] Registered device for session %s", sessionID[:8])
	return nil
}

// UnregisterDevice removes a device registration
func (n *Notifier) UnregisterDevice(sessionID string) error {
	n.mu.Lock()
	defer n.mu.Unlock()
	
	delete(n.registrations, sessionID)
	log.Printf("[APNs] Unregistered device for session %s", sessionID[:8])
	return nil
}

// GetRegistration returns the device registration for a session ID
func (n *Notifier) GetRegistration(sessionID string) (*DeviceRegistration, bool) {
	n.mu.RLock()
	defer n.mu.RUnlock()
	
	reg, exists := n.registrations[sessionID]
	return reg, exists
}

// SendNotification sends a push notification to a specific session ID
func (n *Notifier) SendNotification(ctx context.Context, sessionID string, payload NotificationPayload) error {
	// Get device registration
	reg, exists := n.GetRegistration(sessionID)
	if !exists {
		return fmt.Errorf("no device registered for session %s", sessionID[:8])
	}
	
	// Create notification
	notification := &apns2.Notification{
		DeviceToken: reg.DeviceToken,
		Topic:       n.topic,
		Payload: map[string]interface{}{
			"aps": map[string]interface{}{
				"alert": map[string]interface{}{
					"title": "New Message",
					"body":  "You have a new message", // Generic for privacy
				},
				"badge":            1,
				"sound":            "default",
				"mutable-content":  1, // Allow notification service extension
				"content-available": 1, // Silent notification support
			},
			"session_id":    payload.SessionID,
			"message_id":    payload.MessageID,
			"timestamp":     payload.Timestamp.Unix(),
			"encrypted":     payload.Encrypted,
			"has_attachment": payload.HasAttachment,
		},
		Priority:   apns2.PriorityHigh,
		Expiration: time.Now().Add(24 * time.Hour),
	}
	
	// Send notification
	response, err := n.client.PushWithContext(ctx, notification)
	if err != nil {
		return fmt.Errorf("failed to send notification: %w", err)
	}
	
	// Check response
	if response.StatusCode != 200 {
		// Handle specific error codes
		if response.Reason == apns2.ReasonBadDeviceToken || 
		   response.Reason == apns2.ReasonUnregistered {
			// Device token is invalid, remove registration
			n.UnregisterDevice(sessionID)
			log.Printf("[APNs] Removed invalid device token for session %s: %s", 
				sessionID[:8], response.Reason)
		}
		return fmt.Errorf("APNs error: %s (status %d)", response.Reason, response.StatusCode)
	}
	
	log.Printf("[APNs] Sent notification to session %s (ID: %s)", 
		sessionID[:8], response.ApnsID)
	
	// Update last seen
	n.mu.Lock()
	if reg, exists := n.registrations[sessionID]; exists {
		reg.LastSeen = time.Now()
	}
	n.mu.Unlock()
	
	return nil
}

// SendBatchNotifications sends notifications to multiple session IDs
func (n *Notifier) SendBatchNotifications(ctx context.Context, notifications []struct {
	SessionID string
	Payload   NotificationPayload
}) error {
	var wg sync.WaitGroup
	errors := make(chan error, len(notifications))
	
	for _, notif := range notifications {
		wg.Add(1)
		go func(sid string, payload NotificationPayload) {
			defer wg.Done()
			if err := n.SendNotification(ctx, sid, payload); err != nil {
				errors <- fmt.Errorf("session %s: %w", sid[:8], err)
			}
		}(notif.SessionID, notif.Payload)
	}
	
	wg.Wait()
	close(errors)
	
	// Collect errors
	var errs []error
	for err := range errors {
		errs = append(errs, err)
	}
	
	if len(errs) > 0 {
		return fmt.Errorf("batch notification errors: %d/%d failed", len(errs), len(notifications))
	}
	
	return nil
}

// Stats returns statistics about registered devices
func (n *Notifier) Stats() map[string]interface{} {
	n.mu.RLock()
	defer n.mu.RUnlock()
	
	return map[string]interface{}{
		"total_registrations": len(n.registrations),
		"production_mode":     n.production,
		"topic":              n.topic,
	}
}

// Cleanup removes stale device registrations (not seen in 30 days)
func (n *Notifier) Cleanup() int {
	n.mu.Lock()
	defer n.mu.Unlock()
	
	threshold := time.Now().Add(-30 * 24 * time.Hour)
	removed := 0
	
	for sessionID, reg := range n.registrations {
		if reg.LastSeen.Before(threshold) {
			delete(n.registrations, sessionID)
			removed++
		}
	}
	
	if removed > 0 {
		log.Printf("[APNs] Cleaned up %d stale device registrations", removed)
	}
	
	return removed
}

// Close closes the APNs client
func (n *Notifier) Close() error {
	// APNs client doesn't need explicit closing
	log.Println("[APNs] Notifier closed")
	return nil
}
