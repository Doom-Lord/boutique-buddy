//
//  SettingsView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    @State private var isImporterPresented = false
    @State private var importError: String?

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        Form {
            // MARK: Section 1 — Business Details
            Section("Business Details") {
                if let settings {
                    TextField("Brand Name", text: Binding(
                        get: { settings.brandName },
                        set: {
                            settings.brandName = $0
                            save()
                        }
                    ))

                    logoRow(settings)

                    TextField("Address", text: Binding(
                        get: { settings.address },
                        set: {
                            settings.address = $0
                            save()
                        }
                    ), axis: .vertical)
                    .lineLimit(2...5)

                    TextField("Phone Number", text: Binding(
                        get: { settings.phoneNumber },
                        set: {
                            settings.phoneNumber = $0
                            save()
                        }
                    ))
                } else {
                    Text("Loading settings…")
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Section 2 — Receipts
            Section("Receipts") {
                if let settings {
                    TextField("Thank You Note", text: Binding(
                        get: { settings.thankYouNote },
                        set: {
                            settings.thankYouNote = $0
                            save()
                        }
                    ), axis: .vertical)
                    .lineLimit(2...4)
                    Text("Shown at the bottom of shared receipts and account statements.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Section 3 — Pricing & Categories
            // Placeholder: default markup % / Smart Price settings will live here later.
            // (Currently managed under Tools → Manage Categories / Smart Price.)
            Section("Pricing & Categories") {
                Text("Coming later — default markup and Smart Price preferences.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: Section 4 — Backup
            // Placeholder: backup folder location and auto-backup preferences will live here later.
            // (Currently managed under Tools → Backup & Restore.)
            Section("Backup") {
                Text("Coming later — backup folder and auto-backup preferences.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let importError {
                Section {
                    Text(importError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, idealWidth: 480, minHeight: 420)
        .padding()
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleLogoImport(result)
        }
    }

    @ViewBuilder
    private func logoRow(_ settings: AppSettings) -> some View {
        HStack(alignment: .center, spacing: 16) {
            logoPreview(settings.logoImageData)

            VStack(alignment: .leading, spacing: 8) {
                Button("Choose Logo…") {
                    importError = nil
                    isImporterPresented = true
                }
                if settings.logoImageData != nil {
                    Button("Remove Logo", role: .destructive) {
                        settings.logoImageData = nil
                        save()
                    }
                }
                Text("Images are resized to fit within 500×500 before saving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func logoPreview(_ data: Data?) -> some View {
        Group {
            if let image = LogoImageProcessor.nsImage(from: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "storefront")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func handleLogoImport(_ result: Result<[URL], Error>) {
        guard let settings else { return }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            guard let data = LogoImageProcessor.processedJPEGData(from: url) else {
                importError = "Could not read or resize that image. Try a PNG or JPEG."
                return
            }
            settings.logoImageData = data
            save()
            importError = nil
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func save() {
        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
