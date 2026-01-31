// SuibhneApp.swift
// Main app entry point

import SwiftUI

@main
struct SuibhneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar only - no main window
        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("Suibhne.app starting...")
        
        // Create menu bar item
        setupMenuBar()
        
        // Start socket server
        startServer()
        
        // Request permissions proactively
        Task {
            await requestPermissions()
        }
        
        log.info("Suibhne.app ready", context: ["socket": SuibhnePaths.socketPath])
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        log.info("Suibhne.app shutting down...")
        SocketServer.shared.stop()
    }
    
    // MARK: - Menu Bar
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Suibhne")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    // MARK: - Server
    
    private func startServer() {
        do {
            // Set up command handler
            SocketServer.shared.commandHandler = { request in
                await CommandRouter.shared.handle(request)
            }
            
            // Start listening
            try SocketServer.shared.start()
        } catch {
            log.error("Failed to start socket server", error: error)
        }
    }
    
    // MARK: - Permissions
    
    private func requestPermissions() async {
        // Request Contacts access
        do {
            try await ContactsService.shared.requestAccess()
        } catch {
            log.warn("Contacts permission not granted", error: error)
        }
        
        // Future: Calendar, Reminders, etc.
    }
}
