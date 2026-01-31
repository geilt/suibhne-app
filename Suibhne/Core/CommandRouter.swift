// CommandRouter.swift
// Routes incoming commands to appropriate services

import Foundation

public actor CommandRouter {
    public static let shared = CommandRouter()
    
    private let contacts = ContactsService.shared
    // private let calendar = CalendarService.shared
    // private let reminders = RemindersService.shared
    
    private init() {}
    
    public func handle(_ request: SuibhneRequest) async -> SuibhneResponse {
        log.info("Handling command", context: ["command": request.command, "id": request.id])
        
        guard let command = SuibhneCommand(rawValue: request.command) else {
            return .failure(id: request.id, error: "Unknown command: \(request.command)")
        }
        
        do {
            let result = try await execute(command, args: request.args)
            return .success(id: request.id, data: result)
        } catch {
            log.error("Command failed", error: error, context: ["command": request.command])
            return .failure(id: request.id, error: error.localizedDescription)
        }
    }
    
    private func execute(_ command: SuibhneCommand, args: [String: AnyCodable]) async throws -> Any? {
        switch command {
            
        // MARK: - Contacts
            
        case .contactsSearch:
            guard let query = args["query"]?.stringValue else {
                throw CommandError.missingArgument("query")
            }
            return try await contacts.search(query: query)
            
        case .contactsGet:
            guard let id = args["id"]?.stringValue else {
                throw CommandError.missingArgument("id")
            }
            return try await contacts.get(id: id)
            
        case .contactsList:
            let limit = args["limit"]?.intValue ?? 100
            return try await contacts.list(limit: limit)
            
        case .contactsCreate:
            guard let name = args["name"]?.stringValue else {
                throw CommandError.missingArgument("name")
            }
            let phone = args["phone"]?.stringValue
            let email = args["email"]?.stringValue
            let org = args["organization"]?.stringValue
            return try await contacts.create(name: name, phone: phone, email: email, organization: org)
            
        case .contactsUpdate:
            guard let id = args["id"]?.stringValue else {
                throw CommandError.missingArgument("id")
            }
            return try await contacts.update(
                id: id,
                addPhone: args["add_phone"]?.stringValue,
                addEmail: args["add_email"]?.stringValue,
                setOrganization: args["organization"]?.stringValue,
                setNotes: args["notes"]?.stringValue
            )
            
        case .contactsDelete:
            guard let id = args["id"]?.stringValue else {
                throw CommandError.missingArgument("id")
            }
            return try await contacts.delete(id: id)
            
        // MARK: - Calendar (stub)
            
        case .calendarEvents:
            throw CommandError.notImplemented("calendar.events")
            
        case .calendarCreate:
            throw CommandError.notImplemented("calendar.create")
            
        // MARK: - Reminders (stub)
            
        case .remindersList:
            throw CommandError.notImplemented("reminders.list")
            
        case .remindersAdd:
            throw CommandError.notImplemented("reminders.add")
            
        case .remindersComplete:
            throw CommandError.notImplemented("reminders.complete")
            
        // MARK: - OpenClaw Config
            
        case .configGet:
            return try await getConfig()
            
        case .configSet:
            guard let key = args["key"]?.stringValue,
                  let value = args["value"] else {
                throw CommandError.missingArgument("key and value")
            }
            return try await setConfig(key: key, value: value.value)
            
        case .skillsList:
            return try await listSkills()
            
        case .skillsInstall:
            guard let url = args["url"]?.stringValue else {
                throw CommandError.missingArgument("url")
            }
            return try await installSkill(from: url)
            
        // MARK: - Meta
            
        case .status:
            return await getStatus()
            
        case .permissions:
            return await getPermissions()
            
        case .ping:
            return ["pong": true, "timestamp": ISO8601DateFormatter().string(from: Date())]
        }
    }
    
    // MARK: - Config Helpers
    
    private func getConfig() async throws -> [String: Any] {
        let configPath = SuibhnePaths.configPath
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw CommandError.fileNotFound(configPath)
        }
        
        let content = try String(contentsOfFile: configPath, encoding: .utf8)
        return ["path": configPath, "content": content]
    }
    
    private func setConfig(key: String, value: Any) async throws -> [String: Any] {
        // For safety, we don't directly modify config - we return instructions
        return [
            "message": "Config modification not yet implemented for safety",
            "key": key,
            "value": String(describing: value)
        ]
    }
    
    private func listSkills() async throws -> [[String: String]] {
        let skillsPath = "\(NSHomeDirectory())/.openclaw/skills"
        let moltbotSkillsPath = "\(NSHomeDirectory())/moltbot/skills"
        
        var skills: [[String: String]] = []
        
        for path in [skillsPath, moltbotSkillsPath] {
            if let items = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for item in items {
                    let fullPath = "\(path)/\(item)"
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                        skills.append(["name": item, "path": fullPath])
                    }
                }
            }
        }
        
        return skills
    }
    
    private func installSkill(from url: String) async throws -> [String: Any] {
        // Stub - would clone repo and symlink
        return ["message": "Skill installation not yet implemented", "url": url]
    }
    
    // MARK: - Status Helpers
    
    private func getStatus() async -> [String: Any] {
        return [
            "app": "Suibhne",
            "version": "0.1.0",
            "socketPath": SuibhnePaths.socketPath,
            "socketActive": FileManager.default.fileExists(atPath: SuibhnePaths.socketPath),
            "uptime": ProcessInfo.processInfo.systemUptime
        ]
    }
    
    private func getPermissions() async -> [String: Any] {
        // Check various TCC permissions
        var permissions: [String: String] = [:]
        
        // Contacts - we'll check by trying to access
        permissions["contacts"] = "checking..."
        
        // Calendar
        permissions["calendar"] = "checking..."
        
        // Reminders  
        permissions["reminders"] = "checking..."
        
        return permissions
    }
}

// MARK: - Errors

public enum CommandError: LocalizedError {
    case missingArgument(String)
    case notImplemented(String)
    case fileNotFound(String)
    case permissionDenied(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingArgument(let arg):
            return "Missing required argument: \(arg)"
        case .notImplemented(let command):
            return "Command not yet implemented: \(command)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .permissionDenied(let resource):
            return "Permission denied for: \(resource)"
        }
    }
}
