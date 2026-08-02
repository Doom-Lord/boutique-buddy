//
//  ManageCategoriesView.swift
//  Boutique Buddy
//

import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var showingAdd = false
    @State private var editingCategory: Category?
    @State private var reassignCategory: Category?
    @State private var reassignTargetID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(categories) { category in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.body.weight(.medium))
                        if category.hasSubTypes {
                            Text(category.subTypes.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let markup = category.defaultMarkupPercent {
                            Text("Default markup: \(Int(markup))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(category.items.filter { !$0.isArchived }.count) items")
                        .foregroundStyle(.secondary)
                    Button("Edit") { editingCategory = category }
                }
            }
            .onMove(perform: move)
            .onDelete(perform: delete)
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            CategoryEditorView(category: nil)
                .frame(minWidth: 400, minHeight: 360)
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorView(category: category)
                .frame(minWidth: 400, minHeight: 360)
        }
        .alert("Reassign Items", isPresented: Binding(
            get: { reassignCategory != nil },
            set: { if !$0 { reassignCategory = nil } }
        )) {
            if let doomed = reassignCategory {
                ForEach(categories.filter { $0.id != doomed.id }) { cat in
                    Button(cat.name) {
                        reassignAndDelete(doomed, to: cat)
                    }
                }
                Button("Cancel", role: .cancel) { reassignCategory = nil }
            }
        } message: {
            if let doomed = reassignCategory {
                Text("'\(doomed.name)' has \(doomed.items.count) item(s). Choose a category to move them to before deleting.")
            }
        }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = categories
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in ordered.enumerated() {
            category.sortOrder = index
        }
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let category = categories[index]
            if category.items.isEmpty {
                modelContext.delete(category)
                try? modelContext.save()
            } else if categories.count > 1 {
                reassignCategory = category
            } else {
                errorMessage = "Can't delete the only category while it has items."
            }
        }
    }

    private func reassignAndDelete(_ category: Category, to target: Category) {
        for item in category.items {
            item.category = target
            if let sub = item.subType, !target.subTypes.contains(sub) {
                item.subType = nil
            }
        }
        modelContext.delete(category)
        try? modelContext.save()
        reassignCategory = nil
    }
}

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    var category: Category?

    @State private var name = ""
    @State private var subTypesText = ""
    @State private var markupText = "40"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Sub-Types (comma-separated)", text: $subTypesText)
                Text("e.g. Stitched, Unstitched")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Default Markup %", text: $markupText)
            }
            .formStyle(.grouped)
            .padding()
            .navigationTitle(category == nil ? "Add Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let category {
                    name = category.name
                    subTypesText = category.subTypes.joined(separator: ", ")
                    markupText = category.defaultMarkupPercent.map { "\(Int($0))" } ?? ""
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let subs = subTypesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let markup = Double(markupText)

        if let category {
            category.name = trimmed
            category.subTypes = subs
            category.defaultMarkupPercent = markup
        } else {
            let order = (categories.map(\.sortOrder).max() ?? -1) + 1
            modelContext.insert(Category(
                name: trimmed,
                subTypes: subs,
                defaultMarkupPercent: markup,
                sortOrder: order
            ))
        }
        try? modelContext.save()
        dismiss()
    }
}
