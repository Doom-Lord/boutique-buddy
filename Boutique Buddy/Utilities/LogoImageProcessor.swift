//
//  LogoImageProcessor.swift
//  Boutique Buddy
//

import AppKit
import Foundation

enum LogoImageProcessor {
    /// Loads an image from disk, downscales to fit within `maxDimension`, returns JPEG data.
    static func processedJPEGData(from url: URL, maxDimension: CGFloat = 500, compression: Double = 0.85) -> Data? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return jpegData(from: image, maxDimension: maxDimension, compression: compression)
    }

    static func jpegData(from image: NSImage, maxDimension: CGFloat = 500, compression: Double = 0.85) -> Data? {
        let resized = resized(image, maxDimension: maxDimension)
        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .jpeg, properties: [.compressionFactor: compression]) else {
            return nil
        }
        return data
    }

    static func nsImage(from data: Data?) -> NSImage? {
        guard let data else { return nil }
        return NSImage(data: data)
    }

    private static func resized(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = NSSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let output = NSImage(size: newSize)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        output.unlockFocus()
        return output
    }
}
