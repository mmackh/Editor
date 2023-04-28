//
//  Editor.TextInput.swift
//  Magma
//
//  Created by Maximilian Mackh on 19.02.23.
//

import UIKit
import BaseComponents

extension Editor {
    class TextInput: UIView {
        class Field: UITextField, UITextFieldDelegate {
            enum Action {
                case newline
                case indent
                case unindent
                case undo
                case redo
                case copy
                case cut
                case paste
                case selectAll
                case toggleComment
                case escapeKey
            }
            
            var caretHeight: CGFloat = -1
            
            var textInsertionHandler: ((_ text: String)->())?
            var textDeletionHandler: ((_ delete: Keyboard.Event.Delete)->())?
            
            var textFieldActionHandler: ((_ action: Action)->())?
            
            var textFieldNavigationHandler: ((_ arrow: Keyboard.Event.Arrow)->())?
            
            var modifierKeyPressStateDidChange: ((_ modifierKey: Keyboard.Modifier, _ isEnabled: Bool)->())?
            
            var isShiftKeyPressed: Bool = false {
                didSet {
                    if oldValue != isShiftKeyPressed {
                        modifierKeyPressStateDidChange?(.shift, isShiftKeyPressed)
                    }
                }
            }
            var isOptionKeyPressed: Bool = false {
                didSet {
                    if oldValue != isOptionKeyPressed {
                        modifierKeyPressStateDidChange?(.option, isOptionKeyPressed)
                    }
                }
            }
            var isCommandKeyPressed: Bool = false {
                didSet {
                    if oldValue != isCommandKeyPressed {
                        modifierKeyPressStateDidChange?(.command, isCommandKeyPressed)
                    }
                }
            }
            
            lazy var keyboard: Keyboard? = .init(matching: [.keyDown, .keyUp, .flagsChanged]) { [unowned self] event in
                if self.isFirstResponder == false {
                    return event
                }
                
                if event.kind == .keyDown {
                    if let delete = event.delete {
                        self.textDeletionHandler?(delete)
                        return event
                    }
                    if let arrow = event.arrow {
                        self.textFieldNavigationHandler?(arrow)
                        return event
                    }
                    
                    if event.modifiers == [.command] {
                        if event.characters == "/" {
                            self.textFieldActionHandler?(.toggleComment)
                        }
                    }
                    
                    if event.isEscape {
                        self.textFieldActionHandler?(.escapeKey)
                    }
                }
                
                if event.kind == .flagsChanged {
                    let modifiers: [Keyboard.Modifier] = event.modifiers
                    isShiftKeyPressed = modifiers.contains(.shift)
                    isOptionKeyPressed = modifiers.contains(.option)
                    isCommandKeyPressed = modifiers.contains(.command)
                }
                
                return event
            }
            
            lazy var _keyCommands: [UIKeyCommand] = {
                let commands: [(String, UIKeyModifierFlags)] = [
                    ("\t", []),
                    ("\t", [.shift]),
                    ("[", [.command]),
                    ("]", [.command]),
                ]
                let selector: Selector = #selector(keyCommandPressed(_:))
                return commands.map { (command, modifier) in
                    let keyCommand: UIKeyCommand = .init(input: command, modifierFlags: modifier, action: selector)
                    keyCommand.wantsPriorityOverSystemBehavior = true
                    return keyCommand
                }
            }()
            
            init() {
                super.init(frame: .zero)
                
                autocorrectionType = .no
                autocapitalizationType = .none
                
                delegate = self
                
                _ = keyboard
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override func caretRect(for position: UITextPosition) -> CGRect {
                if caretHeight > 0 {
                    return .init(x: 0, y: 0, width: .onePixel * 2, height: caretHeight)
                }
                return super.caretRect(for: position)
            }
            
            override func layoutSubviews() {
                super.layoutSubviews()
                
                if isFirstResponder {
                    super.selectAll(nil)
                }
            }
            
            override var keyCommands: [UIKeyCommand]? {
                _keyCommands
            }
            
            @objc func keyCommandPressed(_ command: UIKeyCommand) {
                switch command.input ?? "" {
                case "\t":
                    if command.modifierFlags == .shift {
                        textFieldActionHandler?(.unindent)
                    } else {
                        textFieldActionHandler?(.indent)
                    }
                    break
                case "]":
                    textFieldActionHandler?(.indent)
                case "[":
                    textFieldActionHandler?(.unindent)
                default: break
                }
            }
            
            func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
                if string.isEmpty {
                    print("delete forward?")
                    return false
                }

                if string == "\n" {
                    textFieldActionHandler?(.newline)
                    return false
                }

                textInsertionHandler?(string)
                return false
            }
            
            override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
                switch action {
                case #selector(UIResponderStandardEditActions.copy(_:)),
                     #selector(UIResponderStandardEditActions.paste(_:)),
                     #selector(UIResponderStandardEditActions.cut(_:)),
                     #selector(UIResponderStandardEditActions.selectAll(_:)):
                    return true
                default:
                    return super.canPerformAction(action, withSender: sender)
                }
            }
            
            @objc func undo(_ : Any) {
                textFieldActionHandler?(.undo)
            }
            
            @objc func redo(_ : Any) {
                textFieldActionHandler?(.redo)
            }
            
            func textFieldShouldClear(_ textField: UITextField) -> Bool {
                return true
            }
            
            override func copy(_ sender: Any?) {
                textFieldActionHandler?(.copy)
            }
            
            override func cut(_ sender: Any?) {
                textFieldActionHandler?(.cut)
            }
            
            override func paste(_ sender: Any?) {
                textFieldActionHandler?(.paste)
            }
            
            override func selectAll(_ sender: Any?) {
                textFieldActionHandler?(.selectAll)
            }
            
            override func becomeFirstResponder() -> Bool {
                keyboard?.isEnabled = true
                return super.becomeFirstResponder()
            }
            
            override func resignFirstResponder() -> Bool {
                keyboard?.isEnabled = false
                return super.resignFirstResponder()
            }
        }
        
        var field: Field = .init()
        
        init() {
            super.init(frame: .zero)
            field.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(field)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override var canBecomeFirstResponder: Bool {
            true
        }
        
        @discardableResult
        override func becomeFirstResponder() -> Bool {
            field.becomeFirstResponder()
        }
        
        @discardableResult
        override func resignFirstResponder() -> Bool {
            field.resignFirstResponder()
        }
        
        deinit {
        }
    }
}

extension Keyboard.Event {
    enum Arrow: Int {
        case left = 123
        case right = 124
        case down = 125
        case up = 126
    }
    
    enum Delete: Int {
        case backward = 51
        case forward = 117
    }
    
    var arrow: Arrow? {
        .init(rawValue: keyCode)
    }
    
    var delete: Delete? {
        .init(rawValue: keyCode)
    }
    
    var isEscape: Bool {
        keyCode == 53
    }
}
