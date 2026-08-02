//
//  ImageSharing.swift
//  Boutique Buddy
//

import AppKit
import SwiftUI

enum ImageSharing {
    /// Renders a SwiftUI view at its intrinsic height. Width is proposed; height grows with content.
    @MainActor
    static func render<V: View>(_ view: V, width: CGFloat = 380) -> NSImage? {
        let content = view
            .frame(width: width)
            .fixedSize(horizontal: true, vertical: true)

        let renderer = ImageRenderer(content: content)
        // Crisp on phone screens when pasted into WhatsApp / Messages.
        let screenScale = NSScreen.main?.backingScaleFactor ?? 3
        renderer.scale = max(screenScale, 3)

        return renderer.nsImage
    }

    static func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    static func presentShareSheet(_ image: NSImage, from view: NSView) {
        let picker = NSSharingServicePicker(items: [image])
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
}
