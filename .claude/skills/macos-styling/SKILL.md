---
name: macos-styling
description: Styling conventions and reusable components for the macOS UI. Read before any UI work, color choices, typography decisions, or building reusable styled components. Defines the color/font abstraction layer and the styled SwiftUI components used across the app. Concrete colors and fonts are placeholders meant to be replaced with the project's chosen palette.
---

# macOS Styling

Native macOS UI conventions. Styling lives in `Styling/` folder. **Never inline hex values or font names in feature code** — always go through the `AppColor` and `AppFont` extensions. This makes a future restyle (or per-deployment branding) a one-file change.

## Color palette

The placeholder values below are sensible neutral defaults. Replace with the project's chosen palette once decided. The names are stable; only the hex values change.

```swift
// Styling/AppColor.swift
import SwiftUI

extension Color {
    /// Primary surface — covers, key headers, dark UI surfaces.
    static let appPrimary = Color(hex: 0x1A1A2E)
    /// Accent — CTAs, key metrics, focus rings. NOT a background color.
    static let appAccent = Color(hex: 0x2DD4A8)
    /// Accent variant for text on light backgrounds (better contrast than appAccent).
    static let appAccentDark = Color(hex: 0x0D9373)
    /// Main app background (light mode).
    static let appBackground = Color(hex: 0xF5F5F2)
    /// Body text on light surfaces.
    static let appTextPrimary = Color(hex: 0x1A1A2E)
    /// Subtle text, labels, secondary metadata.
    static let appTextSecondary = Color(hex: 0x6B7B8F)
    /// Subtle borders and dividers.
    static let appBorder = Color(hex: 0xE0E0DC)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
```

### Usage rules

- **Primary**: covers, headers, key headings on light bg, sidebar
- **Accent**: CTAs, key metrics, hover states, focus rings — sparingly
- **Accent dark**: accent-colored text on light backgrounds (accessibility)
- **Background**: main window background on content panes
- **Text secondary**: timestamps, labels, chart axis labels
- **Never** put accent color as fill for large surfaces. It's an accent, not a backdrop.

## Typography

Use system fonts as default. Swap to custom fonts later if desired without touching feature code.

```swift
// Styling/AppFont.swift
import SwiftUI

extension Font {
    static func appTitle(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }
    static func appH1(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func appH2(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func appBody(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func appLabel(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}
```

### Replacing with custom fonts

When the project picks a font (or per-deployment branding requires one):

1. Drop `.ttf` / `.otf` files in `Resources/Fonts/`
2. Add to `Info.plist`:
   ```xml
   <key>ATSApplicationFontsPath</key>
   <string>Fonts/</string>
   ```
3. Change `.system(...)` to `.custom("PostScriptName", size: size)` in the extensions above. Feature code doesn't change.
4. Verify PostScript names with `Font.familyNames` once on first run — silent fallback to system if names are wrong.

## Reusable components

Build these in `Styling/Components/` and use them everywhere — don't restyle inline.

### AppCard

```swift
struct AppCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(Color.white)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
    }
}
```

### AppSectionHeader

```swift
struct AppSectionHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appH1())
                .foregroundStyle(Color.appPrimary)
            Rectangle()
                .fill(Color.appAccent)
                .frame(height: 2)
                .frame(maxWidth: 60, alignment: .leading)
        }
    }
}
```

### AppPrimaryButton

```swift
struct AppPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appLabel(13))
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isDisabled ? Color.appTextSecondary : Color.appPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
```

### AppStatusBadge

For status pills (project status, activity status):

```swift
struct AppStatusBadge: View {
    let label: String
    let tone: Tone

    enum Tone { case neutral, accent, warning, success }

    var body: some View {
        Text(label)
            .font(.appLabel(10))
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
    }

    private var background: Color {
        switch tone {
        case .neutral: return .appTextSecondary.opacity(0.15)
        case .accent:  return .appAccent.opacity(0.18)
        case .warning: return .orange.opacity(0.18)
        case .success: return .appAccentDark.opacity(0.18)
        }
    }
    private var foreground: Color {
        switch tone {
        case .neutral: return .appTextSecondary
        case .accent:  return .appAccentDark
        case .warning: return .orange
        case .success: return .appAccentDark
        }
    }
}
```

## Window chrome and layout

- App background: `.appBackground` for content panes, white for cards/sheets
- Sidebar (NavigationSplitView): primary background with white text
- Toolbar: white with subtle bottom border in `.appBorder`
- Default padding scale: 4, 8, 12, 16, 24, 32

## Matrix view styling

The matrix view is the heart of the app. Specific rules:

- Header row: primary bg, white semibold text, 32pt high
- Header column: same, sticky on horizontal scroll
- Cell default: white bg, body text
- Alternating row tint: `.appBackground` at 50%
- Cell with confirmed hours: white bg, primary text
- Cell with AI-suggested hours: `.appAccent` at 15% bg, accent-dark border (1pt)
- Cell with imported-but-unconfirmed: `.appTextSecondary` at 10% bg, dashed border
- Selected cell: `.appAccent` at 25% bg, accent-dark border (1.5pt)
- Totals row: primary bg, white text, slight underline above

## Things to never do

- Inline hex values in feature code
- Use system blue/red/etc. for accents — always app palette
- Use accent color as a large fill — accent only
- Stack 3+ different colored elements in one card
- Use SF Symbols colored arbitrarily — keep them mono in primary or secondary text color
- Animate brand colors transitioning to non-brand colors

## Quick reference

```
Primary:        Color.appPrimary       
Accent:         Color.appAccent        
Accent dark:    Color.appAccentDark    
Background:     Color.appBackground    
Text primary:   Color.appTextPrimary   
Text secondary: Color.appTextSecondary 
Border:         Color.appBorder        

Title:          Font.appTitle()        
H1:             Font.appH1()           
H2:             Font.appH2()           
Body:           Font.appBody()         
Label:          Font.appLabel()        
```
