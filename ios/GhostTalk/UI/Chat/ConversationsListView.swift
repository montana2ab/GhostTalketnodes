import SwiftUI

struct ConversationsListView: View {
    @StateObject private var viewModel = ConversationsViewModel()
    @State private var showingNewChat = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.conversations.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "message.badge.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("No Conversations Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Start a new chat by tapping the + button")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // Conversations list
                    List {
                        ForEach(viewModel.conversations) { conversation in
                            NavigationLink(destination: ChatView(conversation: conversation)) {
                                ConversationRow(conversation: conversation)
                            }
                        }
                        .onDelete(perform: deleteConversations)
                    }
                }
            }
            .navigationTitle("GhostTalk")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewChat = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatView(onCreateChat: { sessionID in
                    viewModel.createConversation(with: sessionID)
                    showingNewChat = false
                })
            }
        }
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        viewModel.conversations.remove(atOffsets: offsets)
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(conversation.displayName.prefix(1).uppercased())
                        .font(.title3)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayName)
                        .font(.headline)
                    Spacer()
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessage.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            if conversation.unreadCount > 0 {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("\(conversation.unreadCount)")
                            .font(.caption2)
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

struct ConversationsListView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationsListView()
    }
}
