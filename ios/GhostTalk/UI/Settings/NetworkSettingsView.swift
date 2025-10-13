import SwiftUI

struct NetworkSettingsView: View {
    @AppStorage("preferredTransport") private var preferredTransport = "HTTPS"
    @AppStorage("circuitRefreshInterval") private var circuitRefreshInterval = 300.0
    
    let transportOptions = ["HTTPS", "HTTP/2", "QUIC"]
    
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
                    Label("Refresh Node List", systemImage: "arrow.clockwise")
                }
            } header: {
                Text("Network Nodes")
            }
        }
        .navigationTitle("Network Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func refreshNodes() {
        // TODO: Implement node list refresh
    }
}

struct NodeListView: View {
    @State private var nodes: [String] = [
        "node1.ghosttalk.network",
        "node2.ghosttalk.network",
        "node3.ghosttalk.network"
    ]
    
    var body: some View {
        List {
            ForEach(nodes, id: \.self) { node in
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(node)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .navigationTitle("Bootstrap Nodes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NetworkSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkSettingsView()
        }
    }
}
