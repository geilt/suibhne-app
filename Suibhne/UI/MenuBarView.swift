// MenuBarView.swift
// Menu bar popover content

import SwiftUI

struct MenuBarView: View {
    @State private var socketActive = true
    @State private var contactsPermission = "checking..."
    @State private var recentLogs: [String] = []
    @State private var showingLogs = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            SuibhneDivider()
            
            // Status
            statusSection
            
            SuibhneDivider()
            
            // Permissions
            permissionsSection
            
            SuibhneDivider()
            
            // Quick Actions
            actionsSection
            
            Spacer()
            
            // Footer
            footer
        }
        .padding()
        .frame(width: 320, height: 400)
        .background(Color.suibhneBgDeep)
        .onAppear {
            refreshStatus()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            FeatherIcon()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Suibhne")
                    .font(.heading)
                    .foregroundColor(.suibhneGold)
                
                Text("The Bridge Between Worlds")
                    .font(.caption)
                    .foregroundColor(.suibhneTextDim)
                    .italic()
            }
            
            Spacer()
            
            StatusDot(isActive: socketActive)
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATUS")
                .font(.caption)
                .foregroundColor(.suibhneGoldDim)
                .tracking(2)
            
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.suibhneSilver)
                Text("Socket")
                    .foregroundColor(.suibhneText)
                Spacer()
                Text(socketActive ? "Active" : "Inactive")
                    .font(.mono)
                    .foregroundColor(socketActive ? .suibhneSuccess : .suibhneError)
            }
            
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.suibhneSilver)
                Text("Path")
                    .foregroundColor(.suibhneText)
                Spacer()
                Text("~/.suibhne/")
                    .font(.mono)
                    .foregroundColor(.suibhneTextDim)
            }
        }
        .suibhneCard()
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PERMISSIONS")
                .font(.caption)
                .foregroundColor(.suibhneGoldDim)
                .tracking(2)
            
            PermissionRow(
                icon: "person.crop.circle",
                name: "Contacts",
                status: contactsPermission
            )
            
            PermissionRow(
                icon: "calendar",
                name: "Calendar",
                status: "not requested"
            )
            
            PermissionRow(
                icon: "checklist",
                name: "Reminders",
                status: "not requested"
            )
        }
        .suibhneCard()
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 8) {
            Button(action: { showingLogs.toggle() }) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("View Logs")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.suibhneText)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            
            Button(action: openSettings) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.suibhneText)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            
            Button(action: openOpenClawConfig) {
                HStack {
                    Image(systemName: "doc.badge.gearshape")
                    Text("OpenClaw Config")
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                }
                .foregroundColor(.suibhneText)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .suibhneCard()
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Text("v0.1.0")
                .font(.caption)
                .foregroundColor(.suibhneTextDim)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption)
            .foregroundColor(.suibhneTextDim)
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func refreshStatus() {
        // Check socket
        socketActive = FileManager.default.fileExists(atPath: SuibhnePaths.socketPath)
        
        // Check contacts permission
        Task {
            do {
                try await ContactsService.shared.requestAccess()
                await MainActor.run {
                    contactsPermission = "granted"
                }
            } catch {
                await MainActor.run {
                    contactsPermission = "denied"
                }
            }
        }
    }
    
    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    private func openOpenClawConfig() {
        let configPath = SuibhnePaths.configPath
        NSWorkspace.shared.selectFile(configPath, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let name: String
    let status: String
    
    private var statusColor: Color {
        switch status {
        case "granted": return .suibhneSuccess
        case "denied": return .suibhneError
        default: return .suibhneTextDim
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.suibhneSilver)
                .frame(width: 20)
            
            Text(name)
                .foregroundColor(.suibhneText)
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
}
