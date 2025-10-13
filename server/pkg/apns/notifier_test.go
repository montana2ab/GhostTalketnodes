package apns

import (
	"context"
	"testing"
	"time"
)

func TestNewNotifier_InvalidConfig(t *testing.T) {
	tests := []struct {
		name    string
		config  Config
		wantErr bool
	}{
		{
			name:    "empty config",
			config:  Config{},
			wantErr: true,
		},
		{
			name: "missing KeyID",
			config: Config{
				TeamID: "TEAM123",
			},
			wantErr: true,
		},
		{
			name: "missing TeamID",
			config: Config{
				KeyID: "KEY123",
			},
			wantErr: true,
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewNotifier(tt.config)
			if (err != nil) != tt.wantErr {
				t.Errorf("NewNotifier() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestRegisterDevice(t *testing.T) {
	// Create a mock notifier (without real APNs client)
	n := &Notifier{
		registrations: make(map[string]*DeviceRegistration),
		topic:        "com.ghosttalk.app",
	}
	
	sessionID := "05ABC123DEF456"
	deviceToken := "device-token-123"
	
	err := n.RegisterDevice(sessionID, deviceToken)
	if err != nil {
		t.Fatalf("RegisterDevice() error = %v", err)
	}
	
	// Verify registration
	reg, exists := n.GetRegistration(sessionID)
	if !exists {
		t.Fatal("Registration not found")
	}
	
	if reg.SessionID != sessionID {
		t.Errorf("SessionID = %v, want %v", reg.SessionID, sessionID)
	}
	
	if reg.DeviceToken != deviceToken {
		t.Errorf("DeviceToken = %v, want %v", reg.DeviceToken, deviceToken)
	}
}

func TestUnregisterDevice(t *testing.T) {
	n := &Notifier{
		registrations: make(map[string]*DeviceRegistration),
		topic:        "com.ghosttalk.app",
	}
	
	sessionID := "05ABC123DEF456"
	deviceToken := "device-token-123"
	
	// Register first
	n.RegisterDevice(sessionID, deviceToken)
	
	// Unregister
	err := n.UnregisterDevice(sessionID)
	if err != nil {
		t.Fatalf("UnregisterDevice() error = %v", err)
	}
	
	// Verify removal
	_, exists := n.GetRegistration(sessionID)
	if exists {
		t.Error("Registration should not exist after unregister")
	}
}

func TestSendNotification_NoRegistration(t *testing.T) {
	n := &Notifier{
		registrations: make(map[string]*DeviceRegistration),
		topic:        "com.ghosttalk.app",
	}
	
	ctx := context.Background()
	sessionID := "05ABC123DEF456"
	
	payload := NotificationPayload{
		SessionID: sessionID,
		MessageID: "msg-123",
		Timestamp: time.Now(),
		Encrypted: true,
	}
	
	err := n.SendNotification(ctx, sessionID, payload)
	if err == nil {
		t.Error("SendNotification() should fail for unregistered device")
	}
}

func TestStats(t *testing.T) {
	n := &Notifier{
		registrations: make(map[string]*DeviceRegistration),
		topic:        "com.ghosttalk.app",
		production:   false,
	}
	
	// Register some devices
	n.RegisterDevice("session1", "token1")
	n.RegisterDevice("session2", "token2")
	n.RegisterDevice("session3", "token3")
	
	stats := n.Stats()
	
	totalReg, ok := stats["total_registrations"].(int)
	if !ok || totalReg != 3 {
		t.Errorf("Stats total_registrations = %v, want 3", totalReg)
	}
	
	topic, ok := stats["topic"].(string)
	if !ok || topic != "com.ghosttalk.app" {
		t.Errorf("Stats topic = %v, want com.ghosttalk.app", topic)
	}
	
	production, ok := stats["production_mode"].(bool)
	if !ok || production != false {
		t.Errorf("Stats production_mode = %v, want false", production)
	}
}

func TestCleanup(t *testing.T) {
	n := &Notifier{
		registrations: make(map[string]*DeviceRegistration),
		topic:        "com.ghosttalk.app",
	}
	
	now := time.Now()
	
	// Add fresh registration
	n.registrations["session1"] = &DeviceRegistration{
		SessionID:   "session1",
		DeviceToken: "token1",
		LastSeen:    now,
	}
	
	// Add stale registration (31 days old)
	n.registrations["session2"] = &DeviceRegistration{
		SessionID:   "session2",
		DeviceToken: "token2",
		LastSeen:    now.Add(-31 * 24 * time.Hour),
	}
	
	// Add another stale registration
	n.registrations["session3"] = &DeviceRegistration{
		SessionID:   "session3",
		DeviceToken: "token3",
		LastSeen:    now.Add(-45 * 24 * time.Hour),
	}
	
	removed := n.Cleanup()
	
	if removed != 2 {
		t.Errorf("Cleanup() removed = %v, want 2", removed)
	}
	
	// Verify fresh registration still exists
	if _, exists := n.registrations["session1"]; !exists {
		t.Error("Fresh registration should not be removed")
	}
	
	// Verify stale registrations are removed
	if _, exists := n.registrations["session2"]; exists {
		t.Error("Stale registration should be removed")
	}
	
	if _, exists := n.registrations["session3"]; exists {
		t.Error("Stale registration should be removed")
	}
}

func TestGetRegistration(t *testing.T) {
	n := &Notifier{
		registrations: make(map[string]*DeviceRegistration),
		topic:        "com.ghosttalk.app",
	}
	
	sessionID := "05ABC123DEF456"
	
	// Test non-existent registration
	_, exists := n.GetRegistration(sessionID)
	if exists {
		t.Error("GetRegistration() should return false for non-existent registration")
	}
	
	// Register device
	n.RegisterDevice(sessionID, "token-123")
	
	// Test existing registration
	reg, exists := n.GetRegistration(sessionID)
	if !exists {
		t.Error("GetRegistration() should return true for existing registration")
	}
	
	if reg.SessionID != sessionID {
		t.Errorf("GetRegistration() SessionID = %v, want %v", reg.SessionID, sessionID)
	}
}

func TestNotificationPayload(t *testing.T) {
	payload := NotificationPayload{
		SessionID:     "05ABC123",
		MessageID:     "msg-123",
		Timestamp:     time.Now(),
		Encrypted:     true,
		HasAttachment: false,
	}
	
	if payload.SessionID != "05ABC123" {
		t.Errorf("SessionID = %v, want 05ABC123", payload.SessionID)
	}
	
	if payload.MessageID != "msg-123" {
		t.Errorf("MessageID = %v, want msg-123", payload.MessageID)
	}
	
	if !payload.Encrypted {
		t.Error("Encrypted should be true")
	}
	
	if payload.HasAttachment {
		t.Error("HasAttachment should be false")
	}
}
