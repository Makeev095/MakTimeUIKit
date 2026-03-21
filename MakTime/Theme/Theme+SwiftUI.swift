import SwiftUI
import UIKit

/// Токены дизайн-системы для SwiftUI (согласованы с [Theme](Theme.swift)).
enum MTColor {
    static let bgPrimary = Color(uiColor: Theme.bgPrimary)
    static let bgSecondary = Color(uiColor: Theme.bgSecondary)
    static let bgCard = Color(uiColor: Theme.bgCard)
    static let accent = Color(uiColor: Theme.accent)
    static let textPrimary = Color(uiColor: Theme.textPrimary)
    static let textSecondary = Color(uiColor: Theme.textSecondary)
    static let textMuted = Color(uiColor: Theme.textMuted)
    static let danger = Color(uiColor: Theme.danger)
    static let border = Color(uiColor: Theme.border)
}

enum MTSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
}

enum MTFont {
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title = Font.system(.title2, design: .rounded).weight(.bold)
    static let headline = Font.system(.headline, design: .rounded)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
}

struct MTAvatarView: View {
    let name: String
    let colorHex: String
    var size: CGFloat = 40

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.35, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(uiColor: UIColor(hex: colorHex)))
            .clipShape(Circle())
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

struct MTPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MTFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(MTColor.accent.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
    }
}
