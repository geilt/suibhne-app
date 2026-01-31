// Logger.swift
// Structured logging for Suibhne

import Foundation
import os.log

public final class SuibhneLogger {
    public static let shared = SuibhneLogger()
    
    private let osLog = OSLog(subsystem: "app.suibhne.app", category: "general")
    private let fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "app.suibhne.logger", qos: .utility)
    private let dateFormatter: ISO8601DateFormatter
    
    public var logLevel: LogLevel = .info
    
    public enum LogLevel: Int, Comparable {
        case debug = 0
        case info = 1
        case warn = 2
        case error = 3
        
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "📝"
            case .warn: return "⚠️"
            case .error: return "❌"
            }
        }
        
        var name: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warn: return "WARN"
            case .error: return "ERROR"
            }
        }
    }
    
    private init() {
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Ensure log directory exists
        SuibhnePaths.ensureDirectories()
        
        // Open log file for today
        let today = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        let logFile = "\(SuibhnePaths.logPath)/\(today).log"
        
        FileManager.default.createFile(atPath: logFile, contents: nil)
        fileHandle = FileHandle(forWritingAtPath: logFile)
        fileHandle?.seekToEndOfFile()
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    // MARK: - Public API
    
    public func debug(_ message: String, context: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, context: context, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, context: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, context: context, file: file, function: function, line: line)
    }
    
    public func warn(_ message: String, error: Error? = nil, context: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var ctx = context ?? [:]
        if let error = error {
            ctx["error"] = String(describing: error)
        }
        log(.warn, message, context: ctx, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, error: Error? = nil, context: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var ctx = context ?? [:]
        if let error = error {
            ctx["error"] = String(describing: error)
        }
        log(.error, message, context: ctx, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    
    private func log(_ level: LogLevel, _ message: String, context: [String: Any]?, file: String, function: String, line: Int) {
        guard level >= logLevel else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let location = "\(fileName):\(line)"
        
        // Build log entry
        var entry: [String: Any] = [
            "timestamp": timestamp,
            "level": level.name,
            "message": message,
            "location": location
        ]
        
        if let context = context, !context.isEmpty {
            entry["context"] = context
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Write to file as JSON
            if let data = try? JSONSerialization.data(withJSONObject: entry),
               let jsonString = String(data: data, encoding: .utf8) {
                self.fileHandle?.write((jsonString + "\n").data(using: .utf8)!)
            }
            
            // Also log to os_log for Console.app
            let consoleMessage = "\(level.emoji) [\(level.name)] \(message)"
            switch level {
            case .debug:
                os_log(.debug, log: self.osLog, "%{public}@", consoleMessage)
            case .info:
                os_log(.info, log: self.osLog, "%{public}@", consoleMessage)
            case .warn:
                os_log(.default, log: self.osLog, "%{public}@", consoleMessage)
            case .error:
                os_log(.error, log: self.osLog, "%{public}@", consoleMessage)
            }
            
            #if DEBUG
            print(consoleMessage)
            #endif
        }
    }
    
    // MARK: - Log Reading (for UI/CLI)
    
    public func recentLogs(limit: Int = 100) -> [String] {
        guard let logFile = currentLogFile(),
              let content = try? String(contentsOfFile: logFile, encoding: .utf8) else {
            return []
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return Array(lines.suffix(limit))
    }
    
    private func currentLogFile() -> String? {
        let today = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        let path = "\(SuibhnePaths.logPath)/\(today).log"
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}

// MARK: - Convenience

public let log = SuibhneLogger.shared
