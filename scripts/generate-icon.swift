#!/usr/bin/swift

// Generates AppIcon.icns for Mac Voice using app.png

import AppKit
import Foundation

let sizes: [(String, Int)] = [
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

func createIconset(from sourceImage: NSImage) {
    let iconsetDir = "/tmp/AppIcon.iconset"
    try? FileManager.default.removeItem(atPath: iconsetDir)
    try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

    for (name, px) in sizes {
        let size = NSSize(width: px, height: px)
        let img = NSImage(size: size)
        
        img.lockFocus()
        // Draw the source image respecting aspect ratio
        sourceImage.draw(in: NSRect(origin: .zero, size: size),
                         from: NSRect(origin: .zero, size: sourceImage.size),
                         operation: .copy,
                         fraction: 1.0)
        img.unlockFocus()
        
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            print("Failed to create \(name)")
            continue
        }
        let path = "\(iconsetDir)/\(name)"
        try! png.write(to: URL(fileURLWithPath: path))
        print("Created \(name) (\(px)x\(px))")
    }

    let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/AppIcon.icns"
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    proc.arguments = ["--convert", "icns", "--output", outputPath, iconsetDir]
    try! proc.run()
    proc.waitUntilExit()

    if proc.terminationStatus == 0 {
        print("✅ Icon created: \(outputPath)")
    } else {
        print("❌ iconutil failed")
        exit(1)
    }
}

// Locate app.png relative to this script
let scriptURL = URL(fileURLWithPath: #file)
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let sourceImagePath = projectRoot.appendingPathComponent("app.png").path

guard let sourceImage = NSImage(contentsOfFile: sourceImagePath) else {
    print("❌ Could not load app.png at \(sourceImagePath)")
    exit(1)
}

createIconset(from: sourceImage)
