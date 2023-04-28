//
//  LSP.swift
//  Magma
//
//  Created by Maximilian Mackh on 05.03.23.
//

import Foundation

class LSP {
    public static var isDebugLogEnabled: Bool = false
    
    class Client {
        enum Executable {
            case clangd
            case custom(path: String)
            
            var path: String {
                switch self {
                case .clangd:
                    return "/usr/bin/clangd"
                case .custom(let path):
                    return path
                }
            }
        }
        
        public let UIDD: String = Foundation.UUID().uuidString
        
        private let process: LSP.Process
        
        private var id: Int = 1
        private var messageQueue: [Int: Message.Payload] = [:]
        private static let payloadSeparator: String = "\r\n\r\n"
        
        private var buffer: String = ""
        private var shouldBuffer: Bool = false
        private var expectedContentLength: Int = 0
        
        init(_ executable: Executable, environementVariables: [String:String]) {
            self.process = .init(executable: executable, environmentVariables: environementVariables)
            self.process.readHandler = { [unowned self] (data, isError) in
                guard let payload = String(data: data, encoding: .utf8) else { return }
                
                if isError {
                    if LSP.isDebugLogEnabled == false { return }
                    print(String(data: data, encoding: .utf8) ?? "Not decodable")
                    return
                }
                
                let messageComponents: [String] = payload.components(separatedBy: LSP.Client.payloadSeparator)
                
                if messageComponents.count == 2 {
                    self.expectedContentLength = Int(messageComponents.first?.components(separatedBy: ": ").last ?? "0")!
                    let jsonString = messageComponents.last!
                    
                    if self.expectedContentLength == jsonString.utf8.count {
                        buffer = String(jsonString)
                        self.shouldBuffer = false
                    } else {
                        buffer = String(jsonString)
                        self.shouldBuffer = true
                    }
                } else if shouldBuffer {
                    self.buffer += payload
                    self.expectedContentLength -= payload.utf8.count
                } else if self.expectedContentLength <= 0 {
                    self.shouldBuffer = false
                }
                
                let jsonString = String(buffer)
                guard let json: NSDictionary = try? JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as? NSDictionary, let responseID: Int = json["id"] as? Int, let payload = self.messageQueue[responseID] else { return }
                
                payload.responseHandler?(json)
                messageQueue[responseID] = nil
            }
            self.process.terminationHandler = {
                print("Bye LSP")
            }
        }
        
        @discardableResult
        private func write(message: Message, responseHandler: Message.Payload.ResponseHandler?) -> Bool {
            guard let payload: Message.Payload = message.packaged(with: id, responseHandler: responseHandler) else {
                return false
            }
            if message.isNotification == false {
                self.messageQueue[id] = payload
                id += 1
            }
            self.process._pipe.write(payload.data)
            return true
        }
        
        @discardableResult
        func notify(_ message: Message) -> Bool {
            self.write(message: message, responseHandler: nil)
        }
        
        @discardableResult
        func message(_ message: Message, responseHandler: @escaping Message.Payload.ResponseHandler) -> Bool {
            self.write(message: message, responseHandler: responseHandler)
        }
        
        func invalidate() {
            self.messageQueue.removeAll()
            self.process._pipe.close()
        }
        
        deinit {
            invalidate()
        }
    }
    
    enum Message {
        // messages with response
        case initialize(rootPath: String)
        case textCompletion(uri: URL, line: Int, column: Int, triggerKind: Int, triggerCharacter: String)
        case symbol(uri: URL)
        
        // notifications
        case didOpen(uri: URL)
        case didChange(uri: URL, version: Int, text: String, range: LSP.Range?)
        case didSave(uri: URL)
        case didClose(uri: URL)
        
        var isNotification: Bool {
            switch self {
            case .didOpen(_), .didChange(_,_,_,_), .didSave(_), .didClose(_):
                return true
            default:
                return false
            }
        }
        
        struct Payload {
            typealias ResponseHandler = (_ response: Any?)->()
            
            let message: Message
            let data: Data
            let responseHandler: ResponseHandler?
        }
        
        func packaged(with id: Int?, responseHandler: Payload.ResponseHandler?) -> Payload? {
            let payload: (String, NSDictionary)
            switch self {
            case .initialize(let rootPath):
                payload = ("initialize", ["trace":"off", "processId":ProcessInfo.processInfo.processIdentifier,"rootPath": rootPath])
            case .didOpen(let uri):
                payload = ("textDocument/didOpen", ["textDocument":["uri":uri.absoluteString,"languageId":"c","text": try! String(contentsOf: uri)]])
            case .didChange(let uri, let version, let text, let range):
                if let range = range {
                    payload = ("textDocument/didChange", ["textDocument":["uri":uri.absoluteString,"version":version], "contentChanges": [["text": text,"range":range.dictionary]]])
                } else {
                    payload = ("textDocument/didChange", ["textDocument":["uri":uri.absoluteString,"version":version], "contentChanges": [["text": text]]])
                }
            case .didSave(let uri):
                payload = ("textDocument/didSave", ["textDocument":["uri":uri.absoluteString,"text": try! String(contentsOf: uri)]])
            case .didClose(let uri):
                payload = ("textDocument/didClose", ["textDocument":["uri":uri.absoluteString]])
            case .textCompletion(let uri, let line, let column, let triggerKind, let triggerCharacter):
                payload = ("textDocument/completion", ["textDocument":["uri":uri.absoluteString], "position" : ["line":line,"character":column],"context":["triggerKind":triggerKind, "triggerCharacter": triggerCharacter]])
            case .symbol(let uri):
                payload = ("textDocument/documentSymbol", ["textDocument":["uri":uri.absoluteString]])
            }
            
            let json: NSMutableDictionary = ["jsonrpc":"2.0", "method": payload.0, "params" : payload.1]
            
            if isNotification == false, let id = id {
                json["id"] = id
            }
            
            guard let data = try? JSONSerialization.data(withJSONObject:json) else { return nil }
            return .init(message: self, data: "Content-Length: \(data.count)\r\n\r\n".data(using: .utf8)! + data, responseHandler: responseHandler)
        }
    }
}

extension LSP {
    class Process {
        var readHandler: ((_ data: Data, _ isError: Bool)->())? {
            set {
                _pipe.readHandler = newValue
            }
            get {
                _pipe.readHandler
            }
        }
        var terminationHandler: (()->())? {
            set {
                _process._terminationHandler = newValue
            }
            get {
                nil
            }
        }
        
        fileprivate let _process: Foundation.Process
        fileprivate let _pipe: LSP.Pipe
        
        init(executable: LSP.Client.Executable, environmentVariables: [String:String]) {
            let pipe: Pipe = .init()
            let process: Foundation.Process = .init()
            
            process.standardInput = pipe.input
            process.standardOutput = pipe.output
            process.standardError = pipe.error
            process._launchPath = executable.path
            process.arguments = []
            process.environment = environmentVariables
            try? process._run()
            
            self._process = process
            self._pipe = pipe
        }
        
        deinit {
            _process.terminate()
        }
    }
    
    fileprivate class Pipe {
        public let input: Foundation.Pipe
        public let output: Foundation.Pipe
        public let error: Foundation.Pipe
        
        public var readHandler: ((_ data: Data, _ isError: Bool)->())?
        
        private var isClosed: Bool = false
        
        private let queue: DispatchQueue
        
        init(queue: DispatchQueue = .init(label: "com.sentionic.magma.stdio")) {
            self.input = .init()
            self.output = .init()
            self.error = .init()
            
            self.queue = queue
            
            output.fileHandleForReading.readabilityHandler = { [unowned self] handle in
                self.read(data: handle.availableData, isError: false)
            }
            error.fileHandleForReading.readabilityHandler = { [unowned self] handle in
                self.read(data: handle.availableData, isError: true)
            }
        }
        
        private func read(data: Data, isError: Bool) {
            if isClosed || data.isEmpty { return }
            queue.async { [weak self] in
                self?.readHandler?(data, isError)
            }
        }
        
        public func write(_ data: Data) {
            if isClosed { return }
            
            queue.async { [weak self] in
                self?.input.fileHandleForWriting.write(data)
            }
        }
        
        public func close() {
            if self.isClosed == true { return }
            self.isClosed = true
            
            
            [input, output, error].forEach { pipe in
                pipe.fileHandleForWriting.closeFile()
                pipe.fileHandleForReading.closeFile()
            }
        }
    }
}

extension Foundation.Process {
    var _launchPath: String? {
        set {
            perform(NSSelectorFromString("setLaunchPath:"), with: newValue)
        }
        get {
            nil
        }
    }
    
    func _run() throws {
        let error: NSError? = nil
        perform(NSSelectorFromString("launchAndReturnError:"), with: error)
        if let error = error {
            throw error
        }
    }
    
    var _terminationHandler: (() -> Void)? {
        set {
            let handler: @convention(block) (Process) -> Void = { process in
                newValue?()
            }
            let block: AnyObject = unsafeBitCast(handler, to: AnyObject.self)
            perform(NSSelectorFromString("setTerminationHandler:"), with: block)
        }
        get {
            nil
        }
    }
}
