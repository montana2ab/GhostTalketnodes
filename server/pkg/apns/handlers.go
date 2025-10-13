package apns

import (
	"encoding/json"
	"log"
	"net/http"
)

// RegisterDeviceRequest represents the request body for device registration
type RegisterDeviceRequest struct {
	SessionID   string `json:"session_id"`
	DeviceToken string `json:"device_token"`
}

// UnregisterDeviceRequest represents the request body for device unregistration
type UnregisterDeviceRequest struct {
	SessionID string `json:"session_id"`
}

// NotificationRequest represents the request body for sending a notification
type NotificationRequest struct {
	SessionID string              `json:"session_id"`
	Payload   NotificationPayload `json:"payload"`
}

// RegisterDeviceHandler handles device registration requests
func (n *Notifier) RegisterDeviceHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	
	var req RegisterDeviceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	
	// Validate request
	if req.SessionID == "" || req.DeviceToken == "" {
		http.Error(w, "session_id and device_token are required", http.StatusBadRequest)
		return
	}
	
	// Register device
	if err := n.RegisterDevice(req.SessionID, req.DeviceToken); err != nil {
		log.Printf("[APNs] Failed to register device: %v", err)
		http.Error(w, "Failed to register device", http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Device registered successfully",
	})
}

// UnregisterDeviceHandler handles device unregistration requests
func (n *Notifier) UnregisterDeviceHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	
	var req UnregisterDeviceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	
	// Validate request
	if req.SessionID == "" {
		http.Error(w, "session_id is required", http.StatusBadRequest)
		return
	}
	
	// Unregister device
	if err := n.UnregisterDevice(req.SessionID); err != nil {
		log.Printf("[APNs] Failed to unregister device: %v", err)
		http.Error(w, "Failed to unregister device", http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Device unregistered successfully",
	})
}

// StatsHandler returns statistics about registered devices
func (n *Notifier) StatsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	
	stats := n.Stats()
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(stats)
}

// SendNotificationHandler handles manual notification sending (for testing)
func (n *Notifier) SendNotificationHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	
	var req NotificationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}
	
	// Validate request
	if req.SessionID == "" {
		http.Error(w, "session_id is required", http.StatusBadRequest)
		return
	}
	
	// Send notification
	if err := n.SendNotification(r.Context(), req.SessionID, req.Payload); err != nil {
		log.Printf("[APNs] Failed to send notification: %v", err)
		http.Error(w, "Failed to send notification: "+err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"message": "Notification sent successfully",
	})
}
