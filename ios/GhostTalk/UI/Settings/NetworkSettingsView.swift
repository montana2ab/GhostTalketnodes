import SwiftUI

struct NetworkSettingsView: View {
    @AppStorage("preferredTransport") private var preferredTransport = "HTTPS"
    @AppStorage("circuitRefreshInterval") private var circuitRefreshInterval = 300.0
    @State private var isRefreshing = false
    @State private var lastRefreshDate: Date?
    @State private var showRefreshAlert = false
    @State private var refreshAlertMessage = ""
    
    let transportOptions = ["HTTPS", "HTTP/2", "QUIC"]
    let directoryURL = "https://directory.ghosttalk.network" // Default directory service
    
    var body: some View {
        Form {
            Section {
                Picker("Transport Protocol", selection: $preferredTransport) {
                    ForEach(transportOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            } header: {
                Text("Connection")
            } footer: {
                Text("HTTPS is recommended for maximum compatibility")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Circuit Refresh Interval")
                        Spacer()
                        Text("\(Int(circuitRefreshInterval))s")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $circuitRefreshInterval, in: 60...600, step: 30)
                }
            } header: {
                Text("Onion Routing")
            } footer: {
                Text("How often to refresh the 3-hop circuit. Lower values provide better security but use more bandwidth.")
            }
            
            Section {
                NavigationLink(destination: NodeListView()) {
                    Label("Bootstrap Nodes", systemImage: "network")
                }
                
                Button(action: refreshNodes) {
                    HStack {
                        Label("Refresh Node List", systemImage: "arrow.clockwise")
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRefreshing)
                
                if let lastRefresh = lastRefreshDate {
                    HStack {
                        Text("Last Updated")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(lastRefresh, style: .relative)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Network Nodes")
            } footer: {
                Text("Fetches the latest list of available GhostNodes from the directory service.")
            }
        }
        .navigationTitle("Network Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Node Refresh", isPresented: $showRefreshAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(refreshAlertMessage)
        }
    }
    
    private func refreshNodes() {
        isRefreshing = true
        
        Task {
            do {
                let networkClient = NetworkClient()
                let nodes = try await networkClient.fetchNodes(from: directoryURL)
                
                // Store nodes in UserDefaults for persistence
                let encoder = JSONEncoder()
                if let encoded = try? encoder.encode(nodes) {
                    UserDefaults.standard.set(encoded, forKey: "cachedNodes")
                }
                
                await MainActor.run {
                    lastRefreshDate = Date()
                    refreshAlertMessage = "Successfully refreshed \(nodes.count) nodes"
                    showRefreshAlert = true
                    isRefreshing = false
                }
            } catch {
                await MainActor.run {
                    refreshAlertMessage = "Failed to refresh nodes: \(error.localizedDescription)"
                    showRefreshAlert = true
                    isRefreshing = false
                }
            }
        }
    }
}

struct NodeListView: View {
    @State private var nodes: [NodeInfo] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading nodes...")
            } else if nodes.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No nodes available")
                        .font(.headline)
                    Text("Try refreshing the node list from Network Settings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(nodes, id: \.sessionID) { node in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text(node.address)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            HStack {
                                if let region = node.region {
                                    Text(region)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let version = node.version {
                                    Text("v\(version)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Bootstrap Nodes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCachedNodes()
        }
    }
    
    private func loadCachedNodes() {
        // Load nodes from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "cachedNodes") {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([NodeInfo].self, from: data) {
                nodes = decoded
            }
        } else {
            // Fallback to default bootstrap nodes
            nodes = [
                NodeInfo(
                    sessionID: "bootstrap1",
                    publicKey: "",
                    address: "node1.ghosttalk.network",
                    port: 9000,
                    region: "US-East",
                    version: "1.0.0"
                ),
                NodeInfo(
                    sessionID: "bootstrap2",
                    publicKey: "",
                    address: "node2.ghosttalk.network",
                    port: 9000,
                    region: "EU-West",
                    version: "1.0.0"
                ),
                NodeInfo(
                    sessionID: "bootstrap3",
                    publicKey: "",
                    address: "node3.ghosttalk.network",
                    port: 9000,
                    region: "Asia-East",
                    version: "1.0.0"
                )
            ]
        }
        isLoading = false
    }
}

struct NetworkSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkSettingsView()
        }
    }
}
