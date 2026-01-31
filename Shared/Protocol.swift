// Protocol.swift
// Shared types for Suibhne IPC

import Foundation

// MARK: - Request/Response Envelope

public struct SuibhneRequest: Codable {
    public let id: String
    public let command: String
    public let args: [String: AnyCodable]
    
    public init(id: String = UUID().uuidString, command: String, args: [String: AnyCodable] = [:]) {
        self.id = id
        self.command = command
        self.args = args
    }
}

public struct SuibhneResponse: Codable {
    public let id: String
    public let success: Bool
    public let data: AnyCodable?
    public let error: String?
    
    public static func success(id: String, data: Any?) -> SuibhneResponse {
        SuibhneResponse(id: id, success: true, data: data.map { AnyCodable($0) }, error: nil)
    }
    
    public static func failure(id: String, error: String) -> SuibhneResponse {
        SuibhneResponse(id: id, success: false, data: nil, error: error)
    }
}

// MARK: - Commands

public enum SuibhneCommand: String, CaseIterable {
    // Contacts
    case contactsSearch = "contacts.search"
    case contactsGet = "contacts.get"
    case contactsList = "contacts.list"
    case contactsCreate = "contacts.create"
    case contactsUpdate = "contacts.update"
    case contactsDelete = "contacts.delete"
    
    // Calendar
    case calendarEvents = "calendar.events"
    case calendarCreate = "calendar.create"
    
    // Reminders
    case remindersList = "reminders.list"
    case remindersAdd = "reminders.add"
    case remindersComplete = "reminders.complete"
    
    // OpenClaw
    case configGet = "config.get"
    case configSet = "config.set"
    case skillsList = "skills.list"
    case skillsInstall = "skills.install"
    
    // Meta
    case status = "status"
    case permissions = "permissions"
    case ping = "ping"
}

// MARK: - AnyCodable (for flexible JSON)

public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encode(String(describing: value))
        }
    }
    
    public var stringValue: String? { value as? String }
    public var intValue: Int? { value as? Int }
    public var boolValue: Bool? { value as? Bool }
    public var arrayValue: [Any]? { value as? [Any] }
    public var dictValue: [String: Any]? { value as? [String: Any] }
}

// MARK: - Contact Types

public struct Contact: Codable, Identifiable {
    public let id: String
    public var name: String
    public var organization: String?
    public var phones: [String]
    public var emails: [String]
    public var notes: String?
    
    public init(id: String, name: String, organization: String? = nil, phones: [String] = [], emails: [String] = [], notes: String? = nil) {
        self.id = id
        self.name = name
        self.organization = organization
        self.phones = phones
        self.emails = emails
        self.notes = notes
    }
}

// MARK: - Paths

public struct SuibhnePaths {
    // Use real home directory, not sandbox container
    private static var realHome: String {
        if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
            return String(cString: home)
        }
        return NSHomeDirectory() // fallback
    }
    
    // Socket in /tmp (accessible by sandboxed apps)
    public static let socketPath = "/tmp/suibhne.sock"
    
    // Logs in home directory (may fail if sandboxed, falls back to container)
    public static var logPath: String { "\(NSHomeDirectory())/.suibhne/logs" }
    public static var configPath: String { "\(realHome)/.openclaw/config.yaml" }
    
    public static func ensureDirectories() {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: "\(NSHomeDirectory())/.suibhne", withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: logPath, withIntermediateDirectories: true)
    }
}
