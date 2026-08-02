//
//  ReceiptChrome.swift
//  Boutique Buddy
//

import SwiftUI

/// Dashed gold “stitch” divider between receipt sections.
struct StitchDivider: View {
    var body: some View {
        StitchLine()
            .stroke(Color.receiptGold, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }
}

private struct StitchLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Stamp-style scalloped bottom edge. Uses `rect` so it fits any intrinsic card size.
struct ScallopedReceiptShape: Shape {
    var scallopRadius: CGFloat = 5.5

    func path(in rect: CGRect) -> Path {
        let r = scallopRadius
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))

        var x = rect.maxX
        let step = r * 2
        while x - step >= rect.minX - 0.5 {
            let center = CGPoint(x: x - r, y: rect.maxY - r)
            path.addArc(
                center: center,
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: false
            )
            x -= step
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Shared paper wrapper: warm stock, intrinsic height, scalloped bottom.
struct ReceiptPaperCard<Content: View>: View {
    let width: CGFloat
    @ViewBuilder let content: () -> Content

    private let scallopRadius: CGFloat = 5.5

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 18 + scallopRadius)
        .frame(width: width)
        .fixedSize(horizontal: true, vertical: true)
        .background(Color.receiptPaper)
        .foregroundStyle(Color.receiptInk)
        .clipShape(ScallopedReceiptShape(scallopRadius: scallopRadius))
        .environment(\.colorScheme, .light)
    }
}

/// Brand block shared by receipt and account statement.
struct ShareDocumentHeader: View {
    let brand: BrandIdentity
    let documentTitle: String
    let date: Date

    private var contactLine: String {
        [brand.address, brand.phoneNumber]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 6) {
            if let logo = LogoImageProcessor.nsImage(from: brand.logoImageData) {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 40, maxHeight: 40)
            }

            Text(brand.brandName)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Color.receiptMaroon)
                .multilineTextAlignment(.center)

            if !contactLine.isEmpty {
                Text(contactLine)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(Color.receiptMuted)
                    .multilineTextAlignment(.center)
            }

            Text(documentTitle.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(1.5)
                .foregroundStyle(Color.receiptGold)
                .padding(.top, 6)

            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(Color.receiptMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ReceiptKeyedRow: View {
    let label: String
    let value: String
    var labelWeight: Font.Weight = .regular
    var valueWeight: Font.Weight = .regular
    var emphasizeDue: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 15, weight: labelWeight, design: .default))
                .foregroundStyle(emphasizeDue ? Color.receiptDue : Color.receiptInk)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 15, weight: valueWeight, design: .default).monospacedDigit())
                .foregroundStyle(emphasizeDue ? Color.receiptDue : Color.receiptInk)
                .multilineTextAlignment(.trailing)
        }
    }
}
