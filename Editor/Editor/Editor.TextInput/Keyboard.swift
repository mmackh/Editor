//
//  Keyboard.swift
//  Magma
//
//  Created by Maximilian Mackh on 19.02.23.
//

import Foundation

class Keyboard {
    struct Mask: OptionSet {
        let rawValue: UInt64
        static let keyDown = Self(rawValue: 1 << Event.Kind.keyDown.rawValue)
        static let keyUp = Self(rawValue: 1 << Event.Kind.keyUp.rawValue)
        static let flagsChanged = Self(rawValue: 1 << Event.Kind.flagsChanged.rawValue)
    }
    
    struct Event {
        enum Kind: UInt {
            case unknown = 0
            case keyDown = 10
            case keyUp = 11
            case flagsChanged = 12
        }
        
        var keyCode: Int {
            nsEvent.keyCode ?? 0
        }
        
        var characters: String {
            nsEvent.characters ?? ""
        }
        
        var modifiers: [Modifier] {
            Modifier.modifiers(for: nsEvent.modifierFlags ?? 0)
        }
        
        var kind: Kind {
            .init(rawValue: nsEvent.type ?? 0) ?? .unknown
        }
        
        fileprivate let nsEvent: NSEvent_Private
    }
    
    var isEnabled: Bool = true
    
    private let nsEvent: AnyClass
    private var monitor: Any!
    
    static private var isAddProtocolSuccessful: Bool = false
    
    init?(matching mask: Mask, handler: @escaping(_ event: Event)->(Event?)) {
        guard let nsEvent = NSClassFromString("NSEvent") else { return nil }
        self.nsEvent = nsEvent
        
        if !Keyboard.isAddProtocolSuccessful && !class_addProtocol(nsEvent, NSEvent_Private.self) { return nil }
        Keyboard.isAddProtocolSuccessful = true
        
        guard let monitor = nsEvent.addLocalMonitorForEvents(matching: mask.rawValue, handler: { [unowned self] nsEvent in
            if !self.isEnabled {
                return nsEvent
            }
            return handler(.init(nsEvent: nsEvent))?.nsEvent
        }) else { return nil }
        self.monitor = monitor as AnyObject
    }
    
    deinit {
        guard let monitor = monitor else { return }
        nsEvent.removeMonitor?(monitor)
    }
}

extension Keyboard {
    struct Modifier: OptionSet {
        let rawValue: UInt
        
        static let capsLock = Self(rawValue: 1 << 16)
        static let shift = Self(rawValue: 1 << 17)
        static let control = Self(rawValue: 1 << 18)
        static let option = Self(rawValue: 1 << 19)
        static let command = Self(rawValue: 1 << 20)
        
        static func modifiers(for flags: UInt) -> [Modifier] {
            var modifiers: [Modifier] = []
            if flags & Modifier.capsLock.rawValue > 0 {
                modifiers.append(.capsLock)
            }
            if flags & Modifier.shift.rawValue > 0 {
                modifiers.append(.shift)
            }
            if flags & Modifier.control.rawValue > 0 {
                modifiers.append(.control)
            }
            if flags & Modifier.option.rawValue > 0 {
                modifiers.append(.option)
            }
            if flags & Modifier.command.rawValue > 0 {
                modifiers.append(.command)
            }
            return modifiers
        }
    }
}

extension NSObject: NSEvent_Private { }

@objc private protocol NSEvent_Private {
    @objc(addLocalMonitorForEventsMatchingMask:handler:) optional static func addLocalMonitorForEvents(matching mask: CUnsignedLongLong, handler block: @escaping (NSObject) -> AnyObject?) -> Any?
    @objc optional static func removeMonitor(_ monitor: Any)
    
    @objc optional var type: UInt { get }
    @objc optional var keyCode: Int { get }
    @objc optional var characters: String { get }
    @objc optional var modifierFlags: UInt { get }
}
