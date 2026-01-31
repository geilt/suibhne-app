// SocketServer.swift
// Unix socket server for IPC

import Foundation

public final class SocketServer {
    public static let shared = SocketServer()
    
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "app.suibhne.socket", qos: .userInitiated)
    
    public var commandHandler: ((SuibhneRequest) async -> SuibhneResponse)?
    
    private init() {}
    
    // MARK: - Lifecycle
    
    public func start() throws {
        let socketPath = SuibhnePaths.socketPath
        
        print("🔌 SocketServer: Starting...")
        print("🔌 SocketServer: Socket path: \(socketPath)")
        
        // Ensure directories exist
        SuibhnePaths.ensureDirectories()
        print("🔌 SocketServer: Directories ensured")
        
        // Remove existing socket
        unlink(socketPath)
        print("🔌 SocketServer: Unlinked old socket")
        
        // Create socket
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            let err = String(cString: strerror(errno))
            print("🔌 SocketServer: ERROR creating socket: \(err)")
            throw SocketError.createFailed(err)
        }
        print("🔌 SocketServer: Socket created (fd: \(serverSocket))")
        
        // Bind to path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        // Copy path into sun_path
        socketPath.withCString { src in
            withUnsafeMutablePointer(to: &addr.sun_path) { dst in
                _ = memcpy(dst, src, min(socketPath.utf8.count, 103))
            }
        }
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        
        guard bindResult == 0 else {
            let err = String(cString: strerror(errno))
            print("🔌 SocketServer: ERROR binding socket: \(err)")
            close(serverSocket)
            throw SocketError.bindFailed(err)
        }
        print("🔌 SocketServer: Socket bound to path")
        
        // Set permissions (owner read/write only)
        chmod(socketPath, S_IRUSR | S_IWUSR)
        
        // Listen
        guard Darwin.listen(serverSocket, 5) == 0 else {
            let err = String(cString: strerror(errno))
            print("🔌 SocketServer: ERROR listening: \(err)")
            close(serverSocket)
            throw SocketError.listenFailed(err)
        }
        
        isRunning = true
        print("🔌 SocketServer: Listening on \(socketPath)")
        log.info("Socket server listening", context: ["path": socketPath])
        
        // Accept loop in background
        queue.async { [weak self] in
            self?.acceptLoop()
        }
    }
    
    public func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        try? FileManager.default.removeItem(atPath: SuibhnePaths.socketPath)
        print("🔌 SocketServer: Stopped")
        log.info("Socket server stopped")
    }
    
    // MARK: - Accept Loop
    
    private func acceptLoop() {
        print("🔌 SocketServer: Accept loop started")
        
        while isRunning && serverSocket >= 0 {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Darwin.accept(serverSocket, sockaddrPtr, &clientAddrLen)
                }
            }
            
            guard clientSocket >= 0 else {
                if isRunning {
                    let err = String(cString: strerror(errno))
                    print("🔌 SocketServer: Accept error: \(err)")
                }
                continue
            }
            
            print("🔌 SocketServer: Client connected (fd: \(clientSocket))")
            
            // Handle client in separate queue
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(clientSocket)
            }
        }
        
        print("🔌 SocketServer: Accept loop ended")
    }
    
    private func handleClient(_ clientSocket: Int32) {
        defer {
            close(clientSocket)
            print("🔌 SocketServer: Client disconnected (fd: \(clientSocket))")
        }
        
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        
        guard bytesRead > 0 else {
            return
        }
        
        let data = Data(bytes: buffer, count: bytesRead)
        
        guard let requestString = String(data: data, encoding: .utf8) else {
            print("🔌 SocketServer: Invalid UTF-8 data")
            return
        }
        
        print("🔌 SocketServer: Received: \(requestString.prefix(100))...")
        
        // Parse and handle request
        handleRequest(requestString, clientSocket: clientSocket)
    }
    
    private func handleRequest(_ requestString: String, clientSocket: Int32) {
        // Parse JSON request
        guard let data = requestString.data(using: .utf8),
              let request = try? JSONDecoder().decode(SuibhneRequest.self, from: data) else {
            let errorResponse = SuibhneResponse.failure(id: "unknown", error: "Invalid request format")
            sendResponse(errorResponse, to: clientSocket)
            return
        }
        
        print("🔌 SocketServer: Request: \(request.command)")
        log.debug("Request received", context: ["id": request.id, "command": request.command])
        
        // Handle command
        let semaphore = DispatchSemaphore(value: 0)
        var response: SuibhneResponse = .failure(id: request.id, error: "No handler")
        
        Task {
            if let handler = commandHandler {
                response = await handler(request)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        sendResponse(response, to: clientSocket)
    }
    
    private func sendResponse(_ response: SuibhneResponse, to clientSocket: Int32) {
        guard let data = try? JSONEncoder().encode(response),
              var responseString = String(data: data, encoding: .utf8) else {
            print("🔌 SocketServer: Failed to encode response")
            return
        }
        
        responseString += "\n"
        
        _ = responseString.withCString { cString in
            write(clientSocket, cString, strlen(cString))
        }
        
        print("🔌 SocketServer: Response sent (success: \(response.success))")
        log.debug("Response sent", context: ["id": response.id, "success": response.success])
    }
}

// MARK: - Errors

public enum SocketError: LocalizedError {
    case createFailed(String)
    case bindFailed(String)
    case listenFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .createFailed(let msg): return "Failed to create socket: \(msg)"
        case .bindFailed(let msg): return "Failed to bind socket: \(msg)"
        case .listenFailed(let msg): return "Failed to listen on socket: \(msg)"
        }
    }
}
