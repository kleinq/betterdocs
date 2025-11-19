import SwiftUI
import UniformTypeIdentifiers

/// Drop delegate for handling file drops onto folders
struct FolderDropDelegate: DropDelegate {
    let targetFolder: Folder
    let onFileMoved: (URL, Folder) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        // Accept file URLs
        return info.hasItemsConforming(to: [.fileURL])
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.fileURL]).first else {
            return false
        }

        // Load the file URL asynchronously
        itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
            if let error = error {
                DispatchQueue.main.async {
                    logError("Drop failed: \(error.localizedDescription)")
                }
                return
            }

            guard let data = urlData as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                DispatchQueue.main.async {
                    logError("Failed to parse dropped URL")
                }
                return
            }

            // Call the completion handler on main thread
            DispatchQueue.main.async {
                onFileMoved(url, targetFolder)
            }
        }

        return true
    }

    func dropEntered(info: DropInfo) {
        // Optional: Add visual feedback when drag enters
    }

    func dropExited(info: DropInfo) {
        // Optional: Remove visual feedback when drag exits
    }
}

/// Drop delegate for handling file drops from Finder
struct FileDropDelegate: DropDelegate {
    let targetFolder: Folder
    let onFileDropped: (URL, Folder) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.fileURL])
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])

        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                if let error = error {
                    DispatchQueue.main.async {
                        logError("Drop failed: \(error.localizedDescription)")
                    }
                    return
                }

                guard let data = urlData as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    DispatchQueue.main.async {
                        logError("Failed to parse dropped URL")
                    }
                    return
                }

                DispatchQueue.main.async {
                    onFileDropped(url, targetFolder)
                }
            }
        }

        return true
    }
}

/// Transferable wrapper for file dragging
struct DraggableFile: Transferable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .fileURL) { file in
            SentTransferredFile(file.fileURL)
        } importing: { received in
            DraggableFile(fileURL: received.file)
        }
    }
}
