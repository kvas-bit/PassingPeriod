import SwiftUI

// MARK: - Primary (solid white on dark)

struct BCPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 1 : 0.35))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(BCMotion.microSpring, value: configuration.isPressed)
    }
}

// MARK: - Ghost text / secondary

struct BCGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bcCaption)
            .foregroundStyle(Color.textSecond)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.06 : 0.03))
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
    }
}
