import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Log immediately to confirm we're running
        NSLog("[Share] viewDidLoad called")

        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        activityIndicator.startAnimating()

        handleSharedContent()
    }

    private func handleSharedContent() {
        NSLog("[Share] handleSharedContent called")

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = extensionItem.attachments?.first else {
            NSLog("[Share] No attachments found")
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        // Debug: Print all registered type identifiers
        NSLog("[Share] Attachment types: %@", attachment.registeredTypeIdentifiers)

        // Priority 1: Audio files - try multiple identifiers
        let audioTypes = [
            "public.audio",
            "com.apple.m4a-audio",
            kUTTypeAudio as String,
            kUTTypeMPEG4Audio as String,
            kUTTypeMP3 as String
        ]

        for audioType in audioTypes {
            if attachment.hasItemConformingToTypeIdentifier(audioType) {
                NSLog("[Share] Detected audio type: %@", audioType)
                attachment.loadItem(forTypeIdentifier: audioType, options: nil) { [weak self] (data, error) in
                    if let error = error {
                        NSLog("[Share] Error loading audio: %@", error.localizedDescription)
                    }
                    self?.handleAudioItem(data: data, error: error)
                }
                return
            }
        }

        // Priority 2: File URL (for files from Files app - check if it's audio)
        if attachment.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
            NSLog("[Share] Detected file URL")
            attachment.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { [weak self] (data, error) in
                self?.handleFileItem(data: data, error: error)
            }
            return
        }

        // Priority 3: Plain text
        if attachment.hasItemConformingToTypeIdentifier(kUTTypePlainText as String) {
            NSLog("[Share] Detected plain text")
            attachment.loadItem(forTypeIdentifier: kUTTypePlainText as String, options: nil) { [weak self] (data, error) in
                self?.handleTextItem(data: data, error: error)
            }
            return
        }

        // Priority 4: Generic text type
        if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            NSLog("[Share] Detected UTType.text")
            attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (data, error) in
                self?.handleTextItem(data: data, error: error)
            }
            return
        }

        // Priority 5: URL type
        if attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
            NSLog("[Share] Detected URL")
            attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { [weak self] (data, error) in
                self?.handleTextItem(data: data, error: error)
            }
            return
        }

        NSLog("[Share] No matching type found")
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - Audio Handling

    private func handleAudioItem(data: NSSecureCoding?, error: Error?) {
        DispatchQueue.main.async {
            NSLog("[Share] handleAudioItem called")

            guard let url = data as? URL else {
                NSLog("[Share] Audio data is not a URL, type: %@", String(describing: type(of: data)))
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }

            NSLog("[Share] Audio URL: %@", url.path)

            // Start accessing security-scoped resource (important for files from other apps)
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID) else {
                NSLog("[Share] Failed to get shared container URL")
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }

            let filename = "shared_audio_\(UUID().uuidString).\(url.pathExtension.isEmpty ? "m4a" : url.pathExtension)"
            let destinationURL = sharedContainerURL.appendingPathComponent(filename)

            NSLog("[Share] Copying to: %@", destinationURL.path)

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                // Use FileManager to copy (handles security scoped resources)
                try FileManager.default.copyItem(at: url, to: destinationURL)
                NSLog("[Share] File copied successfully")

                let urlString = "\(AppConstants.urlScheme)://transcribe-audio?file=\(filename)"
                NSLog("[Share] Opening URL: %@", urlString)

                if let appURL = URL(string: urlString) {
                    self.openMainApp(url: appURL)
                }
            } catch {
                NSLog("[Share] Error copying file: %@", error.localizedDescription)
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }

    // MARK: - Text Handling

    private func handleTextItem(data: NSSecureCoding?, error: Error?) {
        DispatchQueue.main.async {
            var text: String? = nil

            if let string = data as? String {
                text = string
            } else if let url = data as? URL {
                if url.isFileURL {
                    text = try? String(contentsOf: url, encoding: .utf8)
                } else {
                    text = url.absoluteString
                }
            } else if let urlData = data as? Data, let urlString = String(data: urlData, encoding: .utf8) {
                text = urlString
            }

            self.sendTextToApp(text)
        }
    }

    // MARK: - File Handling

    private func handleFileItem(data: NSSecureCoding?, error: Error?) {
        DispatchQueue.main.async {
            guard let url = data as? URL else {
                NSLog("[Share] File data is not a URL")
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }

            NSLog("[Share] File URL: %@, extension: %@", url.path, url.pathExtension)

            let audioExtensions = ["m4a", "mp3", "wav", "aac", "caf", "aiff", "mp4", "m4b", "m4p", "mpeg", "mpga"]
            if audioExtensions.contains(url.pathExtension.lowercased()) {
                NSLog("[Share] Treating as audio file")
                self.handleAudioItem(data: url as NSURL, error: nil)
                return
            }

            // Start accessing security-scoped resource for text files too
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let text = try? String(contentsOf: url, encoding: .utf8)
            self.sendTextToApp(text)
        }
    }

    // MARK: - Helpers

    private func sendTextToApp(_ text: String?) {
        guard let finalText = text, !finalText.isEmpty else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        if let defaults = UserDefaults(suiteName: AppConstants.appGroupID) {
            defaults.set(finalText, forKey: AppConstants.UserDefaultsKey.sharedContent)
            defaults.synchronize()
        }

        var urlString = "\(AppConstants.urlScheme)://open-shared"
        if let encoded = finalText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "?content=\(encoded)"
        }

        if let url = URL(string: urlString) {
            self.openMainApp(url: url)
        }
    }

    private func openMainApp(url: URL) {
        NSLog("[Share] openMainApp called with: %@", url.absoluteString)

        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }
            responder = responder?.next
        }

        self.extensionContext?.open(url, completionHandler: { [weak self] success in
            NSLog("[Share] extensionContext.open result: %d", success)
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })
    }
}
