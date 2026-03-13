import SwiftUI
import UIKit

/// A UITextView wrapper that exposes cursor position for text injection.
/// Adapted from AudioRecorderPavanKumar inspiration.
struct CursorAwareTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int
    var onTextChange: (() -> Void)?
    var isEditable: Bool = true

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 100, right: 16) // Bottom padding for FAB
        textView.isScrollEnabled = true
        textView.keyboardDismissMode = .interactive
        textView.returnKeyType = .default
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.isEditable = isEditable

        // Only update text if it's actually different AND not from user typing
        // This handles external updates (like transcription results)
        let isExternalUpdate = uiView.text != text && !context.coordinator.isUserTyping

        if isExternalUpdate {

            uiView.text = text

            // Restore cursor position after external text update
            let safePosition = min(max(0, cursorPosition), text.count)
            if let newPosition = uiView.position(from: uiView.beginningOfDocument, offset: safePosition) {
                uiView.selectedTextRange = uiView.textRange(from: newPosition, to: newPosition)
            }
        }

        // Reset typing flag after view update completes
        context.coordinator.isUserTyping = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CursorAwareTextEditor
        var isUserTyping = false

        init(_ parent: CursorAwareTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            // Mark that this change came from user typing
            isUserTyping = true

            // Update bindings
            parent.text = textView.text
            if let range = textView.selectedTextRange {
                let location = textView.offset(from: textView.beginningOfDocument, to: range.start)
                parent.cursorPosition = location
            }
            parent.onTextChange?()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if let range = textView.selectedTextRange {
                let location = textView.offset(from: textView.beginningOfDocument, to: range.start)
                parent.cursorPosition = location
            }
        }
    }
}
