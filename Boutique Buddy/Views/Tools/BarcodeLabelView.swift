//
//  BarcodeLabelView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct BarcodeLabelView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<InventoryItem> { !$0.isArchived }, sort: \InventoryItem.name)
    private var items: [InventoryItem]
    @Query private var settingsList: [AppSettings]

    @State private var selectedIDs: Set<UUID> = []
    @State private var labelSize: LabelSize = .mm50x25
    @State private var searchText = ""

    private var settings: AppSettings? { settingsList.first }

    private var filteredItems: [InventoryItem] {
        guard !searchText.isEmpty else { return items }
        let q = searchText.lowercased()
        return items.filter {
            $0.name.lowercased().contains(q) || $0.sku.lowercased().contains(q)
        }
    }

    private var selectedItems: [InventoryItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Select Items")
                    .font(.headline)
                    .padding(12)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 12)
                List(filteredItems, selection: $selectedIDs) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text(item.sku)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .tag(item.id)
                }
            }
            .frame(minWidth: 240)

            VStack(alignment: .leading, spacing: 16) {
                Form {
                    Picker("Label Size", selection: $labelSize) {
                        ForEach(LabelSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .onChange(of: labelSize) { _, newValue in
                        settings?.labelSize = newValue
                        try? modelContext.save()
                    }
                    LabeledContent("Selected", value: "\(selectedItems.count) item(s)")
                }
                .formStyle(.grouped)
                .frame(maxHeight: 120)

                Text("Preview")
                    .font(.headline)

                ScrollView {
                    LazyVGrid(columns: Array(
                        repeating: GridItem(.flexible(), spacing: 8),
                        count: labelSize.columns
                    ), spacing: 8) {
                        ForEach(selectedItems) { item in
                            LabelPreview(item: item, size: labelSize)
                        }
                    }
                    .padding(8)
                }
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button("Print…") { printLabels() }
                        .disabled(selectedItems.isEmpty)
                        .buttonStyle(.borderedProminent)
                    Button("Export PDF…") { exportPDF() }
                        .disabled(selectedItems.isEmpty)
                    Spacer()
                }
            }
            .padding(16)
            .frame(minWidth: 360)
        }
        .navigationTitle("Barcode Labels")
        .onAppear {
            labelSize = settings?.labelSize ?? .mm50x25
        }
    }

    private func printLabels() {
        let view = LabelPrintView(items: selectedItems, labelSize: labelSize)
        let hosting = NSHostingView(rootView: view)
        let size = printPageSize(for: selectedItems.count)
        hosting.frame = CGRect(origin: .zero, size: size)

        let printInfo = NSPrintInfo.shared
        printInfo.leftMargin = 18
        printInfo.rightMargin = 18
        printInfo.topMargin = 18
        printInfo.bottomMargin = 18

        let operation = NSPrintOperation(view: hosting, printInfo: printInfo)
        operation.showsPrintPanel = true
        operation.run()
    }

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "BoutiqueBuddy_Labels.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let view = LabelPrintView(items: selectedItems, labelSize: labelSize)
        let hosting = NSHostingView(rootView: view)
        let size = printPageSize(for: selectedItems.count)
        hosting.frame = CGRect(origin: .zero, size: size)

        let printInfo = NSPrintInfo.shared
        let operation = NSPrintOperation(view: hosting, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        let pdfData = hosting.dataWithPDF(inside: hosting.bounds)
        try? pdfData.write(to: url)
    }

    private func printPageSize(for count: Int) -> CGSize {
        let label = labelSize.sizeInPoints
        let cols = CGFloat(labelSize.columns)
        let rows = ceil(CGFloat(max(count, 1)) / cols)
        return CGSize(
            width: label.width * cols + 40,
            height: max(label.height * rows + 40, 200)
        )
    }
}

private struct LabelPreview: View {
    let item: InventoryItem
    let size: LabelSize

    var body: some View {
        VStack(spacing: 4) {
            Text(item.name)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(item.mrp.currencyString)
                .font(.system(size: 11, weight: .bold))
            if let image = BarcodeGenerator.code128Image(from: item.sku, height: 28) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
            }
            Text(item.sku)
                .font(.system(size: 7).monospaced())
        }
        .padding(6)
        .frame(width: size.sizeInPoints.width, height: size.sizeInPoints.height)
        .background(Color.white)
        .overlay(Rectangle().stroke(Color.gray.opacity(0.4), lineWidth: 0.5))
        .environment(\.colorScheme, .light)
    }
}

private struct LabelPrintView: View {
    let items: [InventoryItem]
    let labelSize: LabelSize

    var body: some View {
        let columns = Array(
            repeating: GridItem(.fixed(labelSize.sizeInPoints.width), spacing: 4),
            count: labelSize.columns
        )
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(items) { item in
                LabelPreview(item: item, size: labelSize)
            }
        }
        .padding(12)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}
