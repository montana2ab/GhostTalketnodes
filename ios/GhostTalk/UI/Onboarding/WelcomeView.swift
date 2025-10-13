import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Logo/Icon
            Image(systemName: "message.badge.filled.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .foregroundColor(.blue)
            
            // Title
            Text("Welcome to GhostTalk")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text("Private, anonymous, secure messaging")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Features
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "lock.shield.fill", 
                          title: "End-to-End Encrypted",
                          description: "Your messages are always encrypted")
                
                FeatureRow(icon: "eye.slash.fill",
                          title: "Anonymous",
                          description: "No phone number or email required")
                
                FeatureRow(icon: "network",
                          title: "Onion Routed",
                          description: "Messages route through 3 nodes for privacy")
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Continue button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(onContinue: {})
    }
}
