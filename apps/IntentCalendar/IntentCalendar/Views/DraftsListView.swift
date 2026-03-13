import SwiftUI

struct DraftsListView: View {
    @ObservedObject var draftManager: DraftManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                // Filter explicitly for .draft status
                ForEach(draftManager.activeDrafts.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { draft in
                    Button(action: {
                        draftManager.selectDraft(draft)
                        isPresented = false
                    }) {
                        VStack(alignment: .leading) {
                            Text(draft.content.isEmpty ? "Empty Draft" : draft.content)
                                .lineLimit(1)
                                .font(.headline)
                            Text(draft.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let draft = draftManager.activeDrafts.sorted(by: { $0.modifiedAt > $1.modifiedAt })[index]
                        draftManager.deleteDraft(draft)
                    }
                }
            }
            .navigationTitle("Drafts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        draftManager.createNewDraft()
                        isPresented = false
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}
