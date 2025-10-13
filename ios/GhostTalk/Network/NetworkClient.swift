import Foundation

/// NetworkClient handles HTTP/HTTPS communication with GhostNodes
class NetworkClient {
    
    private let session: URLSession
    private let timeout: TimeInterval = 30.0
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Packet Sending
    
    /// Send onion packet to a node
    func sendPacket(_ packet: Data, to address: String) throws {
        guard let url = URL(string: "https://\(address)/api/v1/onion") else {
            throw NetworkError.invalidAddress
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = packet
        
        let semaphore = DispatchSemaphore(value: 0)
        var responseError: Error?
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                responseError = error
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 202 {
                    responseError = NetworkError.httpError(httpResponse.statusCode)
                }
            }
            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        
        if let error = responseError {
            throw error
        }
    }
    
    // MARK: - Message Fetching
    
    /// Fetch messages from swarm node
    func fetchMessages(from address: String, sessionID: String) async throws -> [Data] {
        guard let url = URL(string: "https://\(address)/api/v1/swarm/\(sessionID)") else {
            throw NetworkError.invalidAddress
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        // Parse response (assuming JSON array of base64-encoded messages)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            return []
        }
        
        var result: [Data] = []
        for message in messages {
            if let base64 = message["data"] as? String,
               let messageData = Data(base64Encoded: base64) {
                result.append(messageData)
            }
        }
        
        return result
    }
    
    // MARK: - Node Discovery
    
    /// Fetch list of available nodes from directory service
    func fetchNodes(from directoryURL: String) async throws -> [NodeInfo] {
        guard let url = URL(string: "\(directoryURL)/api/v1/directory/nodes") else {
            throw NetworkError.invalidAddress
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        // Parse JSON response
        let decoder = JSONDecoder()
        let nodeList = try decoder.decode(NodeListResponse.self, from: data)
        
        return nodeList.nodes
    }
    
    // MARK: - Health Check
    
    /// Check if a node is healthy and reachable
    func checkHealth(of address: String) async -> Bool {
        guard let url = URL(string: "https://\(address)/health") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}

// MARK: - Supporting Types

struct NodeInfo: Codable {
    let sessionID: String
    let publicKey: String // Base64 encoded
    let address: String
    let port: Int
    let region: String?
    let version: String?
    
    var fullAddress: String {
        return "\(address):\(port)"
    }
    
    var publicKeyData: Data? {
        return Data(base64Encoded: publicKey)
    }
}

struct NodeListResponse: Codable {
    let nodes: [NodeInfo]
    let timestamp: Int64
}

enum NetworkError: Error {
    case invalidAddress
    case invalidResponse
    case httpError(Int)
    case timeout
    case connectionFailed
}
