import SwiftUI

extension Font {
    public static func appTitle(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    public static func appH1(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    public static func appH2(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    public static func appBody(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    public static func appLabel(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    public static func appMeta(_ size: CGFloat = 10.5) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    public static func appNumber(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .default).monospacedDigit()
    }

    public static func appNumberSmall(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .default).monospacedDigit()
    }

    public static func appMono(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}
