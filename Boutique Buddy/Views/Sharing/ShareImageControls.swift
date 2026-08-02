//
//  ShareImageControls.swift
//  Boutique Buddy
//

import AppKit
import SwiftUI

/// Copy + Share buttons for a rendered SwiftUI share card.
struct ShareImageControls<Card: View>: View {
    let helpCopy: String
    let helpShare: String
    let compact: Bool
    @ViewBuilder let card: () -> Card
    var onCopied: (() -> Void)?

    @State private var shareAnchor = ShareAnchorView()

    var body: some View {
        HStack(spacing: compact ? 4 : 8) {
            Button {
                copyImage()
            } label: {
                if compact {
                    Image(systemName: "doc.on.clipboard")
                } else {
                    Label("Copy", systemImage: "doc.on.clipboard")
                }
            }
            .help(helpCopy)
            .buttonStyle(.borderless)

            ShareTriggerButton(anchor: shareAnchor, title: compact ? nil : "Share…") {
                renderImage()
            }
            .help(helpShare)
        }
        .background(
            ShareAnchorRepresentable(anchor: shareAnchor)
                .frame(width: 1, height: 1)
                .opacity(0)
        )
    }

    @MainActor
    private func renderImage() -> NSImage? {
        ImageSharing.render(card())
    }

    @MainActor
    private func copyImage() {
        guard let image = renderImage() else { return }
        ImageSharing.copyToClipboard(image)
        onCopied?()
    }
}

/// Invisible NSView used as the anchor for NSSharingServicePicker.
final class ShareAnchorView: NSView {}

private struct ShareAnchorRepresentable: NSViewRepresentable {
    let anchor: ShareAnchorView

    func makeNSView(context: Context) -> ShareAnchorView { anchor }
    func updateNSView(_ nsView: ShareAnchorView, context: Context) {}
}

private struct ShareTriggerButton: View {
    let anchor: ShareAnchorView
    let title: String?
    let imageProvider: () -> NSImage?

    var body: some View {
        Button {
            guard let image = imageProvider() else { return }
            // Present from the anchor; fall back to the key window content view.
            let host: NSView = anchor.window != nil ? anchor : (NSApp.keyWindow?.contentView ?? anchor)
            ImageSharing.presentShareSheet(image, from: host)
        } label: {
            if let title {
                Label(title, systemImage: "square.and.arrow.up")
            } else {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .buttonStyle(.borderless)
    }
}

/// Bottom toast used after copying a share image.
struct CopyToastOverlay: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: message)
    }
}

extension View {
    func copyToast(_ message: Binding<String?>) -> some View {
        modifier(CopyToastOverlay(message: message))
    }

}
