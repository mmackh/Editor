//
//  Editor.Tokenizer.swift
//  Magma
//
//  Created by Maximilian Mackh on 06.03.23.
//

import Foundation

extension Editor {
    class Tokenizer {
        enum Mode: String {
            case none = "none"
            case decimal = "decimal"
            case float = "float"
            case hex = "hex"
            case inString = "inString"
            case string = "string"
            case inComment = "inComment"
            case comment = "comment"
            case inAngleBracket = "inAngleBracket"
            case angleBracket = "angleBracket"
            case punctuator = "punctuator"
        }
        
        struct Match {
            let location: Int
            let length: Int
            let token: Substring
            let mode: Mode
        }
        
        let separators: [Character]
        let numericalOperation: [Character] = [.init("+"),"-","*","%","/","="]
        
        init(separators: [Character] = [.init("."),",",":","(",")","[","]"]) {
            self.separators = separators
        }
        
        func scan(string: String, handler: (Match)->()) {
            var token: Substring = ""
            var mode: Mode = .none
            
            var column: Int = 0
            
            var firstMatch: Bool = true
            
            func match(with string: Substring) {
                let length: Int = string.utf16.count
                let location: Int = column - length
                
                handler(.init(location: location, length: length, token: token, mode: mode))
                
                firstMatch = false
            }
            
            for character in string {
                defer {
                    column += character.utf16.count
                }
                
                func reset() {
                    token.removeAll()
                    mode = .none
                }
                
                let isNumber: Bool = character.isNumber
                let isWhitespace: Bool = character.isWhitespace
                let isSeparator: Bool = separators.contains(character)
                
                if mode == .inString {
                    if character == "\"" {
                        token.append(character)
                        mode = .string
                        continue
                    }
                    token.append(character)
                    continue
                }
                
                if mode == .inComment {
                    if character.isNewline {
                        mode = .comment
                        match(with: token)
                        reset()
                        continue
                    }
                    token.append(character)
                    continue
                }
                
                if mode == .inAngleBracket {
                    if token.count == 2, token == "<=" {
                        mode = .none
                        match(with: token)
                        reset()
                        continue
                    }
                    token.append(character)
                    if character == ">" {
                        mode = .angleBracket
                    }
                    continue
                }
                
                if mode == .decimal {
                    if character == "." {
                        token += "."
                        mode = .float
                        continue
                    }
                    if character == "x" {
                        token += "x"
                        mode = .hex
                        continue
                    }
                    if !isNumber && !isWhitespace && !isSeparator {
                        match(with: token)
                        
                        token.removeAll()
                        token.append(character)
                        mode = .none
                        continue
                    }
                }
                
                if isWhitespace  || isSeparator || mode == .punctuator {
                    if token.isEmpty { continue }
                    if mode == .inString { continue }
                    
                    if mode == .inComment {
                        mode = .comment
                    }
                    
                    if mode == .inAngleBracket, token.count == 1 {
                        mode = .none
                    }
                    match(with: token)
                    reset()
                    
                    if character == ";" {
                        mode = .punctuator
                        token.append(character)
                        match(with: token)
                        reset()
                    }
                    
                    continue
                }
                
                if mode == .float, !isNumber {
                    match(with: token)
                    reset()
                }
                
                if isNumber, mode == .none {
                    if token.isEmpty {
                        mode = .decimal
                    } else if numericalOperation.contains(character) {
                        match(with: token)
                        reset()
                        token.append(character)
                        mode = .decimal
                        continue
                    }
                }
                
                if character == "\"" {
                    if mode == .inString {
                        mode = .string
                    } else {
                        if token.isEmpty {
                            mode = .inString
                        } else {
                            match(with: token)
                            reset()
                            mode = .inString
                        }
                    }
                }
                
                if token == "/" {
                    if character == "/" {
                        mode = .inComment
                    }
                    if character == "*" {
                        mode = .comment
                    }
                }
                
                if token == "*" {
                    if character == "/" {
                        mode = .comment
                    }
                }
                
                if token == "<" {
                    if character == "<" {
                        mode = .none
                    } else {
                        mode = .inAngleBracket
                    }
                }
                
                if token == "!" {
                    if character != "=" {
                        match(with: token)
                        reset()
                        token.append(character)
                        continue
                    }
                }
                
                if token == "&" {
                    if character != "&" {
                        match(with: token)
                        reset()
                        token.append(character)
                        continue
                    }
                }
                
                // pointer, e.g. char*
                if mode == .none, character == "*", token.count > 0 {
                    match(with: token)
                    reset()
                    token.append(character)
                    continue
                }
                
                if (mode == .none || mode == .punctuator), character == ";" {
                    match(with: token)
                    reset()
                    
                    mode = .punctuator
                    token.append(";")
                    continue
                }
                
                if firstMatch {
                    if character == "*" {
                        mode = .comment
                    }
                }
                
                token.append(character)
            }
            
            if !token.isEmpty {
                if mode == .inComment {
                    mode = .comment
                }
                match(with: token)
            }
        }
    }
}

