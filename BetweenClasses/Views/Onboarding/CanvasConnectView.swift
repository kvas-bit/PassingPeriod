import SwiftUI

struct CanvasConnectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var school = ""
    @State private var token = ""
    @State private var icalURL = ""
    @State private var geminiKey = ""
    @State private var elevenLabsKey = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {

                        // Canvas section
                        sectionHeader("Canvas", icon: "graduationcap.fill")

                        inputField(label: "School domain", placeholder: "e.g. berkeley", text: $school)
                        secureField(label: "Access token", placeholder: "Paste from Canvas Settings", text: $token)

                        Text("Generate at: Canvas → Account → Settings → Approved Integrations → New Access Token")
                            .bcCaption()
                            .foregroundStyle(.textTertiary)

                        // iCal section
                        sectionHeader("iCal Schedule (optional)", icon: "calendar")
                        inputField(label: "iCal URL", placeholder: "webcal://...", text: $icalURL)
                        Text("Export from your university portal or Blue.")
                            .bcCaption()
                            .foregroundStyle(.textTertiary)

                        // API Keys section
                        sectionHeader("API Keys", icon: "key.fill")
                        secureField(label: "Gemini API key", placeholder: "AIza...", text: $geminiKey)
                        secureField(label: "ElevenLabs API key", placeholder: "sk_...", text: $elevenLabsKey)

                        if let err = error {
                            Text(err)
                                .bcCaption()
                                .foregroundStyle(.red)
                        }

                        // Save button
                        Button {
                            save()
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Connect")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)

                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.textSecond)
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.textSecond)
            Text(title.uppercased())
                .bcCaption()
                .foregroundStyle(.textSecond)
        }
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .bcCaption()
                .foregroundStyle(.textSecond)
            TextField(placeholder, text: text)
                .bcBody()
                .foregroundStyle(.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 12)
        }
    }

    private func secureField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .bcCaption()
                .foregroundStyle(.textSecond)
            SecureField(placeholder, text: text)
                .bcBody()
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 12)
        }
    }

    private func save() {
        isSaving = true
        error = nil

        do {
            if !school.isEmpty { try KeychainService.save(school.lowercased(), for: KeychainKey.canvasSchool) }
            if !token.isEmpty  { try KeychainService.save(token, for: KeychainKey.canvasToken) }
            if !icalURL.isEmpty { try KeychainService.save(icalURL, for: KeychainKey.icalURL) }
            if !geminiKey.isEmpty { try KeychainService.save(geminiKey, for: KeychainKey.geminiKey) }
            if !elevenLabsKey.isEmpty { try KeychainService.save(elevenLabsKey, for: KeychainKey.elevenLabsKey) }

            appState.completeOnboarding()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

#Preview {
    CanvasConnectView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
