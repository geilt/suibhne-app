#!/usr/bin/env swift
// suibhne CLI
// Command-line interface for Suibhne.app

import Foundation

// MARK: - Client

class SuibhneClient {
    private let socketPath: String
    
    init(socketPath: String = "\(NSHomeDirectory())/.suibhne/suibhne.sock") {
        self.socketPath = socketPath
    }
    
    func send(command: String, args: [String: Any] = [:]) throws -> [String: Any] {
        // Create socket
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw ClientError.socketCreationFailed
        }
        defer { close(fd) }
        
        // Connect to Unix socket
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        let pathBytes = socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 104) { sunPath in
                for (i, byte) in pathBytes.enumerated() where i < 103 {
                    sunPath[i] = byte
                }
            }
        }
        
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        
        guard connectResult == 0 else {
            throw ClientError.connectionFailed
        }
        
        // Build request
        let request: [String: Any] = [
            "id": UUID().uuidString,
            "command": command,
            "args": args
        ]
        
        let requestData = try JSONSerialization.data(withJSONObject: request)
        let requestString = String(data: requestData, encoding: .utf8)!
        
        // Send request
        _ = requestString.withCString { cString in
            write(fd, cString, strlen(cString))
        }
        
        // Read response
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buffer, buffer.count)
        
        guard bytesRead > 0 else {
            throw ClientError.noResponse
        }
        
        let responseData = Data(bytes: buffer, count: bytesRead)
        guard let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw ClientError.invalidResponse
        }
        
        return response
    }
}

enum ClientError: LocalizedError {
    case socketCreationFailed
    case connectionFailed
    case noResponse
    case invalidResponse
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .socketCreationFailed:
            return "Failed to create socket"
        case .connectionFailed:
            return "Failed to connect to Suibhne.app. Is it running?"
        case .noResponse:
            return "No response from server"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let msg):
            return "Server error: \(msg)"
        }
    }
}

// MARK: - CLI

struct CLI {
    let args: [String]
    let client = SuibhneClient()
    
    func run() {
        guard args.count > 1 else {
            printUsage()
            return
        }
        
        let command = args[1]
        let subArgs = Array(args.dropFirst(2))
        
        do {
            switch command {
            case "contacts":
                try handleContacts(subArgs)
            case "calendar":
                try handleCalendar(subArgs)
            case "reminders":
                try handleReminders(subArgs)
            case "config":
                try handleConfig(subArgs)
            case "skills":
                try handleSkills(subArgs)
            case "status":
                try handleStatus()
            case "permissions":
                try handlePermissions()
            case "logs":
                try handleLogs(subArgs)
            case "ping":
                try handlePing()
            case "help", "--help", "-h":
                printUsage()
            case "version", "--version", "-v":
                print("suibhne 0.1.0")
            default:
                print("Unknown command: \(command)")
                print("Run 'suibhne help' for usage.")
                exit(1)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    // MARK: - Contacts
    
    private func handleContacts(_ args: [String]) throws {
        guard let action = args.first else {
            print("Usage: suibhne contacts <search|get|list|create|update|delete> [args]")
            return
        }
        
        switch action {
        case "search":
            guard args.count > 1 else {
                print("Usage: suibhne contacts search <query>")
                return
            }
            let query = args.dropFirst().joined(separator: " ")
            let response = try client.send(command: "contacts.search", args: ["query": query])
            printResponse(response)
            
        case "get":
            guard args.count > 1 else {
                print("Usage: suibhne contacts get <id>")
                return
            }
            let response = try client.send(command: "contacts.get", args: ["id": args[1]])
            printResponse(response)
            
        case "list":
            let limit = args.count > 1 ? Int(args[1]) ?? 100 : 100
            let response = try client.send(command: "contacts.list", args: ["limit": limit])
            printResponse(response)
            
        case "create":
            var createArgs: [String: Any] = [:]
            var i = 1
            while i < args.count {
                switch args[i] {
                case "--name", "-n":
                    if i + 1 < args.count { createArgs["name"] = args[i + 1]; i += 1 }
                case "--phone", "-p":
                    if i + 1 < args.count { createArgs["phone"] = args[i + 1]; i += 1 }
                case "--email", "-e":
                    if i + 1 < args.count { createArgs["email"] = args[i + 1]; i += 1 }
                case "--org", "-o":
                    if i + 1 < args.count { createArgs["organization"] = args[i + 1]; i += 1 }
                default:
                    break
                }
                i += 1
            }
            
            guard createArgs["name"] != nil else {
                print("Usage: suibhne contacts create --name <name> [--phone <phone>] [--email <email>] [--org <org>]")
                return
            }
            
            let response = try client.send(command: "contacts.create", args: createArgs)
            printResponse(response)
            
        case "update":
            guard args.count > 2 else {
                print("Usage: suibhne contacts update <id> [--add-phone <phone>] [--add-email <email>] [--org <org>]")
                return
            }
            
            var updateArgs: [String: Any] = ["id": args[1]]
            var i = 2
            while i < args.count {
                switch args[i] {
                case "--add-phone":
                    if i + 1 < args.count { updateArgs["add_phone"] = args[i + 1]; i += 1 }
                case "--add-email":
                    if i + 1 < args.count { updateArgs["add_email"] = args[i + 1]; i += 1 }
                case "--org":
                    if i + 1 < args.count { updateArgs["organization"] = args[i + 1]; i += 1 }
                case "--notes":
                    if i + 1 < args.count { updateArgs["notes"] = args[i + 1]; i += 1 }
                default:
                    break
                }
                i += 1
            }
            
            let response = try client.send(command: "contacts.update", args: updateArgs)
            printResponse(response)
            
        case "delete":
            guard args.count > 1 else {
                print("Usage: suibhne contacts delete <id>")
                return
            }
            let response = try client.send(command: "contacts.delete", args: ["id": args[1]])
            printResponse(response)
            
        default:
            print("Unknown contacts action: \(action)")
        }
    }
    
    // MARK: - Other Commands (stubs)
    
    private func handleCalendar(_ args: [String]) throws {
        print("Calendar commands not yet implemented")
    }
    
    private func handleReminders(_ args: [String]) throws {
        print("Reminders commands not yet implemented")
    }
    
    private func handleConfig(_ args: [String]) throws {
        guard let action = args.first else {
            print("Usage: suibhne config <get|edit>")
            return
        }
        
        switch action {
        case "get":
            let response = try client.send(command: "config.get")
            printResponse(response)
            
        case "edit":
            // Open config in default editor
            let configPath = "\(NSHomeDirectory())/.openclaw/config.yaml"
            let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "nano"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [editor, configPath]
            try process.run()
            process.waitUntilExit()
            
        default:
            print("Unknown config action: \(action)")
        }
    }
    
    private func handleSkills(_ args: [String]) throws {
        guard let action = args.first else {
            print("Usage: suibhne skills <list|install>")
            return
        }
        
        switch action {
        case "list":
            let response = try client.send(command: "skills.list")
            printResponse(response)
            
        case "install":
            guard args.count > 1 else {
                print("Usage: suibhne skills install <url>")
                return
            }
            let response = try client.send(command: "skills.install", args: ["url": args[1]])
            printResponse(response)
            
        default:
            print("Unknown skills action: \(action)")
        }
    }
    
    private func handleStatus() throws {
        let response = try client.send(command: "status")
        printResponse(response)
    }
    
    private func handlePermissions() throws {
        let response = try client.send(command: "permissions")
        printResponse(response)
    }
    
    private func handleLogs(_ args: [String]) throws {
        let logPath = "\(NSHomeDirectory())/.suibhne/logs"
        
        if args.first == "--tail" || args.first == "-f" {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
            process.arguments = ["-f", "\(logPath)/\(todayString()).log"]
            try process.run()
            process.waitUntilExit()
        } else {
            // Print recent logs
            let limit = Int(args.first ?? "20") ?? 20
            let logFile = "\(logPath)/\(todayString()).log"
            
            if let content = try? String(contentsOfFile: logFile, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                    .suffix(limit)
                
                for line in lines {
                    print(line)
                }
            } else {
                print("No logs found")
            }
        }
    }
    
    private func handlePing() throws {
        let response = try client.send(command: "ping")
        printResponse(response)
    }
    
    // MARK: - Helpers
    
    private func printUsage() {
        print("""
        suibhne - The Bridge Between Worlds
        
        USAGE:
            suibhne <command> [args]
        
        COMMANDS:
            contacts    Manage contacts (search, get, list, create, update, delete)
            calendar    Manage calendar events (coming soon)
            reminders   Manage reminders (coming soon)
            config      View or edit OpenClaw configuration
            skills      List or install skills
            status      Show Suibhne status
            permissions Show permission status
            logs        View recent logs (--tail for live)
            ping        Test connection to Suibhne.app
            help        Show this help
            version     Show version
        
        EXAMPLES:
            suibhne contacts search "john smith"
            suibhne contacts create --name "John Doe" --phone "+1234567890"
            suibhne config edit
            suibhne logs --tail
        
        For more information: https://suibhne.bot
        """)
    }
    
    private func printResponse(_ response: [String: Any]) {
        if let success = response["success"] as? Bool, !success {
            if let error = response["error"] as? String {
                print("Error: \(error)")
            }
            return
        }
        
        if let data = response["data"] {
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print(data)
            }
        }
    }
    
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Main

let cli = CLI(args: CommandLine.arguments)
cli.run()
