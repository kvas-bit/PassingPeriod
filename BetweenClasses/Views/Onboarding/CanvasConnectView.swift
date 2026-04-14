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
    @State private var schoolError: String?
    @State private var icalError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {

                        // Canvas section
                        sectionHeader("Canvas", icon: "graduationcap.fill")

                        inputField(label: "School domain", placeholder: "e.g. berkeley or canvas.berkeley.edu", text: $school)
                        if let schoolErr = schoolError {
                            validationHint(schoolErr, icon: "exclamationmark.circle.fill")
                        }
                        secureField(label: "Access token", placeholder: "Paste from Canvas Settings", text: $token)

                        Text("Domain: just the subdomain (berkeley) or full hostname (canvas.school.edu). Token: Canvas → Account → Settings → Approved Integrations → New Access Token")
                            .bcCaption()
                            .foregroundStyle(Color.textTertiary)

                        // iCal section
                        sectionHeader("iCal Schedule (optional)", icon: "calendar")
                        inputField(label: "iCal URL", placeholder: "webcal://...", text: $icalURL)
                        if let icalErr = icalError {
                            validationHint(icalErr, icon: "exclamationmark.circle.fill")
                        }
                        Text("Export from your university portal or Blue.")
                            .bcCaption()
                            .foregroundStyle(Color.textTertiary)

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
                        .foregroundStyle(Color.textSecond)
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .onAppear {
                school       = (try? KeychainService.retrieve(KeychainKey.canvasSchool)) ?? ""
                icalURL      = (try? KeychainService.retrieve(KeychainKey.icalURL))      ?? ""
                // Don't pre-fill secrets — show placeholder so user knows they're set
                if KeychainService.exists(KeychainKey.canvasToken)    { token = "••••••••" }
                if KeychainService.exists(KeychainKey.geminiKey)      { geminiKey = "••••••••" }
                if KeychainService.exists(KeychainKey.elevenLabsKey)  { elevenLabsKey = "••••••••" }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecond)
            Text(title.uppercased())
                .bcCaption()
                .foregroundStyle(Color.textSecond)
        }
    }

    private func validationHint(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .bcCaption()
        }
        .foregroundStyle(.red)
        .padding(.top, 2)
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .bcCaption()
                .foregroundStyle(Color.textSecond)
            TextField(placeholder, text: text)
                .bcBody()
                .foregroundStyle(Color.textPrimary)
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
                .foregroundStyle(Color.textSecond)
            SecureField(placeholder, text: text)
                .bcBody()
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 12)
        }
    }

    private func save() {
        schoolError = nil
        icalError = nil

        // Validate school domain
        if !school.isEmpty {
            let trimmed = school.trimmingCharacters(in: .whitespacesAndNewlines)
            // Must be alphanumeric with optional dots/hyphens
            let validDomain = trimmed.range(of: "^[a-zA-Z0-9.-]+$", options: .regularExpression)
            if validDomain == nil {
                schoolError = "School domain can only contain letters, numbers, dots, and hyphens"
                return
            }
        }

        // Validate iCal URL format if provided
        if !icalURL.isEmpty {
            var urlString = icalURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if urlString.hasPrefix("webcal://") {
                urlString = "https://" + urlString.dropFirst(9)
            }
            if URL(string: urlString) == nil {
                icalError = "Enter a valid webcal or https URL"
                return
            }
        }

        isSaving = true
        error = nil

        do {
            if !school.isEmpty    { try KeychainService.save(school.lowercased(), for: KeychainKey.canvasSchool) }
            if !token.isEmpty && token != "••••••••"          { try KeychainService.save(token, for: KeychainKey.canvasToken) }
            if !icalURL.isEmpty   { try KeychainService.save(icalURL, for: KeychainKey.icalURL) }
            if !geminiKey.isEmpty && geminiKey != "••••••••"  { try KeychainService.save(geminiKey, for: KeychainKey.geminiKey) }
            if !elevenLabsKey.isEmpty && elevenLabsKey != "••••••••" { try KeychainService.save(elevenLabsKey, for: KeychainKey.elevenLabsKey) }

            appState.completeOnboarding()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }
}

#Preview {
    CanvasConnectView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
