import Foundation

@MainActor
class FileSystemWatcher: ObservableObject {
    private nonisolated(unsafe) var eventStream: FSEventStreamRef?
    private var watchedPath: String?
    private var callback: (() -> Void)?
    private var debounceTask: Task<Void, Never>?
    private var lastTriggerTime: Date = .distantPast

    /// Start watching a folder for changes
    func watch(path: URL, onChange: @escaping () -> Void) {
        // Stop any existing watch
        stopWatching()

        watchedPath = path.path
        callback = onChange

        let pathsToWatch = [path.path] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self as AnyObject).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // Create event stream
        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (stream, contextInfo, numEvents, eventPaths, eventFlags, eventIds) in
                guard let contextInfo = contextInfo else { return }

                let watcher = Unmanaged<FileSystemWatcher>.fromOpaque(contextInfo).takeUnretainedValue()

                // Log what files are triggering changes
                let paths = UnsafeBufferPointer(start: eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self), count: numEvents)
                let flags = UnsafeBufferPointer(start: eventFlags, count: numEvents)

                var hasRealChange = false
                var relevantPaths: [String] = []

                for i in 0..<numEvents {
                    let flag = flags[i]
                    if let cPath = paths[i] as UnsafePointer<CChar>? {
                        let path = String(cString: cPath)

                        // Ignore system/hidden files and folders
                        let filename = (path as NSString).lastPathComponent
                        if filename.hasPrefix(".") ||
                           filename == "Icon\r" ||
                           filename.hasSuffix(".DS_Store") ||
                           filename.hasSuffix(".tmp") ||
                           path.contains("/.git/") ||
                           path.contains("/.Trash/") {
                            print("🔇 Ignoring system file: \(filename)")
                            continue
                        }

                        // Check if this is a real change (not just metadata)
                        if flag & UInt32(kFSEventStreamEventFlagItemCreated) != 0 ||
                           flag & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 ||
                           flag & UInt32(kFSEventStreamEventFlagItemModified) != 0 ||
                           flag & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
                            hasRealChange = true
                            relevantPaths.append(path)
                            print("📝 File change detected: \(filename)")
                        }
                    }
                }

                guard hasRealChange else {
                    print("🔇 No relevant changes detected")
                    return
                }

                print("✅ Triggering reload for \(relevantPaths.count) file(s)")
                Task { @MainActor in
                    watcher.triggerCallback()
                }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0, // Latency in seconds - increased to reduce frequency
            UInt32(kFSEventStreamCreateFlagFileEvents)
        )

        guard let stream = eventStream else {
            print("❌ Failed to create FSEventStream")
            return
        }

        // Schedule on run loop
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        // Start the stream
        if FSEventStreamStart(stream) {
            print("👁️ Started watching: \(path.path)")
        } else {
            print("❌ Failed to start FSEventStream")
            stopWatching()
        }
    }

    /// Trigger callback with debouncing to prevent rapid-fire updates
    private func triggerCallback() {
        // Cancel any pending trigger
        debounceTask?.cancel()

        // Check if we triggered recently (within 5 seconds)
        let now = Date()
        let timeSinceLastTrigger = now.timeIntervalSince(lastTriggerTime)

        if timeSinceLastTrigger < 5.0 {
            // Too soon - debounce this trigger
            debounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                guard !Task.isCancelled else { return }
                self.lastTriggerTime = Date()
                self.callback?()
            }
        } else {
            // Enough time has passed - trigger immediately
            lastTriggerTime = now
            callback?()
        }
    }

    /// Stop watching for file changes
    func stopWatching() {
        guard let stream = eventStream else { return }

        // Cancel any pending debounce
        debounceTask?.cancel()
        debounceTask = nil

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)

        if let path = watchedPath {
            print("👁️ Stopped watching: \(path)")
        }

        eventStream = nil
        watchedPath = nil
        callback = nil
    }

    deinit {
        // Can't call @MainActor-isolated methods from deinit
        // Clean up manually
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
