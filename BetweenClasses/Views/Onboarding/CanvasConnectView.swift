import SwiftUI

struct CanvasConnectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var school = ""
    @State private var token = ""
    @State private var icalURL = ""
    @State private var geminiKey = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var refreshCredentialsTick = 0

    private var tokenIsPlaceholder: Bool { token == "••••••••" }
    private var geminiIsPlaceholder: Bool { geminiKey == "••••••••" }
    private var schoolTrimmed: String { school.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sync classes and unlock imports")
                                .bcBody()
                                .foregroundStyle(Color.textPrimary)
                            Text("Credentials stay on-device in the Keychain. You can connect Canvas only, add iCal later, or both.")
                                .bcCaption()
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.bottom, 4)

                        connectionStatusStrip

                        // Canvas section
                        formSection(title: "Canvas", icon: "graduationcap.fill") {
                            inputField(label: "School domain", placeholder: "e.g. berkeley or canvas.berkeley.edu", text: $school)
                            secureField(label: "Access token", placeholder: "Paste from Canvas Settings", text: $token)

                            Text("Domain: subdomain (berkeley) or full host (canvas.school.edu). Token: Canvas → Account → Settings → Approved Integrations → New Access Token")
                                .bcCaption()
                                .foregroundStyle(Color.textTertiary)
                        }

                        // iCal section
                        formSection(title: "iCal schedule", subtitle: "Optional — adds meeting times", icon: "calendar") {
                            inputField(label: "iCal URL", placeholder: "webcal:// or https://…", text: $icalURL)
                            Text("Export from your university portal or Blue. Leave blank to skip.")
                                .bcCaption()
                                .foregroundStyle(Color.textTertiary)
                        }

                        // API Keys section
                        formSection(title: "Gemini / AI", subtitle: "Needed for cleanup & voice", icon: "key.fill") {
                            secureField(label: "Gemini API key", placeholder: "AIza…", text: $geminiKey)
                            Text("Stored locally like your Canvas token. Used when you clean up OCR text or run AI-powered quiz helpers.")
                                .bcCaption()
                                .foregroundStyle(Color.textTertiary)
                        }

                        formSection(title: "Appearance", icon: "paintpalette") {
                            Toggle(isOn: Binding(
                                get: { appState.colorCodingEnabled },
                                set: { appState.setColorCodingEnabled($0) }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Subject color coding")
                                        .bcBody()
                                        .foregroundStyle(Color.textPrimary)
                                    Text("Adds soft subject/topic tints in quiz, schedule, graph, and notes. Turn it off for full monochrome.")
                                        .bcCaption()
                                        .foregroundStyle(Color.textTertiary)
                                }
                            }
                            .tint(Color.white.opacity(0.9))
                        }

                        if let err = error {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.red.opacity(0.85))
                                Text(err)
                                    .bcCaption()
                                    .foregroundStyle(Color.textPrimary.opacity(0.92))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.22), lineWidth: 1)
                            )
                        }

                        Button {
                            save()
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.black)
                                } else {
                                    Text(primaryConnectTitle)
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
                if KeychainService.exists(KeychainKey.canvasToken)    { token = "••••••••" }
                if KeychainService.exists(KeychainKey.geminiKey)      { geminiKey = "••••••••" }
                refreshCredentialsTick &+= 1
            }
        }
    }

    private var primaryConnectTitle: String {
        let canvasSaved = KeychainService.exists(KeychainKey.canvasToken) && KeychainService.exists(KeychainKey.canvasSchool)
        return canvasSaved ? "Save & continue" : "Connect"
    }

    private var connectionStatusStrip: some View {
        let _ = refreshCredentialsTick
        return HStack(spacing: 8) {
            statusDot(label: "Canvas", active: KeychainService.exists(KeychainKey.canvasToken) && KeychainService.exists(KeychainKey.canvasSchool))
            statusDot(label: "iCal", active: KeychainService.exists(KeychainKey.icalURL))
            statusDot(label: "Gemini", active: KeychainService.exists(KeychainKey.geminiKey))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous)
                .strokeBorder(Color.glassStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(connectionAccessibilityLabel)
    }

    private var connectionAccessibilityLabel: String {
        let parts = [
            KeychainService.exists(KeychainKey.canvasToken) && KeychainService.exists(KeychainKey.canvasSchool) ? "Canvas linked" : "Canvas not linked",
            KeychainService.exists(KeychainKey.icalURL) ? "iCal linked" : "iCal not linked",
            KeychainService.exists(KeychainKey.geminiKey) ? "Gemini key saved" : "Gemini key missing",
        ]
        return parts.joined(separator: ", ")
    }

    private func statusDot(label: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green.opacity(0.85) : Color.white.opacity(0.18))
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(active ? Color.textPrimary.opacity(0.92) : Color.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(active ? 0.06 : 0.03), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.glassStroke.opacity(active ? 0.35 : 0.2), lineWidth: 1)
        )
    }

    private func formSection(title: String, subtitle: String? = nil, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecond)
                    Text(title.uppercased())
                        .bcCaption()
                        .foregroundStyle(Color.textSecond)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .glassCard(cornerRadius: BCRadius.control)
        }
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
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.glassStroke.opacity(0.5), lineWidth: 1)
                )
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
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.glassStroke.opacity(0.5), lineWidth: 1)
                )
        }
    }

    private func save() {
        isSaving = true
        error = nil

        let hasNewToken = !token.isEmpty && !tokenIsPlaceholder
        if hasNewToken && schoolTrimmed.isEmpty {
            error = "Add your Canvas school domain before saving a new access token."
            isSaving = false
            return
        }

        do {
            if !schoolTrimmed.isEmpty {
                try KeychainService.save(schoolTrimmed.lowercased(), for: KeychainKey.canvasSchool)
            }
            if hasNewToken { try KeychainService.save(token, for: KeychainKey.canvasToken) }
            let icalTrim = icalURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !icalTrim.isEmpty { try KeychainService.save(icalTrim, for: KeychainKey.icalURL) }
            let hasNewGemini = !geminiKey.isEmpty && !geminiIsPlaceholder
            if hasNewGemini { try KeychainService.save(geminiKey, for: KeychainKey.geminiKey) }

            refreshCredentialsTick &+= 1
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
