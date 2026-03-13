import SwiftUI

struct ArchiveListView: View {
    @ObservedObject var draftManager: DraftManager
    @Binding var isPresented: Bool

    private var sortedArchived: [Draft] {
        draftManager.archivedDrafts.sorted(by: { $0.modifiedAt > $1.modifiedAt })
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(sortedArchived) { draft in
                    ArchiveRowView(draft: draft, onRestore: {
                        restoreAndOpen(draft)
                    }, onCopy: {
                        UIPasteboard.general.string = draft.content
                    }, onSwipeRestore: {
                        withAnimation {
                            draftManager.restoreDraft(draft)
                        }
                    })
                }
                .onDelete(perform: deleteDrafts)
            }
            .navigationTitle("Archive")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .overlay {
                if draftManager.archivedDrafts.isEmpty {
                    emptyStateView
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack {
            Image(systemName: "archivebox")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No archived entries yet")
                .foregroundColor(.secondary)
        }
    }

    private func deleteDrafts(at offsets: IndexSet) {
        for index in offsets {
            if index < sortedArchived.count {
                draftManager.deleteDraft(sortedArchived[index])
            }
        }
    }

    private func restoreAndOpen(_ draft: Draft) {
        draftManager.restoreDraft(draft)
        draftManager.selectDraft(draft)
        isPresented = false
    }
}

// MARK: - Archive Row View

private struct ArchiveRowView: View {
    let draft: Draft
    let onRestore: () -> Void
    let onCopy: () -> Void
    let onSwipeRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(draft.content)
                .lineLimit(2)
                .font(.body)
            Text("Archived on \(draft.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onRestore)
        .contextMenu {
            Button(action: onRestore) {
                Label("Restore & Edit", systemImage: "pencil")
            }
            Button(action: onCopy) {
                Label("Copy Text", systemImage: "doc.on.doc")
            }
        }
        .swipeActions(edge: .leading) {
            Button(action: onSwipeRestore) {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(ThemeManager.obsidianPurple)
        }
    }
}
