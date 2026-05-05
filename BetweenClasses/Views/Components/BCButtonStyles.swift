import SwiftUI

// MARK: - Primary (accent fill)

struct BCPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let base = Color.bcAccent.opacity(isEnabled ? 1 : 0.38)
        let pressed = configuration.isPressed ? Color.bcAccentMuted : base

        return configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.accentOnAccent.opacity(isEnabled ? 1 : 0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                    .fill(pressed)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                    .strokeBorder(Color.white.opacity(configuration.isPressed ? 0.22 : 0.12), lineWidth: 1)
            )
            .shadow(color: isEnabled ? Color.bcAccent.opacity(configuration.isPressed ? 0.12 : 0.22) : .clear, radius: 16, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(BCMotion.microSpring, value: configuration.isPressed)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55), trigger: configuration.isPressed) { old, new in
                !old && new
            }
    }
}

// MARK: - Ghost text / secondary

struct BCGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bcCaption)
            .foregroundStyle(configuration.isPressed ? Color.bcAccent : Color.textSecond)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? Color.bcAccentSubtle
                            : Color.white.opacity(0.035)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                    .strokeBorder(Color.glassStroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(BCMotion.microSpring, value: configuration.isPressed)
    }
}

// MARK: - Toolbar icon (glass chip)

struct BCToolbarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(BCMotion.microSpring, value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed) { old, new in
                old == false && new == true
            }
    }
}
