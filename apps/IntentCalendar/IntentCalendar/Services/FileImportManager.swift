import SwiftUI
import UniformTypeIdentifiers
import os

#if !canImport(UniformTypeIdentifiers) // Fallback if UTType isn't available at all
#else
import UniformTypeIdentifiers
#endif

// Compatibility shim for UTType.markdown on older SDKs
extension UTType {
    /// Provides a Markdown UTType when running on SDKs that don't expose `UTType.markdown`.
    static var markdownCompat: UTType {
        if let type = UTType(filenameExtension: "md") {
            return type
        }
        // Public UTI for Markdown; used as a fallback if needed
        return UTType(importedAs: "net.daringfireball.markdown")
    }

    /// Unified accessor for Markdown UTType across SDK versions without referencing UTType.markdown directly
    static var markdownType: UTType {
        // Prefer the system-resolved type for the .md extension when available
        if let extType = UTType(filenameExtension: "md") {
            return extType
        }
        // Fallback to a known imported UTI string
        return UTType(importedAs: "net.daringfireball.markdown")
    }
}

class FileImportManager: ObservableObject {
    @Published var isImporterPresented = false
    @Published var selectedFileURL: URL?
    @Published var error: String?

    // Allowed types: Audio + Text
    let allowedContentTypes: [UTType] = {
        return [.audio, .plainText, .markdownType]
    }()

    func startImport() {
        Logger.fileImport.info("Starting file import flow")
        isImporterPresented = true
    }

    func handleImport(result: Result<[URL], Error>, completion: @escaping (Result<URL, Error>) -> Void) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Logger.fileImport.info("File selected: \(url.path)")

            // Security scoped resource access handling
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }

                // We must copy the file to a temp location to persist access or process it safely
                // because access is lost once this scope ends.
                do {
                    let tempDir = FileManager.default.temporaryDirectory
                    let dstURL = tempDir.appendingPathComponent(url.lastPathComponent)

                    if FileManager.default.fileExists(atPath: dstURL.path) {
                        try FileManager.default.removeItem(at: dstURL)
                    }
                    try FileManager.default.copyItem(at: url, to: dstURL)
                    Logger.fileImport.debug("Copied file to temp: \(dstURL.path)")
                    completion(.success(dstURL))
                } catch {
                    Logger.fileImport.error("Failed to copy file: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            } else {
                // If it fails (e.g. from app document picker in some contexts), try using directly
                Logger.fileImport.info("Using file directly (no security scope needed/available)")
                completion(.success(url))
            }

        case .failure(let error):
            Logger.fileImport.error("Import failed: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
}
