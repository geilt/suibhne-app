// Theme.swift
// Suibhne visual theme (matching suibhne.bot website)

import SwiftUI

// MARK: - Colors

extension Color {
    // Core palette
    static let suibhneBgDeep = Color(hex: "0a0a0c")
    static let suibhneBgDark = Color(hex: "12131a")
    static let suibhneGold = Color(hex: "c9a227")
    static let suibhneGoldDim = Color(hex: "8a7019")
    static let suibhneSilver = Color(hex: "a8b2c1")
    static let suibhneText = Color(hex: "d4d4d8")
    static let suibhneTextDim = Color(hex: "71717a")
    static let suibhneAccent = Color(hex: "2d5a4a")
    
    // Semantic
    static let suibhneSuccess = Color(hex: "7fff7f")
    static let suibhneWarning = Color(hex: "ffd700")
    static let suibhneError = Color(hex: "ff6b6b")
    
    // Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// MARK: - Typography

extension Font {
    // Cinzel for headings (Celtic/ancient feel)
    static func cinzel(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Cinzel", size: size).weight(weight)
    }
    
    // Cormorant Garamond for body (elegant serif)
    static func cormorant(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Cormorant Garamond", size: size).weight(weight)
    }
    
    // Fallback system fonts if custom fonts not available
    static let heading = Font.system(size: 16, weight: .semibold, design: .serif)
    static let subheading = Font.system(size: 13, weight: .medium, design: .serif)
    static let body = Font.system(size: 12, weight: .regular, design: .default)
    static let caption = Font.system(size: 10, weight: .regular, design: .default)
    static let mono = Font.system(size: 11, weight: .regular, design: .monospaced)
}

// MARK: - View Modifiers

struct SuibhneCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.suibhneBgDark.opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.suibhneGold.opacity(0.15), lineWidth: 1)
            )
    }
}

struct SuibhneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Color.suibhneGold : Color.suibhneGoldDim)
            .foregroundColor(Color.suibhneBgDeep)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

extension View {
    func suibhneCard() -> some View {
        modifier(SuibhneCardStyle())
    }
}

// MARK: - Common Components

struct SuibhneDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .suibhneGoldDim, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}

struct StatusDot: View {
    let isActive: Bool
    
    var body: some View {
        Circle()
            .fill(isActive ? Color.suibhneSuccess : Color.suibhneTextDim)
            .frame(width: 8, height: 8)
            .shadow(color: isActive ? .suibhneSuccess.opacity(0.5) : .clear, radius: 4)
    }
}

struct FeatherIcon: View {
    var body: some View {
        Text("🪶")
            .font(.system(size: 24))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HStack {
            FeatherIcon()
            Text("Suibhne")
                .font(.heading)
                .foregroundColor(.suibhneGold)
        }
        
        SuibhneDivider()
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusDot(isActive: true)
                Text("Socket Active")
                    .foregroundColor(.suibhneText)
            }
            
            HStack {
                StatusDot(isActive: false)
                Text("Contacts Pending")
                    .foregroundColor(.suibhneTextDim)
            }
        }
        .suibhneCard()
        
        Button("Request Access") {}
            .buttonStyle(SuibhneButtonStyle())
    }
    .padding()
    .background(Color.suibhneBgDeep)
}
