import UIKit

struct Theme {
    // Backgrounds
    static let bgPrimary    = UIColor(hex: "0F0F1A")
    static let bgSecondary  = UIColor(hex: "1A1A2E")
    static let bgTertiary   = UIColor(hex: "16213E")
    static let bgHover      = UIColor(hex: "1F2544")
    static let bgActive     = UIColor(hex: "2A2D5E")
    static let bgCard       = UIColor(hex: "141428")

    // Accent
    static let accent          = UIColor(hex: "6C63FF")
    static let accentHover     = UIColor(hex: "5A52E0")
    static let accentLight     = UIColor(hex: "6C63FF").withAlphaComponent(0.15)
    static let accentSecondary = UIColor(hex: "FF6584")

    // Text
    static let textPrimary   = UIColor(hex: "EAEAEA")
    static let textSecondary = UIColor(hex: "8B8CA0")
    static let textMuted     = UIColor(hex: "555670")

    // Messages (received slightly lighter for contrast, WhatsApp/Telegram style)
    static let msgSent     = UIColor(hex: "6C63FF")
    static let msgReceived = UIColor(hex: "252840")

    // Status
    static let success = UIColor(hex: "43AA8B")
    static let danger  = UIColor(hex: "F94144")
    static let warning = UIColor(hex: "F9844A")

    // Borders
    static let border      = UIColor.white.withAlphaComponent(0.06)
    static let glassBorder = UIColor.white.withAlphaComponent(0.12)

    // Corner radii
    static let radiusSm: CGFloat = 8
    static let radius: CGFloat   = 12
    static let radiusLg: CGFloat = 20
    static let radiusXl: CGFloat = 28
    static let radiusPill: CGFloat = 999

    // Animation
    static let animationFast: TimeInterval = 0.2
    static let animationNormal: TimeInterval = 0.3
    static let animationSpringDamping: CGFloat = 0.8

    // Shadow (for cards)
    static let shadowColor = UIColor.black.cgColor
    static let shadowOpacity: Float = 0.15
    static let shadowRadius: CGFloat = 8
    static let shadowOffset = CGSize(width: 0, height: 2)

    // Typography — SF Rounded (Telegram/WhatsApp style)
    static let fontLargeTitle = fontRounded(size: 34, weight: .bold)
    static let fontDisplay = fontRounded(size: 42, weight: .bold)
    static let fontTitle = fontRounded(size: 28, weight: .bold)
    static let fontHeadline = fontRounded(size: 17, weight: .semibold)
    static let fontBody = fontRounded(size: 16, weight: .regular)
    static let fontSubhead = fontRounded(size: 14, weight: .medium)
    static let fontCaption = fontRounded(size: 12, weight: .regular)
    static let fontSmall = fontRounded(size: 11, weight: .medium)
    static let fontSmallBold = fontRounded(size: 11, weight: .bold)

    // Rounded fonts (Telegram-style)
    static func fontRounded(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        if let rounded = descriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    // Custom font loader — добавьте шрифты в Info.plist (UIAppFonts)
    static func customFont(name: String, size: CGFloat) -> UIFont? {
        UIFont(name: name, size: size)
    }
}

// MARK: - UIColor init from hex
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
