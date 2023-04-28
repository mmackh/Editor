//
//  Editor.Container.swift
//  Magma
//
//  Created by Maximilian Mackh on 15.02.23.
//

import Foundation
import BaseComponents

extension Editor {
    class Container {
        enum Delete {
            case backward
            case forward
        }
        
        enum Update: Codable, Equatable {
            case none
            case reload(index: Int)
            case reloadVisible
            case reloadAll
        }
        
        struct Line {
            let idx: Int
            let length: Int
        }
        
        var strategy: Indentation.Strategy = .init(kind: .spaces, count: 4)
        
        var lines: [String] = []
        
        var selectAllPosition: Position {
            let lastIdx: Int = lines.count - 1
            let lastLine: String = lines[lastIdx]
            let position: Position = .init(row: 0, column: 0).with(selectionTo: .init(row: lastIdx, column: lastLine.count))
            position.visibilityAdjustmentBehaviour = .none
            return position
        }
        
        let _onUpdate: (_ update: Update, _ position: Position)->()
        
        init(onUpdateHandler: @escaping (_ update: Update, _ position: Position)->()) {
            self._onUpdate = onUpdateHandler
        }
        
        var session: Session? {
            didSet {
                lines.removeAll()
                lines = (session?.text ?? "").separatedByNewlines()
                if lines.count == 0 {
                    lines.append("")
                }
                
                self.strategy = session?.indentationStrategy ?? .detect(in: Array(lines.prefix(50)))
                
                self.registerUpdate(.reloadAll, position: session?.position ?? .zero)
            }
        }
        
        var string: String {
            lines.joined(separator: "\n")
        }
        
        enum Operation: Codable {
            case read(position: Position)
            case delete(position: Position, length: Int)
            case newline(position: Position)
            case insert(position: Position, value: String)
            case replace(position: Position, value: String)
            case indent(position: Position, offset: Int)
            case highlight(position: Position)
            case move(position: Position)
        }
        
        struct Behaviour: OptionSet {
            let rawValue: Int
            
            static let increaseIndentationAfterOpenBrace: Behaviour = Behaviour(rawValue: 1 << 0)
            static let retainIndentationOfPerviousLine: Behaviour = Behaviour(rawValue: 1 << 1)
            static let decrementIndentationLevelWithBackspace: Behaviour = Behaviour(rawValue: 1 << 2)
            static let closeCurleyBrackets: Behaviour = Behaviour(rawValue: 1 << 3)
            static let closeRoundBrackets: Behaviour = Behaviour(rawValue: 1 << 4)
            static let closeSquareBrackets: Behaviour = Behaviour(rawValue: 1 << 5)
            static let closeQuotationMarks: Behaviour = Behaviour(rawValue: 1 << 6)
            static let preventDuplicateCharacterEntry: Behaviour = Behaviour(rawValue: 1 << 7)
            
            static let `default`: Behaviour = [
                .increaseIndentationAfterOpenBrace,
                .retainIndentationOfPerviousLine,
                .decrementIndentationLevelWithBackspace,
                .closeCurleyBrackets,
                .closeRoundBrackets,
                .closeSquareBrackets,
                .closeQuotationMarks,
                .preventDuplicateCharacterEntry,
            ]
        }
        
        var behaviour: Behaviour = .default
        
        enum Initiator: Codable {
            case input
            case undo
            case redo
        }
        
        struct Result: Codable {
            let operation: Operation
            let undo: [Operation]
            
            let update: Update
            
            let updatedPosition: Position
            let output: String
        }
        
        @discardableResult
        func performOperation(_ operation: Operation, initiator: Initiator = .input) -> Result? {
            
            switch operation {
            case .read(let position):
                guard let endPosition: Position = position.currentSelectionEndPosition else { return nil }
                
                let selection: Position.Selection = .init(position, endPosition)
                let selectedRows: [Int] = position.getSelectedIndicies()
                
                let maxIdx: Int = selectedRows.count - 1
                var isStart: Bool = false
                var isEnd: Bool = false
                
                var string: String = ""
                
                for (idx, row) in selectedRows.enumerated() {
                    let line: String = lines[row]
                    isStart = idx == 0
                    isEnd = idx == maxIdx
                    
                    if isStart && isEnd {
                        let startIndex: String.Index = line.index(utf16Offset: selection.start.column)
                        let endIndex: String.Index = line.index(utf16Offset: selection.end.column)
                        string += line[startIndex..<endIndex]
                        break
                    }
                    
                    if isStart {
                        let startIndex: String.Index = line.index(utf16Offset: selection.start.column)
                        string += line.suffix(from: startIndex) + "\n"
                    } else if isEnd {
                        let endIndex: String.Index = line.index(utf16Offset: selection.end.column)
                        string += line.prefix(upTo: endIndex)
                    } else {
                        string += line + "\n"
                    }
                }
                
                return .init(operation: operation, undo: [], update: .none, updatedPosition: position, output: string)
            case .delete(let position, let length):
                if length == 0 { return nil }
                
                let isLengthGreaterThanOne: Bool = abs(length) > 1
                
                if position.isSelection || isLengthGreaterThanOne {
                    if position.isSelection == false {
                        position.currentSelectionEndPosition = calculateSafePositionOffset(at: position, length: length)
                    }
                    return performOperation(.replace(position: position, value: ""), initiator: initiator)
                }
                
                if position.row == 0 && position.column == 0 && length < 0 { return nil }
                
                let line: String = lines[position.row]
                
                let splitIndex: String.Index = line.index(utf16Offset: position.column)
                
                if position.column == 0 && length < 0 {
                    let suffix: Substring = line.suffix(from: splitIndex)
                    
                    let previousRow = position.row - 1
                    let previousLine: String = lines[previousRow]
                    
                    let mergedLine = previousLine + suffix
                    lines[previousRow] = mergedLine
                    lines.remove(at: position.row)
                    
                    let updatedPosition: Position = .init(row: previousRow, column: previousLine.utf16.count)
                    
                    let result: Result = .init(operation: operation, undo: [
                        .newline(position: updatedPosition)
                    ], update: .reloadVisible, updatedPosition: updatedPosition, output: "")
                    
                    if initiator == .input {
                        registerUndo(result)
                    }
                    
                    return result
                } else if length > 0 && position.column >= line.utf16.count {
                    let nextRow = position.row + 1
                    if nextRow > lines.count - 1 { return nil }
                    
                    let nextLine: String = lines[nextRow]
                    lines[position.row] = line + nextLine
                    lines.remove(at: nextRow)
                    
                    let highlightPosition: Position = position.with(selectionTo: .init(row: nextRow, column: 0))
                    
                    let result: Result = .init(operation: operation, undo: [
                        .newline(position: position),
                        .highlight(position: highlightPosition)
                    ], update: .reloadVisible, updatedPosition: position, output: "")
                    
                    if initiator == .input {
                        registerUndo(result)
                    }
                } else {
                    var mutableLine: String = line
                    
                    let character: String = String(mutableLine.remove(at: length > 0 ? splitIndex : line.index(before: splitIndex)))
                    lines[position.row] = mutableLine
                    
                    let updatedPosition: Position = .init(row: position.row, column: position.column - (length > 0 ? 0 : character.utf16.count))
                    
                    var undo: [Operation] = [
                        .insert(position: updatedPosition, value: character)
                    ]
                    if length > 0 {
                        undo.append(.move(position: position))
                    }
                    let result: Result = .init(operation: operation, undo: undo, update: .reload(index: updatedPosition.row), updatedPosition: updatedPosition, output: "")
                    
                    if initiator == .input {
                        registerUndo(result)
                    }
                    
                    return result
                }
                break
            case .newline(let position):
                if position.isSelection {
                    return performOperation(.replace(position: position, value: "\n"), initiator: initiator)
                }
                let line: String = lines[position.row]
                let splitIndex: String.Index = line.index(utf16Offset: position.column)
                let prefix: Substring = line.prefix(upTo: splitIndex)
                var suffix: String = String(line.suffix(from: splitIndex))
                
                var indentation = line.indentionation(strategy: strategy)
                
                if initiator == .input {
                    if prefix.last == "{" && behaviour.contains(.increaseIndentationAfterOpenBrace) {
                        if suffix.first == "}" {
                            performOperation(.insert(position: position, value: "\n" + indentation.offset(by: 1).render("")  + "\n" + indentation.render("")))
                            registerUpdate(.none, position: .init(row: position.row + 1, column: indentation.offset(by: 1).count))
                            return nil
                        } else {
                            indentation = indentation.offset(by: 1)
                            suffix = indentation.render(suffix)
                        }
                    } else if line.hasSuffix("public:") || line.hasSuffix("private:") {
                        indentation = indentation.offset(by: 1)
                        suffix = indentation.render(suffix)
                    } else if behaviour.contains(.retainIndentationOfPerviousLine) {
                        suffix = indentation.render(suffix)
                    }
                }
                
                let updatedPosition: Position = .init(row: position.row + 1, column: indentation.count)
                
                lines[position.row] = String(prefix)
                lines.insert(suffix, at: updatedPosition.row)
                
                let result: Result = .init(operation: operation, undo: [
                    .delete(position: updatedPosition, length: -(1 + indentation.count))
                ], update: .reloadVisible, updatedPosition: updatedPosition, output: "")
                
                if initiator == .input {
                    registerUndo(result)
                }
                
                return result
            case .insert(let position, let value):
                if position.isSelection {
                    return performOperation(.replace(position: position, value: value), initiator: initiator)
                }
                
                var line: String = lines[position.row]
                let insertIdx: String.Index = line.index(utf16Offset: position.column)
                
                if value.rangeOfCharacter(from: .newlines) != nil {
                    let prefix: Substring = line.prefix(upTo: insertIdx)
                    let suffix: Substring = line.suffix(from: insertIdx)
                    
                    let lines: [String] = value.separatedByNewlines()
                    let maxIdx: Int = lines.count - 1
                    var updatedRow: Int = position.row
                    var updatedColumn: Int = position.column
                    
                    for (idx, line) in lines.enumerated() {
                        if idx == 0 {
                            self.lines[position.row] = prefix + line
                            continue
                        } else if idx == maxIdx {
                            self.lines.insert(line + suffix, at: position.row + idx)
                            updatedColumn = line.utf16.count
                        } else {
                            self.lines.insert(line, at: position.row + idx)
                        }
                        updatedRow += 1
                    }
                    
                    let updatedPosition: Position = .init(row: updatedRow, column: updatedColumn)
                    
                    let result: Result = .init(operation: operation, undo: [
                        .delete(position: updatedPosition, length: -value.utf16.count)
                    ], update: .reloadVisible, updatedPosition: updatedPosition, output: "")
                    
                    if initiator == .input {
                        registerUndo(result)
                    }
                    
                    return result
                } else {
                    var transformedPosition: Position?
                    var transformedValue: String = value
                    
                    let length: Int = line.count
                    
                    if initiator == .input {
                        if position.column == length {
                            if value == "{", behaviour.contains(.closeCurleyBrackets) {
                                transformedValue = "{}"
                                transformedPosition = position.offsetBy(row: 0, column: 1)
                            } else if value == "(", behaviour.contains(.closeRoundBrackets) {
                                transformedValue = "()"
                                transformedPosition = position.offsetBy(row: 0, column: 1)
                            } else if value == "[", behaviour.contains(.closeSquareBrackets) {
                                transformedValue = "[]"
                                transformedPosition = position.offsetBy(row: 0, column: 1)
                            } else if value == "\"", behaviour.contains(.closeQuotationMarks) {
                                transformedValue = "\"\""
                                transformedPosition = position.offsetBy(row: 0, column: 1)
                            }
                        }
                        
                        if position.column == length - 1, behaviour.contains(.preventDuplicateCharacterEntry), let lastCharacter = line.last {
                            if lastCharacter == "}" && value == "}" {
                                registerUpdate(.none, position: position.offsetBy(row: 0, column: 1))
                                return nil
                            }
                            if lastCharacter == ")" && value == ")" {
                                registerUpdate(.none, position: position.offsetBy(row: 0, column: 1))
                                return nil
                            }
                            if lastCharacter == "]" && value == "]" {
                                registerUpdate(.none, position: position.offsetBy(row: 0, column: 1))
                                return nil
                            }
                            if lastCharacter == "\"" && value == "\"" {
                                registerUpdate(.none, position: position.offsetBy(row: 0, column: 1))
                                return nil
                            }
                        }
                    }
                    
                    line.insert(contentsOf: transformedValue, at: insertIdx)
                    lines[position.row] = line
                    
                    let updatedPosition: Position = .init(row: position.row, column: position.column + transformedValue.utf16.count)
                    
                    if initiator == .input {
                        let token = seekToken(at: position)
                        updatedPosition.currentTokenStore = token?.0.isEmpty == true ? nil : token
                    }
                    
                    let result: Result = .init(operation: operation, undo: [
                        .delete(position: updatedPosition, length: -transformedValue.utf16.count)
                    ], update: .reload(index: updatedPosition.row), updatedPosition: updatedPosition, output: "")
                    
                    if initiator == .input {
                        registerUndo(result)
                        
                        if let transformedPosition = transformedPosition {
                            registerUpdate(.none, position: transformedPosition)
                        } else {
                            session?.assistant?.invalidate(invalidation: .full(source: string))
                        }
                    } else {
                        updatedPosition.currentTokenStore = nil
                    }
                    
                    return result
                }
            case .replace(let position, let value):
                if !position.isSelection { return nil }
                
                guard let endPosition: Position = position.currentSelectionEndPosition else { return nil }
                
                let selection: Position.Selection = .init(position, endPosition)
                let selectedRows: [Int] = position.getSelectedIndicies()
                
                let maxIdx: Int = selectedRows.count - 1
                var isStart: Bool = false
                var isEnd: Bool = false
                
                var string: String = ""
                
                var prefix: String = ""
                var suffix: String = ""
                var rowIndiciesToRemove: [Int] = []
                
                for (idx, row) in selectedRows.enumerated() {
                    var line: String = lines[row]
                    isStart = idx == 0
                    isEnd = idx == maxIdx
                    
                    if isStart && isEnd {
                        let startIndex: String.Index = line.index(utf16Offset: selection.start.column)
                        let endIndex: String.Index = line.index(utf16Offset: selection.end.column)
                        
                        string += line[startIndex..<endIndex]
                        
                        line.removeSubrange(.init(uncheckedBounds: (startIndex, endIndex)))
                        lines[row] = line
                        break
                    }
                    
                    if isStart {
                        let startIndex: String.Index = line.index(utf16Offset: selection.start.column)
                        string += line.suffix(from: startIndex) + "\n"
                        prefix = String(line.prefix(upTo: startIndex))
                    } else if isEnd {
                        let endIndex: String.Index = line.index(utf16Offset: selection.end.column)
                        string += line.prefix(upTo: endIndex)
                        suffix = String(line.suffix(from: endIndex))
                        rowIndiciesToRemove.append(row)
                    } else {
                        string += line + "\n"
                        rowIndiciesToRemove.append(row)
                    }
                }
                
                if rowIndiciesToRemove.count > 0 {
                    lines[selectedRows.first!] = prefix + suffix
                    lines.removeSubrange(rowIndiciesToRemove.first!...rowIndiciesToRemove.last!)
                }
                
                let updatedPosition: Position = selection.start.withoutSelection()
                var insertPosition: Position? = nil
                
                var undo: [Operation] = []
                
                if value.count > 0 {
                    if let result = performOperation(.insert(position: updatedPosition, value: value), initiator: .undo) {
                        undo.append(contentsOf: result.undo)
                        insertPosition = result.updatedPosition
                    }
                }
                
                undo.append(.insert(position: updatedPosition, value: string))
                undo.append(.highlight(position: position))
                
                let result: Result = .init(operation: operation, undo: undo, update: .reloadVisible, updatedPosition: insertPosition ?? updatedPosition, output: "")
                
                if initiator == .input {
                    registerUndo(result)
                }
                
                return result
            case .indent(let position, let offset):
                var updatedPosition: Position = position
                
                var undoSteps: [Operation] = []
                let indicies: [Int] = position.isSelection ? position.getSelectedIndicies() : [position.row]
                
                let isMultilineSelection = indicies.count > 1
                
                for (idx, row) in indicies.enumerated() {
                    let line = lines[row]
                    let indentation: Indentation = line.indentionation(strategy: strategy)
                    
                    if indentation.level == 0 && offset < 0 { continue }
                    
                    let updatedIndentation = indentation.offset(by: offset)
                    self.lines[row] = updatedIndentation.render(line)
                    
                    undoSteps.append(.indent(position: .init(row: row, column: 0), offset: -offset))
                    
                    if idx == 0 {
                        updatedPosition = .init(row: row, column: position.column + (updatedIndentation.level - indentation.level) * indentation.strategy.count)
                    } else if idx == indicies.count - 1 {
                        
                    }
                }
                
                let result: Result = .init(operation: operation, undo: undoSteps, update: .reloadVisible, updatedPosition: updatedPosition, output: "")
                
                if initiator == .input {
                    registerUndo(result)
                }
                return result
            case .highlight(let position):
                self.registerUpdate(.none, position: position)
            case .move(let position):
                self.registerUpdate(.none, position: position)
            }
            
            return nil
        }
        
        func registerUpdate(_ update: Update, position: Position, character: Character? = nil) {
            if update != .none {
                session?.assistant?.invalidate(invalidation: .full(source: self.lines.joined(separator: "\n")))
            }
            _onUpdate(update, position)
        }
        
        private func registerUndo(_ result: Result) {
            session?.undoStack.append(result)
            self.registerUpdate(result.update, position: result.updatedPosition)
        }
        
        func undo() {
            guard let result: Result = session?.undoStack.popLast() else { return }
            var updatedPosition: Position?
            for undo in result.undo {
                updatedPosition = performOperation(undo, initiator: .undo)?.updatedPosition
                
                if case .highlight(let position) = undo {
                    updatedPosition = position
                }
                
                if case .move(let position) = undo {
                    updatedPosition = position
                }
            }
            
            if let updatedPosition = updatedPosition {
                self.registerUpdate(result.update, position: updatedPosition)
            }
        }
        
        func redo() {
            
        }
        
        func calculateSafePositionOffset(at position: Position, length: Int) -> Position {
            let maxRowIdx: Int = lines.count - 1
            var row: Int = position.row
            var column: Int = position.column
            
            let isBackwards: Bool = length < 0
            
            var line: String = lines[row]
            var lineCount: Int = isBackwards ? line.utf16.count : line.utf16.count + 1
            var length: Int = abs(length)
            
            while length > 0 {
                let isLineEnd: Bool = isBackwards ? column == 0 : column + 1 >= lineCount
                
                if isLineEnd {
                    if isBackwards, row == 0 {
                        break
                    }
                    if isBackwards == false, row >= maxRowIdx {
                        break
                    }
                    
                    length -= 1
                    row += isBackwards ? -1 : 1
                    
                    line = lines[row]
                    lineCount = line.utf16.count
                    column = isBackwards ? lineCount : 0
                    
                    continue
                }
                
                if isBackwards {
                    column -= 1
                    length -= 1
                } else {
                    column += 1
                    length -= 1
                }
            }
            
            return .init(row: row, column: column)
        }
        
        func characterString(at position: Position) -> String? {
            if position.column < 0 { return nil }
            let line = lines[position.row]
            if position.column >= line.utf16.count { return nil }
            let index: String.Index = line.index(utf16Offset: position.column)
            return String(line[index])
        }
        
        func line(for row: Int) -> String? {
            if row < 0 { return nil }
            if row >= lines.count { return nil }
            return lines[row]
        }
        
        func seekToken(at position: Position, boundaries: [Character] = [" ",":",".",",",";","!","?","*","&","{","}","(",")","[","]","\"","\'","<",">"]) -> (String,Position)? {
            
            let line: String = lines[position.row]
            
            if line.utf16.count <= position.column { return nil }
            
            var result: String = ""
            var utf16Idx: Int = 0
            
            var startColumn: Int = 0
            var endColumn: Int?
            
            for character in line {
                defer {
                    utf16Idx += character.utf16.count
                }
                if boundaries.contains(character) {
                    if utf16Idx >= position.column {
                        endColumn = utf16Idx
                        break
                    }
                    result.removeAll()
                } else {
                    if result.isEmpty {
                        startColumn = utf16Idx
                    }
                    result.append(character)
                }
            }
            
            if result.isEmpty == false && endColumn == nil {
                endColumn = line.utf16.count
            }
            
            if result == "" {
                return nil
            }
            
            if let endColumn = endColumn {
                return (result,.init(row: position.row, column: startColumn).with(selectionTo: .init(row: position.row, column: endColumn)))
            }
            
            return nil
        }
    }
}

fileprivate extension String {
    func index(utf16Offset: Int) -> String.Index {
        if utf16Offset == 0 {
            return startIndex
        }
        if utf16Offset >= utf16.count {
            return endIndex
        }
        return rangeOfComposedCharacterSequence(at: .init(utf16Offset: utf16Offset, in: self)).lowerBound
    }
    
    func characterIndex(utf16Offset: Int) -> (Character, String.Index) {
        let index = self.index(utf16Offset: utf16Offset)
        return (self[index], index)
    }
    
    func separatedByNewlines() -> [String] {
        var lines: [String] = []
        (self as NSString).enumerateLines { line, stop in
            lines.append(line)
        }
        if self.last?.isNewline == true {
            lines.append("")
        }
        return lines
    }
}
