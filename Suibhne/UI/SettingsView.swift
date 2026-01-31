// SettingsView.swift
// Settings window

import SwiftUI

struct SettingsView: View {
    @State private var logLevel: String = "info"
    @State private var launchAtLogin = false
    @State private var recentLogs: [LogEntry] = []
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)
            
            permissionsTab
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
                .tag(1)
            
            logsTab
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }
                .tag(2)
            
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .frame(width: 500, height: 400)
    }
    
    // MARK: - General Tab
    
    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        // TODO: Implement launch at login
                    }
                
                Picker("Log Level", selection: $logLevel) {
                    Text("Debug").tag("debug")
                    Text("Info").tag("info")
                    Text("Warn").tag("warn")
                    Text("Error").tag("error")
                }
                .onChange(of: logLevel) { _, newValue in
                    switch newValue {
                    case "debug": log.logLevel = .debug
                    case "info": log.logLevel = .info
                    case "warn": log.logLevel = .warn
                    case "error": log.logLevel = .error
                    default: break
                    }
                }
            } header: {
                Text("Application")
            }
            
            Section {
                LabeledContent("Socket Path") {
                    Text(SuibhnePaths.socketPath)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                LabeledContent("Log Directory") {
                    Text(SuibhnePaths.logPath)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                LabeledContent("Config Path") {
                    Text(SuibhnePaths.configPath)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Paths")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Permissions Tab
    
    private var permissionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suibhne needs permission to access protected resources on behalf of OpenClaw and other headless processes.")
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                PermissionCard(
                    name: "Contacts",
                    description: "Search, create, and update contacts",
                    icon: "person.crop.circle.fill",
                    status: .granted
                )
                
                PermissionCard(
                    name: "Calendar",
                    description: "Read and create calendar events",
                    icon: "calendar",
                    status: .notRequested
                )
                
                PermissionCard(
                    name: "Reminders",
                    description: "Manage reminders and lists",
                    icon: "checklist",
                    status: .notRequested
                )
                
                PermissionCard(
                    name: "Automation",
                    description: "Control other applications via AppleScript",
                    icon: "gearshape.2.fill",
                    status: .notRequested
                )
            }
            
            Spacer()
            
            Button("Open System Settings...") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
            }
        }
        .padding()
    }
    
    // MARK: - Logs Tab
    
    private var logsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent Logs")
                    .font(.headline)
                
                Spacer()
                
                Button("Refresh") {
                    loadLogs()
                }
                
                Button("Open in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: SuibhnePaths.logPath)
                }
            }
            .padding()
            
            Divider()
            
            if recentLogs.isEmpty {
                VStack {
                    Spacer()
                    Text("No logs yet")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(recentLogs) { entry in
                    LogRow(entry: entry)
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            loadLogs()
        }
    }
    
    // MARK: - About Tab
    
    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("🪶")
                .font(.system(size: 64))
            
            Text("Suibhne")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("The Bridge Between Worlds")
                .font(.title3)
                .foregroundColor(.secondary)
                .italic()
            
            Text("v0.1.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
                .frame(width: 200)
            
            Text("Named for Suibhne Geilt, the legendary wild king who wandered between worlds.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Spacer()
            
            HStack(spacing: 16) {
                Link("Website", destination: URL(string: "https://suibhne.bot")!)
                Link("GitHub", destination: URL(string: "https://github.com/geilt/suibhne-app")!)
            }
            .font(.caption)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func loadLogs() {
        let rawLogs = log.recentLogs(limit: 50)
        recentLogs = rawLogs.compactMap { line in
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let timestamp = json["timestamp"] as? String,
                  let level = json["level"] as? String,
                  let message = json["message"] as? String else {
                return nil
            }
            
            return LogEntry(
                id: UUID().uuidString,
                timestamp: timestamp,
                level: level,
                message: message
            )
        }
    }
}

// MARK: - Supporting Views

struct PermissionCard: View {
    let name: String
    let description: String
    let icon: String
    let status: PermissionStatus
    
    enum PermissionStatus {
        case granted, denied, notRequested
        
        var text: String {
            switch self {
            case .granted: return "Granted"
            case .denied: return "Denied"
            case .notRequested: return "Not Requested"
            }
        }
        
        var color: Color {
            switch self {
            case .granted: return .green
            case .denied: return .red
            case .notRequested: return .secondary
            }
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(status.text)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(status.color.opacity(0.2))
                .foregroundColor(status.color)
                .cornerRadius(4)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct LogEntry: Identifiable {
    let id: String
    let timestamp: String
    let level: String
    let message: String
}

struct LogRow: View {
    let entry: LogEntry
    
    private var levelColor: Color {
        switch entry.level {
        case "ERROR": return .red
        case "WARN": return .orange
        case "INFO": return .blue
        case "DEBUG": return .gray
        default: return .primary
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.level)
                .font(.caption.monospaced())
                .foregroundColor(levelColor)
                .frame(width: 50, alignment: .leading)
            
            Text(entry.message)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(formatTimestamp(entry.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func formatTimestamp(_ iso: String) -> String {
        // Extract just HH:MM:SS
        if let tIndex = iso.firstIndex(of: "T"),
           let dotIndex = iso.firstIndex(of: ".") ?? iso.firstIndex(of: "Z") {
            let start = iso.index(after: tIndex)
            return String(iso[start..<dotIndex])
        }
        return iso
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
