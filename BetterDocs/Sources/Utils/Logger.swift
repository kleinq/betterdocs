import Foundation
import os.log

/// Centralized logging for BetterDocs
/// Logs are written to ~/Library/Logs/BetterDocs/
final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger()

    private let logDirectory: URL
    private let logFileURL: URL
    private let fileHandle: FileHandle?
    private let osLog = OSLog(subsystem: "com.betterdocs.app", category: "general")

    private init() {
        // Set up log directory
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        logDirectory = homeDirectory.appendingPathComponent("Library/Logs/BetterDocs")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        // Create log file with date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        logFileURL = logDirectory.appendingPathComponent("BetterDocs-\(dateString).log")

        // Create or open log file
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()

        // Log startup
        log("📱 BetterDocs started - Log file: \(logFileURL.path)", level: .info)
    }

    deinit {
        try? fileHandle?.close()
    }

    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }

    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(message)\n"

        // Write to file
        if let data = logMessage.data(using: .utf8) {
            fileHandle?.write(data)
        }

        // Also log to system console in debug builds
        #if DEBUG
        print(logMessage, terminator: "")
        #else
        // In release, use os_log
        os_log("%{public}s", log: osLog, type: osLogType(for: level), message)
        #endif
    }

    private func osLogType(for level: LogLevel) -> OSLogType {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }

    // Convenience methods
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
}

// Global convenience functions
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.debug(message, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.info(message, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.warning(message, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.error(message, file: file, function: function, line: line)
}
