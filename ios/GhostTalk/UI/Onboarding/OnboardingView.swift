import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep: OnboardingStep = .welcome
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    enum OnboardingStep {
        case welcome
        case createOrImport
        case createIdentity
        case displayRecoveryPhrase
        case importIdentity
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack {
                    switch currentStep {
                    case .welcome:
                        WelcomeView(onContinue: {
                            withAnimation {
                                currentStep = .createOrImport
                            }
                        })
                    case .createOrImport:
                        CreateOrImportView(
                            onCreate: {
                                withAnimation {
                                    currentStep = .createIdentity
                                }
                            },
                            onImport: {
                                withAnimation {
                                    currentStep = .importIdentity
                                }
                            }
                        )
                    case .createIdentity:
                        CreateIdentityView(
                            onComplete: { identity in
                                withAnimation {
                                    currentStep = .displayRecoveryPhrase
                                }
                            },
                            onError: { error in
                                errorMessage = error
                                showError = true
                            }
                        )
                    case .displayRecoveryPhrase:
                        RecoveryPhraseView(
                            onComplete: {
                                // Identity already created, just finish onboarding
                            }
                        )
                    case .importIdentity:
                        ImportIdentityView(
                            onComplete: {
                                // Identity imported successfully
                            },
                            onError: { error in
                                errorMessage = error
                                showError = true
                            }
                        )
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(AppState())
    }
}
