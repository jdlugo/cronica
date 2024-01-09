import SwiftUI

struct AboutSettings: View {
#if os(iOS)
    @Environment(\.requestReview) var requestReview
#endif
    @StateObject private var settings = SettingsStore.shared
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
	let buildNumber: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    var body: some View {
        Form {
            Section {
                CenterHorizontalView {
                    VStack {
                        Image("Cronica")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120, alignment: .center)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(radius: 5)
                        Text("Streaming Now")
                            .fontWeight(.semibold)
                            .fontDesign(.monospaced)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.top)
                    }
                }
            }
            
#if os(iOS)
            Button {
                requestReview()
            } label: {
                Text("settingsReviewCronica")
            }
#endif
            
#if os(iOS)
            if let appUrl = URL(string: "https://apple.co/3TV9SLP") {
                ShareLink(item: appUrl).labelStyle(.titleOnly)
            }
#endif
#if os(macOS)
            privacy
#endif
            #if !os(macOS)
            FeedbackSettingsView()
            #endif
            
            
            
            Section {
                
                CenterHorizontalView {
                    Text("Version \(appVersion ?? "") • \(buildNumber)")
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .onTapGesture(count: 4) {
                            withAnimation { settings.displayDeveloperSettings.toggle() }
                        }
                }
            }
        }
        .navigationTitle("aboutTitle")
#if os(macOS)
        .formStyle(.grouped)
#endif
    }
    
    private func aboutButton(title: String, subtitle: String? = nil, url: String) -> some View {
        Button {
            guard let url = URL(string: url) else { return }
#if os(macOS)
            NSWorkspace.shared.open(url)
#else
            UIApplication.shared.open(url)
#endif
        } label: {
			buttonLabels(title: title, subtitle: subtitle)
        }
#if os(macOS)
        .buttonStyle(.link)
#endif
    }
	
	private func buttonLabels(title: String, subtitle: String?) -> some View {
		VStack(alignment: .leading) {
			Text(NSLocalizedString(title, comment: ""))
			if let subtitle {
				Text(NSLocalizedString(subtitle, comment: ""))
					.font(.caption)
					.foregroundColor(.secondary)
			}
		}
	}
    
#if os(macOS)
    private var privacy: some View {
        Section {
            Button("settingsPrivacyPolicy") {
                guard let url = URL(string: "https://streamingnowapp.com/privacy") else { return }
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.link)
        } header: {
            Text("Privacy")
        }
    }
#endif
}

#Preview {
    AboutSettings()
}
