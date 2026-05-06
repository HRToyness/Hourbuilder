#!/usr/bin/env swift
// Genereert het app-icoon: 1024×1024 master PNG + complete iconset + .icns
//
// Ontwerp: dark navy rounded-square achtergrond met een 3×3 heat-map grid
// in mint groen — refereert direct aan de matrix view die het hart van de
// app is.
//
// Gebruik: ./scripts/generate-icon.swift Resources

import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: generate-icon.swift <output-dir>\n".data(using: .utf8)!)
    exit(1)
}
let outputDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

// MARK: - Tekening

let size: CGFloat = 1024

func draw() -> NSImage {
    let canvas = NSSize(width: size, height: size)
    let image = NSImage(size: canvas)
    image.lockFocus()
    defer { image.unlockFocus() }

    // 1. Achtergrond — dark navy rounded square (Apple icon radius ≈ 22.37%)
    let bg = NSColor(srgbRed: 0.110, green: 0.110, blue: 0.180, alpha: 1)
    bg.setFill()
    let bgPath = NSBezierPath(
        roundedRect: NSRect(origin: .zero, size: canvas),
        xRadius: size * 0.2237,
        yRadius: size * 0.2237
    )
    bgPath.fill()

    // 2. Subtiele radiale glow vanuit linksboven — diepte
    if let context = NSGraphicsContext.current?.cgContext {
        context.saveGState()
        let glowColors = [
            NSColor(srgbRed: 0.18, green: 0.83, blue: 0.66, alpha: 0.10).cgColor,
            NSColor(srgbRed: 0.18, green: 0.83, blue: 0.66, alpha: 0.0).cgColor,
        ] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: space, colors: glowColors, locations: [0, 1]) {
            context.addPath(bgPath.cgPath)
            context.clip()
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: size * 0.25, y: size * 0.78),
                startRadius: 0,
                endCenter: CGPoint(x: size * 0.25, y: size * 0.78),
                endRadius: size * 0.6,
                options: []
            )
        }
        context.restoreGState()
    }

    // 3. Heat-map grid: 3 rij × 3 kolom met varierende intensiteit
    let cellSize: CGFloat = size * 0.18
    let gap: CGFloat = size * 0.040
    let gridSize: CGFloat = cellSize * 3 + gap * 2
    let originX = (size - gridSize) / 2
    let originY = (size - gridSize) / 2

    // Heat patroon: lager links/onder, hoger rechts/boven (vorm van groei)
    // Waarden 0..4 → bucket intensiteiten zoals in HeatMapBucket
    let pattern: [[Int]] = [
        [3, 4, 2],   // top row
        [2, 3, 4],
        [1, 2, 3],   // bottom row
    ]

    let mintLevels: [NSColor] = [
        NSColor(srgbRed: 0.91, green: 0.96, blue: 1.00, alpha: 1.00),  // 1
        NSColor(srgbRed: 0.77, green: 0.88, blue: 0.98, alpha: 1.00),  // 2
        NSColor(srgbRed: 0.18, green: 0.83, blue: 0.66, alpha: 1.00),  // 3 — accent mint
        NSColor(srgbRed: 0.10, green: 0.62, blue: 0.50, alpha: 1.00),  // 4 — donkergroen
    ]

    for row in 0..<3 {
        for col in 0..<3 {
            // Visuele rij: bovenste rij (pattern[0]) tekent op grootste y
            let visualRow = row
            let intensity = pattern[visualRow][col]
            let cellX = originX + CGFloat(col) * (cellSize + gap)
            let cellY = originY + CGFloat(2 - visualRow) * (cellSize + gap)

            let rect = NSRect(x: cellX, y: cellY, width: cellSize, height: cellSize)
            let cellPath = NSBezierPath(roundedRect: rect, xRadius: cellSize * 0.18, yRadius: cellSize * 0.18)

            // Subtiele schaduw onder elke cel
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.setShadow(
                    offset: CGSize(width: 0, height: -2),
                    blur: 8,
                    color: NSColor.black.withAlphaComponent(0.25).cgColor
                )
                if intensity == 0 {
                    NSColor(srgbRed: 0.18, green: 0.18, blue: 0.25, alpha: 1).setFill()
                } else {
                    mintLevels[intensity - 1].setFill()
                }
                cellPath.fill()
                context.restoreGState()
            } else {
                if intensity == 0 {
                    NSColor(srgbRed: 0.18, green: 0.18, blue: 0.25, alpha: 1).setFill()
                } else {
                    mintLevels[intensity - 1].setFill()
                }
                cellPath.fill()
            }
        }
    }

    return image
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            @unknown default: break
            }
        }
        return path
    }
}

// MARK: - PNG export

func writePNG(_ image: NSImage, size: Int, to url: URL) throws {
    let target = NSImage(size: NSSize(width: size, height: size))
    target.lockFocus()
    image.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1.0
    )
    target.unlockFocus()

    guard let tiff = target.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1)
    }
    try pngData.write(to: url)
}

// MARK: - Iconset + .icns

let masterImage = draw()

let iconsetDir = outputDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in sizes {
    let url = iconsetDir.appendingPathComponent(name)
    try writePNG(masterImage, size: pixels, to: url)
}

// Master 1024 voor distributie (App Store screenshots etc.)
try writePNG(masterImage, size: 1024, to: outputDir.appendingPathComponent("AppIcon-1024.png"))

print("✓ Iconset geschreven naar \(iconsetDir.path)")

// iconutil aanroepen voor .icns
let icnsURL = outputDir.appendingPathComponent("AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try task.run()
task.waitUntilExit()
if task.terminationStatus == 0 {
    print("✓ AppIcon.icns geschreven naar \(icnsURL.path)")
} else {
    FileHandle.standardError.write("iconutil faalde met status \(task.terminationStatus)\n".data(using: .utf8)!)
    exit(Int32(task.terminationStatus))
}
