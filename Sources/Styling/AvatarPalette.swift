import SwiftUI

/// Deterministische bg/fg-paren voor avatar initialen. `Swift.hashValue` is
/// per-launch random, dus we gebruiken een stabiele eigen hash.
public enum AvatarPalette {
    public struct Pair: Sendable, Hashable {
        public let background: Color
        public let foreground: Color
    }

    public static let palette: [Pair] = [
        Pair(background: Color(hex: 0xE8DCEF), foreground: Color(hex: 0x5C2A82)), // paars
        Pair(background: Color(hex: 0xFCD9C1), foreground: Color(hex: 0x8A4012)), // oranje
        Pair(background: Color(hex: 0xD4F0E1), foreground: Color(hex: 0x0A5C2E)), // groen
        Pair(background: Color(hex: 0xD9E5FA), foreground: Color(hex: 0x1B3A7A)), // blauw
        Pair(background: Color(hex: 0xF5E0E0), foreground: Color(hex: 0x7A1F1F)), // rood
        Pair(background: Color(hex: 0xEAEACE), foreground: Color(hex: 0x5A5215)), // olijf
    ]

    public static func pair(for name: String) -> Pair {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return palette[0] }
        var hash: UInt64 = 0
        for byte in normalized.utf8 {
            hash = hash &* 31 &+ UInt64(byte)
        }
        let index = Int(hash % UInt64(palette.count))
        return palette[index]
    }

    public static func initials(for name: String) -> String {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        let combined = letters.joined()
        return combined.isEmpty ? "?" : combined.uppercased()
    }
}
