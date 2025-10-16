import Foundation
import SQLite3

// MARK: - Database Manager

/// DatabaseManager handles all SQLite operations
/// NOTE: This uses SQLite. For production, upgrade to SQLCipher for encryption
class DatabaseManager {
    
    private var db: OpaquePointer?
    private let dbPath: String
    private let queue = DispatchQueue(label: "com.ghosttalk.database", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init() throws {
        // Get database path in app's documents directory
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.dbPath = documentsPath.appendingPathComponent("ghosttalk.db").path
        
        // Open database
        try openDatabase()
        
        // Create tables
        try createTables()
        
        // Run migrations
        try runMigrations()
    }
    
    deinit {
        closeDatabase()
    }
    
    // MARK: - Database Lifecycle
    
    private func openDatabase() throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        
        if sqlite3_open_v2(dbPath, &db, flags, nil) != SQLITE_OK {
            throw DatabaseError.openFailed(message: lastErrorMessage())
        }
        
        // Enable WAL mode for better concurrency
        try execute("PRAGMA journal_mode = WAL")
        
        // Enable foreign keys
        try execute("PRAGMA foreign_keys = ON")
    }
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    // MARK: - Schema Creation
    
    private func createTables() throws {
        // Conversations table
        try execute("""
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL UNIQUE,
                display_name TEXT,
                avatar_data BLOB,
                last_message_id TEXT,
                last_message_text TEXT,
                last_message_timestamp REAL,
                unread_count INTEGER DEFAULT 0,
                is_pinned INTEGER DEFAULT 0,
                is_muted INTEGER DEFAULT 0,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
        """)
        
        // Messages table
        try execute("""
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                conversation_id TEXT NOT NULL,
                text TEXT NOT NULL,
                sender_session_id TEXT NOT NULL,
                recipient_session_id TEXT NOT NULL,
                timestamp REAL NOT NULL,
                status INTEGER DEFAULT 0,
                is_outgoing INTEGER NOT NULL,
                is_read INTEGER DEFAULT 0,
                attachment_url TEXT,
                attachment_type TEXT,
                reply_to_message_id TEXT,
                created_at REAL NOT NULL,
                FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            )
        """)
        
        // Contacts table
        try execute("""
            CREATE TABLE IF NOT EXISTS contacts (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL UNIQUE,
                display_name TEXT,
                avatar_data BLOB,
                notes TEXT,
                is_blocked INTEGER DEFAULT 0,
                is_trusted INTEGER DEFAULT 0,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
        """)
        
        // Create indices for better query performance
        try execute("CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, timestamp DESC)")
        try execute("CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp DESC)")
        try execute("CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at DESC)")
    }
    
    private func runMigrations() throws {
        // Get current schema version
        let version = try getSchemaVersion()
        
        // Run migrations if needed
        if version < 1 {
            // Migration v1: Initial schema (already created above)
            try setSchemaVersion(1)
        }
        
        // Add future migrations here
        // if version < 2 { ... }
    }
    
    private func getSchemaVersion() throws -> Int {
        // Check if user_version pragma exists
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                return Int(sqlite3_column_int(statement, 0))
            }
        }
        
        return 0
    }
    
    private func setSchemaVersion(_ version: Int) throws {
        try execute("PRAGMA user_version = \(version)")
    }
    
    // MARK: - Execute SQL
    
    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        defer { sqlite3_free(errorMessage) }
        
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            throw DatabaseError.executeFailed(message: message)
        }
    }
    
    private func lastErrorMessage() -> String {
        if let error = sqlite3_errmsg(db) {
            return String(cString: error)
        }
        return "Unknown error"
    }
    
    // MARK: - Conversations
    
    func saveConversation(_ conversation: DBConversation) throws {
        try queue.sync {
            let sql = """
                INSERT OR REPLACE INTO conversations 
                (id, session_id, display_name, avatar_data, last_message_id, last_message_text, 
                 last_message_timestamp, unread_count, is_pinned, is_muted, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: lastErrorMessage())
            }
            
            sqlite3_bind_text(statement, 1, conversation.id, -1, nil)
            sqlite3_bind_text(statement, 2, conversation.sessionID, -1, nil)
            bindOptionalText(statement, 3, conversation.displayName)
            bindOptionalBlob(statement, 4, conversation.avatarData)
            bindOptionalText(statement, 5, conversation.lastMessageID)
            bindOptionalText(statement, 6, conversation.lastMessageText)
            bindOptionalDate(statement, 7, conversation.lastMessageTimestamp)
            sqlite3_bind_int(statement, 8, Int32(conversation.unreadCount))
            sqlite3_bind_int(statement, 9, conversation.isPinned ? 1 : 0)
            sqlite3_bind_int(statement, 10, conversation.isMuted ? 1 : 0)
            sqlite3_bind_double(statement, 11, conversation.createdAt.timeIntervalSince1970)
            sqlite3_bind_double(statement, 12, conversation.updatedAt.timeIntervalSince1970)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(message: lastErrorMessage())
            }
        }
    }
    
    func getConversation(byID id: String) throws -> DBConversation? {
        return try queue.sync {
            let sql = "SELECT * FROM conversations WHERE id = ?"
            return try querySingleConversation(sql: sql, bindID: id)
        }
    }
    
    func getConversation(bySessionID sessionID: String) throws -> DBConversation? {
        return try queue.sync {
            let sql = "SELECT * FROM conversations WHERE session_id = ?"
            return try querySingleConversation(sql: sql, bindID: sessionID)
        }
    }
    
    func getAllConversations() throws -> [DBConversation] {
        return try queue.sync {
            let sql = "SELECT * FROM conversations ORDER BY updated_at DESC"
            return try queryConversations(sql: sql)
        }
    }
    
    func deleteConversation(_ id: String) throws {
        try queue.sync {
            let sql = "DELETE FROM conversations WHERE id = ?"
            try executeWithBinding(sql: sql, bindings: [.text(id)])
        }
    }
    
    private func querySingleConversation(sql: String, bindID: String) throws -> DBConversation? {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        
        sqlite3_bind_text(statement, 1, bindID, -1, nil)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return parseConversation(from: statement)
        }
        
        return nil
    }
    
    private func queryConversations(sql: String) throws -> [DBConversation] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        
        var conversations: [DBConversation] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            conversations.append(parseConversation(from: statement))
        }
        
        return conversations
    }
    
    private func parseConversation(from statement: OpaquePointer?) -> DBConversation {
        return DBConversation(
            id: String(cString: sqlite3_column_text(statement, 0)),
            sessionID: String(cString: sqlite3_column_text(statement, 1)),
            displayName: columnText(statement, 2),
            avatarData: columnBlob(statement, 3),
            lastMessageID: columnText(statement, 4),
            lastMessageText: columnText(statement, 5),
            lastMessageTimestamp: columnDate(statement, 6),
            unreadCount: Int(sqlite3_column_int(statement, 7)),
            isPinned: sqlite3_column_int(statement, 8) == 1,
            isMuted: sqlite3_column_int(statement, 9) == 1,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 10)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 11))
        )
    }
    
    // MARK: - Messages
    
    func saveMessage(_ message: DBMessage) throws {
        try queue.sync {
            let sql = """
                INSERT OR REPLACE INTO messages 
                (id, conversation_id, text, sender_session_id, recipient_session_id, timestamp, 
                 status, is_outgoing, is_read, attachment_url, attachment_type, reply_to_message_id, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: lastErrorMessage())
            }
            
            sqlite3_bind_text(statement, 1, message.id, -1, nil)
            sqlite3_bind_text(statement, 2, message.conversationID, -1, nil)
            sqlite3_bind_text(statement, 3, message.text, -1, nil)
            sqlite3_bind_text(statement, 4, message.senderSessionID, -1, nil)
            sqlite3_bind_text(statement, 5, message.recipientSessionID, -1, nil)
            sqlite3_bind_double(statement, 6, message.timestamp.timeIntervalSince1970)
            sqlite3_bind_int(statement, 7, Int32(message.status))
            sqlite3_bind_int(statement, 8, message.isOutgoing ? 1 : 0)
            sqlite3_bind_int(statement, 9, message.isRead ? 1 : 0)
            bindOptionalText(statement, 10, message.attachmentURL)
            bindOptionalText(statement, 11, message.attachmentType)
            bindOptionalText(statement, 12, message.replyToMessageID)
            sqlite3_bind_double(statement, 13, message.createdAt.timeIntervalSince1970)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(message: lastErrorMessage())
            }
        }
    }
    
    func getMessage(byID id: String) throws -> DBMessage? {
        return try queue.sync {
            let sql = "SELECT * FROM messages WHERE id = ?"
            return try querySingleMessage(sql: sql, bindID: id)
        }
    }
    
    func getMessages(forConversation conversationID: String, limit: Int = 100) throws -> [DBMessage] {
        return try queue.sync {
            let sql = """
                SELECT * FROM messages 
                WHERE conversation_id = ? 
                ORDER BY timestamp DESC 
                LIMIT ?
            """
            
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: lastErrorMessage())
            }
            
            sqlite3_bind_text(statement, 1, conversationID, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(limit))
            
            var messages: [DBMessage] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                messages.append(parseMessage(from: statement))
            }
            
            return messages.reversed() // Return in chronological order
        }
    }
    
    func updateMessageStatus(_ messageID: String, status: Int) throws {
        try queue.sync {
            let sql = "UPDATE messages SET status = ? WHERE id = ?"
            
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: lastErrorMessage())
            }
            
            sqlite3_bind_int(statement, 1, Int32(status))
            sqlite3_bind_text(statement, 2, messageID, -1, nil)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(message: lastErrorMessage())
            }
        }
    }
    
    func deleteMessage(_ id: String) throws {
        try queue.sync {
            let sql = "DELETE FROM messages WHERE id = ?"
            try executeWithBinding(sql: sql, bindings: [.text(id)])
        }
    }
    
    private func querySingleMessage(sql: String, bindID: String) throws -> DBMessage? {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        
        sqlite3_bind_text(statement, 1, bindID, -1, nil)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return parseMessage(from: statement)
        }
        
        return nil
    }
    
    private func parseMessage(from statement: OpaquePointer?) -> DBMessage {
        return DBMessage(
            id: String(cString: sqlite3_column_text(statement, 0)),
            conversationID: String(cString: sqlite3_column_text(statement, 1)),
            text: String(cString: sqlite3_column_text(statement, 2)),
            senderSessionID: String(cString: sqlite3_column_text(statement, 3)),
            recipientSessionID: String(cString: sqlite3_column_text(statement, 4)),
            timestamp: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
            status: Int(sqlite3_column_int(statement, 6)),
            isOutgoing: sqlite3_column_int(statement, 7) == 1,
            isRead: sqlite3_column_int(statement, 8) == 1,
            attachmentURL: columnText(statement, 9),
            attachmentType: columnText(statement, 10),
            replyToMessageID: columnText(statement, 11),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 12))
        )
    }
    
    // MARK: - Contacts
    
    func saveContact(_ contact: DBContact) throws {
        try queue.sync {
            let sql = """
                INSERT OR REPLACE INTO contacts 
                (id, session_id, display_name, avatar_data, notes, is_blocked, is_trusted, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: lastErrorMessage())
            }
            
            sqlite3_bind_text(statement, 1, contact.id, -1, nil)
            sqlite3_bind_text(statement, 2, contact.sessionID, -1, nil)
            bindOptionalText(statement, 3, contact.displayName)
            bindOptionalBlob(statement, 4, contact.avatarData)
            bindOptionalText(statement, 5, contact.notes)
            sqlite3_bind_int(statement, 6, contact.isBlocked ? 1 : 0)
            sqlite3_bind_int(statement, 7, contact.isTrusted ? 1 : 0)
            sqlite3_bind_double(statement, 8, contact.createdAt.timeIntervalSince1970)
            sqlite3_bind_double(statement, 9, contact.updatedAt.timeIntervalSince1970)
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executeFailed(message: lastErrorMessage())
            }
        }
    }
    
    func getContact(bySessionID sessionID: String) throws -> DBContact? {
        return try queue.sync {
            let sql = "SELECT * FROM contacts WHERE session_id = ?"
            
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: lastErrorMessage())
            }
            
            sqlite3_bind_text(statement, 1, sessionID, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                return parseContact(from: statement)
            }
            
            return nil
        }
    }
    
    func getAllContacts() throws -> [DBContact] {
        return try queue.sync {
            let sql = "SELECT * FROM contacts ORDER BY display_name"
            
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(message: lastErrorMessage())
            }
            
            var contacts: [DBContact] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                contacts.append(parseContact(from: statement))
            }
            
            return contacts
        }
    }
    
    func deleteContact(_ sessionID: String) throws {
        try queue.sync {
            let sql = "DELETE FROM contacts WHERE session_id = ?"
            try executeWithBinding(sql: sql, bindings: [.text(sessionID)])
        }
    }
    
    private func parseContact(from statement: OpaquePointer?) -> DBContact {
        return DBContact(
            id: String(cString: sqlite3_column_text(statement, 0)),
            sessionID: String(cString: sqlite3_column_text(statement, 1)),
            displayName: columnText(statement, 2),
            avatarData: columnBlob(statement, 3),
            notes: columnText(statement, 4),
            isBlocked: sqlite3_column_int(statement, 5) == 1,
            isTrusted: sqlite3_column_int(statement, 6) == 1,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
        )
    }
    
    // MARK: - Helper Methods
    
    private enum BindingValue {
        case text(String)
        case int(Int)
        case double(Double)
        case blob(Data)
    }
    
    private func executeWithBinding(sql: String, bindings: [BindingValue]) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(message: lastErrorMessage())
        }
        
        for (index, binding) in bindings.enumerated() {
            let bindIndex = Int32(index + 1)
            switch binding {
            case .text(let value):
                sqlite3_bind_text(statement, bindIndex, value, -1, nil)
            case .int(let value):
                sqlite3_bind_int(statement, bindIndex, Int32(value))
            case .double(let value):
                sqlite3_bind_double(statement, bindIndex, value)
            case .blob(let value):
                value.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, bindIndex, bytes.baseAddress, Int32(value.count), nil)
                }
            }
        }
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executeFailed(message: lastErrorMessage())
        }
    }
    
    private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value = value {
            sqlite3_bind_text(statement, index, value, -1, nil)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    private func bindOptionalBlob(_ statement: OpaquePointer?, _ index: Int32, _ value: Data?) {
        if let value = value {
            value.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(value.count), nil)
            }
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    private func bindOptionalDate(_ statement: OpaquePointer?, _ index: Int32, _ value: Date?) {
        if let value = value {
            sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: text)
    }
    
    private func columnBlob(_ statement: OpaquePointer?, _ index: Int32) -> Data? {
        guard let blob = sqlite3_column_blob(statement, index) else {
            return nil
        }
        let size = Int(sqlite3_column_bytes(statement, index))
        return Data(bytes: blob, count: size)
    }
    
    private func columnDate(_ statement: OpaquePointer?, _ index: Int32) -> Date? {
        let timestamp = sqlite3_column_double(statement, index)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}

// MARK: - Errors

enum DatabaseError: Error {
    case openFailed(message: String)
    case prepareFailed(message: String)
    case executeFailed(message: String)
    case notFound
}
