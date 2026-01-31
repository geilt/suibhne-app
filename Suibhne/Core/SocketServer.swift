// SocketServer.swift
// Unix socket server for IPC

import Foundation
import Network

public final class SocketServer {
    public static let shared = SocketServer()
    
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "bot.suibhne.socket", qos: .userInitiated)
    
    public var commandHandler: ((SuibhneRequest) async -> SuibhneResponse)?
    
    private init() {}
    
    // MARK: - Lifecycle
    
    public func start() throws {
        // Remove existing socket file
        let socketPath = SuibhnePaths.socketPath
        SuibhnePaths.ensureDirectories()
        try? FileManager.default.removeItem(atPath: socketPath)
        
        // Create Unix domain socket listener
        let params = NWParameters()
        params.allowLocalEndpointReuse = true
        params.acceptLocalOnly = true
        
        let endpoint = NWEndpoint.unix(path: socketPath)
        
        listener = try NWListener(using: params)
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                log.info("Socket server ready", context: ["path": socketPath])
            case .failed(let error):
                log.error("Socket server failed", error: error)
            case .cancelled:
                log.info("Socket server cancelled")
            default:
                break
            }
        }
        
        // We need to bind to the unix socket path
        // NWListener doesn't directly support unix sockets in this way
        // Let's use a simpler approach with Darwin sockets
        startDarwinSocket()
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        
        try? FileManager.default.removeItem(atPath: SuibhnePaths.socketPath)
        log.info("Socket server stopped")
    }
    
    // MARK: - Darwin Socket Implementation
    
    private var serverSocket: Int32 = -1
    private var isRunning = false
    
    private func startDarwinSocket() {
        let socketPath = SuibhnePaths.socketPath
        
        // Remove existing socket
        unlink(socketPath)
        
        // Create socket
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            log.error("Failed to create socket", context: ["errno": errno])
            return
        }
        
        // Bind to path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        let pathBytes = socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let bound = ptr.withMemoryRebound(to: CChar.self, capacity: 104) { sunPath in
                for (i, byte) in pathBytes.enumerated() where i < 103 {
                    sunPath[i] = byte
                }
            }
        }
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        
        guard bindResult == 0 else {
            log.error("Failed to bind socket", context: ["errno": errno, "path": socketPath])
            close(serverSocket)
            return
        }
        
        // Set permissions (owner read/write only)
        chmod(socketPath, S_IRUSR | S_IWUSR)
        
        // Listen
        guard listen(serverSocket, 5) == 0 else {
            log.error("Failed to listen on socket", context: ["errno": errno])
            close(serverSocket)
            return
        }
        
        isRunning = true
        log.info("Socket server listening", context: ["path": socketPath])
        
        // Accept loop
        queue.async { [weak self] in
            self?.acceptLoop()
        }
    }
    
    private func acceptLoop() {
        while isRunning && serverSocket >= 0 {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    accept(serverSocket, sockaddrPtr, &clientAddrLen)
                }
            }
            
            guard clientSocket >= 0 else {
                if isRunning {
                    log.warn("Accept failed", context: ["errno": errno])
                }
                continue
            }
            
            log.debug("Client connected", context: ["fd": clientSocket])
            
            // Handle client in separate queue
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(clientSocket)
            }
        }
    }
    
    private func handleClient(_ clientSocket: Int32) {
        defer {
            close(clientSocket)
            log.debug("Client disconnected", context: ["fd": clientSocket])
        }
        
        var buffer = [UInt8](repeating: 0, count: 65536)
        
        while isRunning {
            let bytesRead = read(clientSocket, &buffer, buffer.count)
            
            guard bytesRead > 0 else {
                break // Client disconnected or error
            }
            
            let data = Data(bytes: buffer, count: bytesRead)
            
            guard let requestString = String(data: data, encoding: .utf8) else {
                log.warn("Invalid UTF-8 data received")
                continue
            }
            
            // Parse and handle request
            handleRequest(requestString, clientSocket: clientSocket)
        }
    }
    
    private func handleRequest(_ requestString: String, clientSocket: Int32) {
        // Parse JSON request
        guard let data = requestString.data(using: .utf8),
              let request = try? JSONDecoder().decode(SuibhneRequest.self, from: data) else {
            let errorResponse = SuibhneResponse.failure(id: "unknown", error: "Invalid request format")
            sendResponse(errorResponse, to: clientSocket)
            return
        }
        
        log.debug("Request received", context: ["id": request.id, "command": request.command])
        
        // Handle command
        Task {
            let response: SuibhneResponse
            
            if let handler = commandHandler {
                response = await handler(request)
            } else {
                response = SuibhneResponse.failure(id: request.id, error: "No command handler registered")
            }
            
            sendResponse(response, to: clientSocket)
        }
    }
    
    private func sendResponse(_ response: SuibhneResponse, to clientSocket: Int32) {
        guard let data = try? JSONEncoder().encode(response),
              var responseString = String(data: data, encoding: .utf8) else {
            log.error("Failed to encode response")
            return
        }
        
        responseString += "\n"
        
        responseString.withCString { cString in
            _ = write(clientSocket, cString, strlen(cString))
        }
        
        log.debug("Response sent", context: ["id": response.id, "success": response.success])
    }
    
    // MARK: - NWConnection handling (for future)
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                log.debug("Connection ready")
                self?.receive(on: connection)
            case .failed(let error):
                log.error("Connection failed", error: error)
            case .cancelled:
                self?.connections.removeAll { $0 === connection }
            default:
                break
            }
        }
        
        connections.append(connection)
        connection.start(queue: queue)
    }
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleData(data, from: connection)
            }
            
            if let error = error {
                log.error("Receive error", error: error)
                return
            }
            
            if isComplete {
                connection.cancel()
            } else {
                self?.receive(on: connection)
            }
        }
    }
    
    private func handleData(_ data: Data, from connection: NWConnection) {
        guard let request = try? JSONDecoder().decode(SuibhneRequest.self, from: data) else {
            log.warn("Invalid request data")
            return
        }
        
        Task {
            let response: SuibhneResponse
            
            if let handler = commandHandler {
                response = await handler(request)
            } else {
                response = SuibhneResponse.failure(id: request.id, error: "No handler")
            }
            
            if let responseData = try? JSONEncoder().encode(response) {
                connection.send(content: responseData, completion: .contentProcessed { error in
                    if let error = error {
                        log.error("Send error", error: error)
                    }
                })
            }
        }
    }
}
