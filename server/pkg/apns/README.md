# APNs Notifier

## Overview

The APNs (Apple Push Notification service) Notifier is a component of the GhostTalk server that sends push notifications to iOS clients when they receive messages.

## Features

- **Token-based authentication**: Uses modern .p8 key authentication (recommended by Apple)
- **Device registration management**: Tracks device tokens per Session ID
- **Batch notifications**: Send notifications to multiple devices efficiently
- **Automatic cleanup**: Removes stale device registrations
- **Error handling**: Handles invalid device tokens gracefully
- **Production/Development modes**: Supports both APNs environments

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────┐
│  iOS Client │────────▶│ GhostTalk    │────────▶│  APNs   │
│             │ Register │   Server     │ Push    │ Service │
│             │          │  (Notifier)  │ Notif   │         │
└─────────────┘          └──────────────┘         └─────────┘
                                │
                                ▼
                         ┌─────────────┐
                         │ Registrations│
                         │  (In-Memory) │
                         └─────────────┘
```

## Configuration

### Token-based Authentication (Recommended)

1. Create an APNs Key in Apple Developer Portal
2. Download the .p8 key file
3. Note the Key ID and Team ID

```go
config := apns.Config{
    KeyID:      "ABC123DEF4",
    TeamID:     "TEAM123456",
    P8KeyData:  keyData,  // []byte from .p8 file
    Topic:      "com.ghosttalk.app",
    Production: false,  // Use false for development
}

notifier, err := apns.NewNotifier(config)
```

### Certificate-based Authentication (Legacy)

Not implemented in this version. Token-based authentication is recommended.

## Usage

### Initialize Notifier

```go
import "github.com/montana2ab/GhostTalketnodes/server/pkg/apns"

notifier, err := apns.NewNotifier(config)
if err != nil {
    log.Fatal(err)
}
defer notifier.Close()
```

### Register Device

When an iOS client starts, it sends its device token:

```go
err := notifier.RegisterDevice(sessionID, deviceToken)
```

HTTP API:
```bash
POST /apns/register
Content-Type: application/json

{
  "session_id": "05ABC123...",
  "device_token": "device-token-from-ios"
}
```

### Send Notification

When a message arrives for a user:

```go
payload := apns.NotificationPayload{
    SessionID:     recipientSessionID,
    MessageID:     messageID,
    Timestamp:     time.Now(),
    Encrypted:     true,
    HasAttachment: false,
}

err := notifier.SendNotification(ctx, recipientSessionID, payload)
```

### Send Batch Notifications

For multiple recipients:

```go
notifications := []struct {
    SessionID string
    Payload   apns.NotificationPayload
}{
    {SessionID: "session1", Payload: payload1},
    {SessionID: "session2", Payload: payload2},
}

err := notifier.SendBatchNotifications(ctx, notifications)
```

### Cleanup Stale Registrations

Run periodically (e.g., daily):

```go
removed := notifier.Cleanup()
log.Printf("Cleaned up %d stale registrations", removed)
```

### Get Statistics

```go
stats := notifier.Stats()
// Returns: {
//   "total_registrations": 1234,
//   "production_mode": true,
//   "topic": "com.ghosttalk.app"
// }
```

## HTTP API Endpoints

### POST /apns/register

Register a device for push notifications.

**Request:**
```json
{
  "session_id": "05ABC123DEF456...",
  "device_token": "device-token-from-apns"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Device registered successfully"
}
```

### POST /apns/unregister

Unregister a device from push notifications.

**Request:**
```json
{
  "session_id": "05ABC123DEF456..."
}
```

**Response:**
```json
{
  "success": true,
  "message": "Device unregistered successfully"
}
```

### GET /apns/stats

Get notifier statistics.

**Response:**
```json
{
  "total_registrations": 1234,
  "production_mode": true,
  "topic": "com.ghosttalk.app"
}
```

### POST /apns/send (Testing Only)

Manually send a notification (for testing).

**Request:**
```json
{
  "session_id": "05ABC123DEF456...",
  "payload": {
    "session_id": "05ABC123DEF456...",
    "message_id": "msg-123",
    "timestamp": "2025-10-13T10:30:00Z",
    "encrypted": true,
    "has_attachment": false
  }
}
```

## Notification Payload

Notifications sent to iOS devices include:

**APNs Payload:**
```json
{
  "aps": {
    "alert": {
      "title": "New Message",
      "body": "You have a new message"
    },
    "badge": 1,
    "sound": "default",
    "mutable-content": 1,
    "content-available": 1
  },
  "session_id": "05ABC123...",
  "message_id": "msg-123",
  "timestamp": 1697192400,
  "encrypted": true,
  "has_attachment": false
}
```

**Privacy Considerations:**
- Alert text is generic ("New Message")
- Actual message content is NOT included
- Client decrypts and displays the message after fetching it

## Error Handling

### Invalid Device Token

When APNs returns `BadDeviceToken` or `Unregistered`, the notifier automatically:
1. Removes the invalid registration
2. Logs the removal
3. Returns an error to the caller

### Network Errors

Network failures are returned as errors. Implement retry logic in your application:

```go
for retries := 0; retries < 3; retries++ {
    err := notifier.SendNotification(ctx, sessionID, payload)
    if err == nil {
        break
    }
    time.Sleep(time.Second * time.Duration(retries+1))
}
```

## Integration with Swarm Store

When the Swarm Store receives a message:

```go
func (s *Store) StoreMessage(msg Message) error {
    // Store message
    err := s.storage.Save(msg)
    if err != nil {
        return err
    }
    
    // Send push notification
    if s.notifier != nil {
        payload := apns.NotificationPayload{
            SessionID:   msg.RecipientSessionID,
            MessageID:   msg.ID,
            Timestamp:   msg.Timestamp,
            Encrypted:   true,
        }
        
        go s.notifier.SendNotification(context.Background(), 
            msg.RecipientSessionID, payload)
    }
    
    return nil
}
```

## Testing

### Unit Tests

Run tests:
```bash
cd server/pkg/apns
go test -v
```

Tests cover:
- Device registration/unregistration
- Statistics
- Cleanup of stale registrations
- Error handling

### Integration Testing

Use APNs development environment:
```go
config := apns.Config{
    KeyID:      "YOUR_KEY_ID",
    TeamID:     "YOUR_TEAM_ID",
    P8KeyData:  keyData,
    Topic:      "com.ghosttalk.app",
    Production: false,  // Development mode
}
```

Test with TestFlight builds or development builds on a real device.

## Production Deployment

### Setup Checklist

- [ ] Generate APNs Key in Apple Developer Portal
- [ ] Download .p8 key file
- [ ] Store key securely (environment variable or secrets manager)
- [ ] Set Production: true in config
- [ ] Test with production builds
- [ ] Monitor APNs response codes
- [ ] Set up cleanup cron job (daily)

### Environment Variables

```bash
export APNS_KEY_ID="ABC123DEF4"
export APNS_TEAM_ID="TEAM123456"
export APNS_KEY_PATH="/path/to/key.p8"
export APNS_TOPIC="com.ghosttalk.app"
export APNS_PRODUCTION="true"
```

### Security Considerations

1. **Protect APNs Key**: The .p8 key is sensitive. Store it securely.
2. **Rate Limiting**: Implement rate limits on registration endpoints
3. **Validation**: Validate Session IDs and device tokens
4. **Audit Logging**: Log all registration and notification events
5. **Token Rotation**: Rotate APNs keys periodically (Apple recommends annually)

## Monitoring

### Metrics to Track

- Total registrations
- Notifications sent per hour
- Failed notifications
- Invalid device tokens removed
- Average notification latency

### Logging

The notifier logs important events:
- Device registrations/unregistrations
- Notification sends (with APNs ID)
- Invalid device token removals
- Cleanup operations

## Limitations

### Current Implementation

- **In-memory storage**: Device registrations are stored in memory. They're lost on restart.
- **No persistence**: Implement persistent storage (Redis, database) for production.
- **No token validation**: Device tokens aren't validated before sending.
- **Basic error handling**: More sophisticated retry logic could be added.

### Future Enhancements

- [ ] Persistent storage for device registrations
- [ ] Redis/Memcached caching layer
- [ ] Notification history tracking
- [ ] Advanced retry logic with exponential backoff
- [ ] APNs feedback service integration
- [ ] Support for notification actions
- [ ] Support for notification categories
- [ ] Metrics and monitoring integration (Prometheus)

## Dependencies

```go
require (
    github.com/sideshow/apns2 v0.23.0
)
```

## References

- [Apple Push Notification Service](https://developer.apple.com/documentation/usernotifications)
- [APNs Provider API](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)
- [apns2 Go Library](https://github.com/sideshow/apns2)
- [Token-based Authentication](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns)

## Support

For issues or questions:
- Check server logs for APNs errors
- Verify APNs key configuration
- Test with APNs development environment first
- Check Apple Developer Portal for APNs key validity
- Review APNs response codes in logs
