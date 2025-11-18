import Foundation

@MainActor
class FileSystemWatcher: ObservableObject {
    private nonisolated(unsafe) var eventStream: FSEventStreamRef?
    private var watchedPath: String?
    private var callback: (() -> Void)?

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

                // Only trigger if there are actual changes
                let flags = UnsafeBufferPointer(start: eventFlags, count: numEvents)
                for flag in flags {
                    // Check if this is a real change (not just metadata)
                    if flag & UInt32(kFSEventStreamEventFlagItemCreated) != 0 ||
                       flag & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 ||
                       flag & UInt32(kFSEventStreamEventFlagItemModified) != 0 ||
                       flag & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
                        Task { @MainActor in
                            watcher.callback?()
                        }
                        break
                    }
                }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // Latency in seconds (debounce file changes)
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
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

    /// Stop watching for file changes
    func stopWatching() {
        guard let stream = eventStream else { return }

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
