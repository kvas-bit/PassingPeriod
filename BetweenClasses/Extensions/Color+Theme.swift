import SwiftUI
import UIKit

extension Color {
    // Backgrounds
    static let bgPrimary  = Color(hex: "#08090a")
    static let bgSurface  = Color(hex: "#0f1011")
    static let bgElevated = Color(hex: "#191a1b")

    // Text
    static let textPrimary = Color.white
    static let textSecond  = Color.white.opacity(0.5)
    static let textTertiary = Color.white.opacity(0.25)

    // Glass
    static let glassStroke = Color.white.opacity(0.10)
    static let glassFill   = Color.white.opacity(0.045)
    static let glassStrokeOuter = Color.white.opacity(0.06)

    /// Single brand accent — ice blue tuned for contrast on near-black.
    static let bcAccent = Color(hex: "#5EB8FF")
    /// Text / icons placed directly on the accent fill.
    static let accentOnAccent = Color(hex: "#050607")
    /// Subtle accent wash (chips, focus rings, selection).
    static let bcAccentSubtle = Color.bcAccent.opacity(0.14)
    /// Pressed / highlighted control surface.
    static let bcAccentMuted = Color.bcAccent.opacity(0.22)

    /// Primary interactive emphasis (replaces flat white as the main CTA hue).
    static var accentPrimary: Color { bcAccent }

    private static let mutedBaseHues: [Double] = [0.58, 0.61, 0.64, 0.69, 0.74, 0.79, 0.83, 0.91]
    private static let monochromeSubjectHex = "#D3D7DE"
    private static let monochromeTopicHex = "#A8AFBB"
    private static let monochromeNoteHex = "#7F8897"

    static var isColorCodingEnabled: Bool {
        UserDefaults.standard.object(forKey: "bc_color_coding_enabled") as? Bool ?? true
    }

    static func generatedSubjectHex(for seed: String) -> String {
        guard isColorCodingEnabled else { return monochromeSubjectHex }

        let normalized = seed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = normalized.unicodeScalars.reduce(UInt64(0x9e3779b97f4a7c15)) { partial, scalar in
            (partial ^ UInt64(scalar.value)).multipliedReportingOverflow(by: 1099511628211).partialValue
        }
        let paletteIndex = Int(hash % UInt64(mutedBaseHues.count))
        let baseHue = mutedBaseHues[paletteIndex]
        let hueJitter = Double(Int((hash >> 7) % 7) - 3) * 0.004
        let hue = min(max(baseHue + hueJitter, 0), 0.999)
        let saturation = 0.20 + Double((hash >> 11) % 9) / 100.0
        let brightness = 0.72 + Double((hash >> 17) % 8) / 100.0
        return UIColor(
            hue: CGFloat(hue),
            saturation: CGFloat(min(saturation, 0.30)),
            brightness: CGFloat(min(brightness, 0.80)),
            alpha: 1
        ).hexString
    }

    static func derivedHex(from baseHex: String, seed: String, role: PaletteRole) -> String {
        guard isColorCodingEnabled else {
            switch role {
            case .topic: return monochromeTopicHex
            case .note: return monochromeNoteHex
            }
        }

        let base = UIColor(Color(hex: baseHex))
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 1

        guard base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return baseHex
        }

        let hash = seed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().unicodeScalars.reduce(UInt64(2166136261)) { partial, scalar in
            (partial ^ UInt64(scalar.value)).multipliedReportingOverflow(by: 16777619).partialValue
        }
        let hueOffset = CGFloat(Int(hash % 7) - 3) * 0.004
        let satOffset = CGFloat(Int((hash >> 4) % 5) - 2) * 0.010
        let brightOffset = CGFloat(Int((hash >> 8) % 5) - 2) * 0.010

        let tunedHue = (hue + hueOffset).truncatingRemainder(dividingBy: 1)
        let wrappedHue = tunedHue < 0 ? tunedHue + 1 : tunedHue

        let adjusted: UIColor
        switch role {
        case .topic:
            adjusted = UIColor(
                hue: wrappedHue,
                saturation: min(max(saturation * 0.78 + satOffset, 0.14), 0.28),
                brightness: min(max(brightness * 1.03 + 0.03 + brightOffset, 0.62), 0.84),
                alpha: alpha
            )
        case .note:
            adjusted = UIColor(
                hue: wrappedHue,
                saturation: min(max(saturation * 0.52 + satOffset, 0.08), 0.20),
                brightness: min(max(brightness * 1.08 + 0.06 + brightOffset, 0.66), 0.88),
                alpha: alpha
            )
        }

        return adjusted.hexString
    }

    enum PaletteRole {
        case topic
        case note
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >>  8) & 0xFF) / 255
            b = Double( int        & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }

    /// For SceneKit / UIKit bridges (e.g. knowledge graph nodes).
    var uiColor: UIColor { UIColor(self) }
}

extension Subject {
    var displayColorHex: String {
        guard Color.isColorCodingEnabled else {
            return Color.generatedSubjectHex(for: name)
        }

        let trimmed = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidColorHex(trimmed), trimmed.uppercased() != "#FFFFFF" else {
            return Color.generatedSubjectHex(for: name)
        }
        return trimmed
    }

    var displayColor: Color {
        Color(hex: displayColorHex)
    }

    func topicColorHex(for topicName: String) -> String {
        Color.derivedHex(from: displayColorHex, seed: "\(name)-topic-\(topicName)", role: .topic)
    }

    func topicColor(for topicName: String) -> Color {
        Color(hex: topicColorHex(for: topicName))
    }

    func noteColorHex(for topicName: String) -> String {
        Color.derivedHex(from: topicColorHex(for: topicName), seed: "\(name)-note-\(topicName)", role: .note)
    }

    func noteColor(for topicName: String) -> Color {
        Color(hex: noteColorHex(for: topicName))
    }

    private static func isValidColorHex(_ value: String) -> Bool {
        value.range(of: "^#?[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }
}

private extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#FFFFFF"
        }
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}
