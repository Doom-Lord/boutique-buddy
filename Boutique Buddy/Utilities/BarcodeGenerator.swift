//
//  BarcodeGenerator.swift
//  Boutique Buddy
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum BarcodeGenerator {
    static func code128Image(from string: String, height: CGFloat = 40) -> NSImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)
        filter.quietSpace = 7

        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 3, y: 3))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        let size = NSSize(width: CGFloat(cgImage.width), height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.draw(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
}
