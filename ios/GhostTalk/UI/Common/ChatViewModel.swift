import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isSending: Bool = false
    
    let conversation: Conversation
    private let chatService: ChatService
    private var cancellables = Set<AnyCancellable>()
    
    init(conversation: Conversation) {
        self.conversation = conversation
        self.chatService = ChatService()
        setupSubscriptions()
    }
    
    func loadMessages() {
        // TODO: Load messages from storage
        // For now, using sample data for UI demonstration
        messages = []
    }
    
    func sendMessage(text: String) {
        let message = Message(
            text: text,
            isOutgoing: true,
            status: .sending
        )
        
        messages.append(message)
        isSending = true
        
        // Send via ChatService
        Task {
            do {
                try await chatService.sendMessage(text: text, to: conversation.sessionID)
                
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == message.id }) {
                        messages[index].status = .sent
                    }
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == message.id }) {
                        messages[index].status = .failed
                    }
                    isSending = false
                }
            }
        }
    }
    
    private func setupSubscriptions() {
        // Subscribe to incoming messages
        chatService.messageReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] receivedMessage in
                guard let self = self else { return }
                // Only add messages for this conversation
                if receivedMessage.sender == self.conversation.sessionID {
                    let message = Message(
                        text: receivedMessage.content,
                        timestamp: receivedMessage.timestamp,
                        isOutgoing: false,
                        status: .delivered
                    )
                    self.messages.append(message)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to message status updates
        chatService.messageStatusChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self = self else { return }
                if let index = self.messages.firstIndex(where: { $0.id == update.messageID }) {
                    self.messages[index].status = update.status
                }
            }
            .store(in: &cancellables)
    }
}
