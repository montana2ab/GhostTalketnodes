package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestNewRateLimiter(t *testing.T) {
	rl := NewRateLimiter(10, 20)
	
	if rl.rps != 10 {
		t.Errorf("RPS = %d, want 10", rl.rps)
	}
	
	if rl.burst != 20 {
		t.Errorf("Burst = %d, want 20", rl.burst)
	}
	
	if rl.limiters == nil {
		t.Error("Limiters map is nil")
	}
}

func TestRateLimiter_GetLimiter(t *testing.T) {
	rl := NewRateLimiter(10, 20)
	
	ip := "192.168.1.1"
	
	// First call should create a new limiter
	limiter1 := rl.getLimiter(ip)
	if limiter1 == nil {
		t.Fatal("Limiter is nil")
	}
	
	// Second call should return the same limiter
	limiter2 := rl.getLimiter(ip)
	if limiter1 != limiter2 {
		t.Error("Different limiters returned for same IP")
	}
	
	// Different IP should get different limiter
	limiter3 := rl.getLimiter("192.168.1.2")
	if limiter1 == limiter3 {
		t.Error("Same limiter returned for different IP")
	}
}

func TestRateLimiter_Cleanup(t *testing.T) {
	rl := NewRateLimiter(10, 20)
	
	// Add some limiters
	rl.getLimiter("192.168.1.1")
	rl.getLimiter("192.168.1.2")
	
	if len(rl.limiters) != 2 {
		t.Errorf("Expected 2 limiters, got %d", len(rl.limiters))
	}
	
	// Cleanup
	rl.Cleanup()
	
	if len(rl.limiters) != 0 {
		t.Errorf("Expected 0 limiters after cleanup, got %d", len(rl.limiters))
	}
}

func TestRateLimiter_Middleware(t *testing.T) {
	// Create rate limiter with 2 requests per second
	rl := NewRateLimiter(2, 2)
	
	// Create test handler
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("success"))
	})
	
	// Wrap with rate limiter
	rateLimitedHandler := rl.Middleware(handler)
	
	// First 2 requests should succeed (burst)
	for i := 0; i < 2; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		req.RemoteAddr = "192.168.1.1:1234"
		
		rr := httptest.NewRecorder()
		rateLimitedHandler.ServeHTTP(rr, req)
		
		if rr.Code != http.StatusOK {
			t.Errorf("Request %d: expected status 200, got %d", i+1, rr.Code)
		}
	}
	
	// Third request should be rate limited
	req := httptest.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.1:1234"
	
	rr := httptest.NewRecorder()
	rateLimitedHandler.ServeHTTP(rr, req)
	
	if rr.Code != http.StatusTooManyRequests {
		t.Errorf("Expected status 429, got %d", rr.Code)
	}
}

func TestRateLimiter_MiddlewareDifferentIPs(t *testing.T) {
	// Create rate limiter with 1 request per second
	rl := NewRateLimiter(1, 1)
	
	// Create test handler
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	
	rateLimitedHandler := rl.Middleware(handler)
	
	// Request from IP 1 should succeed
	req1 := httptest.NewRequest("GET", "/test", nil)
	req1.RemoteAddr = "192.168.1.1:1234"
	rr1 := httptest.NewRecorder()
	rateLimitedHandler.ServeHTTP(rr1, req1)
	
	if rr1.Code != http.StatusOK {
		t.Errorf("Request from IP1: expected status 200, got %d", rr1.Code)
	}
	
	// Request from IP 2 should also succeed (different IP)
	req2 := httptest.NewRequest("GET", "/test", nil)
	req2.RemoteAddr = "192.168.1.2:1234"
	rr2 := httptest.NewRecorder()
	rateLimitedHandler.ServeHTTP(rr2, req2)
	
	if rr2.Code != http.StatusOK {
		t.Errorf("Request from IP2: expected status 200, got %d", rr2.Code)
	}
	
	// Second request from IP 1 should be rate limited
	req3 := httptest.NewRequest("GET", "/test", nil)
	req3.RemoteAddr = "192.168.1.1:1234"
	rr3 := httptest.NewRecorder()
	rateLimitedHandler.ServeHTTP(rr3, req3)
	
	if rr3.Code != http.StatusTooManyRequests {
		t.Errorf("Second request from IP1: expected status 429, got %d", rr3.Code)
	}
}

func TestRateLimiter_MiddlewareWithRefill(t *testing.T) {
	// Create rate limiter with 10 requests per second
	rl := NewRateLimiter(10, 1)
	
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	
	rateLimitedHandler := rl.Middleware(handler)
	
	// First request should succeed
	req1 := httptest.NewRequest("GET", "/test", nil)
	req1.RemoteAddr = "192.168.1.1:1234"
	rr1 := httptest.NewRecorder()
	rateLimitedHandler.ServeHTTP(rr1, req1)
	
	if rr1.Code != http.StatusOK {
		t.Errorf("First request: expected status 200, got %d", rr1.Code)
	}
	
	// Second request should be rate limited (burst = 1)
	req2 := httptest.NewRequest("GET", "/test", nil)
	req2.RemoteAddr = "192.168.1.1:1234"
	rr2 := httptest.NewRecorder()
	rateLimitedHandler.ServeHTTP(rr2, req2)
	
	if rr2.Code != http.StatusTooManyRequests {
		t.Errorf("Second request: expected status 429, got %d", rr2.Code)
	}
	
	// Wait for bucket to refill (slightly more than 100ms at 10 req/s)
	time.Sleep(150 * time.Millisecond)
	
	// Third request should succeed after refill
	req3 := httptest.NewRequest("GET", "/test", nil)
	req3.RemoteAddr = "192.168.1.1:1234"
	rr3 := httptest.NewRecorder()
	rateLimitedHandler.ServeHTTP(rr3, req3)
	
	if rr3.Code != http.StatusOK {
		t.Errorf("Third request after refill: expected status 200, got %d", rr3.Code)
	}
}

func TestGetClientIP(t *testing.T) {
	tests := []struct {
		name           string
		remoteAddr     string
		xForwardedFor  string
		xRealIP        string
		expectedIP     string
	}{
		{
			name:       "From RemoteAddr",
			remoteAddr: "192.168.1.1:1234",
			expectedIP: "192.168.1.1:1234",
		},
		{
			name:          "From X-Real-IP",
			remoteAddr:    "192.168.1.1:1234",
			xRealIP:       "10.0.0.1",
			expectedIP:    "10.0.0.1",
		},
		{
			name:          "From X-Forwarded-For",
			remoteAddr:    "192.168.1.1:1234",
			xForwardedFor: "10.0.0.1",
			expectedIP:    "10.0.0.1",
		},
		{
			name:          "X-Forwarded-For takes precedence",
			remoteAddr:    "192.168.1.1:1234",
			xForwardedFor: "10.0.0.1",
			xRealIP:       "10.0.0.2",
			expectedIP:    "10.0.0.1",
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", "/test", nil)
			req.RemoteAddr = tt.remoteAddr
			
			if tt.xForwardedFor != "" {
				req.Header.Set("X-Forwarded-For", tt.xForwardedFor)
			}
			
			if tt.xRealIP != "" {
				req.Header.Set("X-Real-IP", tt.xRealIP)
			}
			
			ip := getClientIP(req)
			if ip != tt.expectedIP {
				t.Errorf("getClientIP() = %s, want %s", ip, tt.expectedIP)
			}
		})
	}
}
