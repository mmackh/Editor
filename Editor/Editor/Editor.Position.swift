//
//  Editor.Position.swift
//  Magma
//
//  Created by Maximilian Mackh on 15.02.23.
//

import Foundation
import BaseComponents

extension Editor {
    class Position: Codable, Equatable, CustomDebugStringConvertible, Comparable {
        enum DocumentVisibilityAdjustementBehaviour: Codable {
            case none
            case contentOffset
            case followCursor
            case scrollToLine
        }
        
        let row: Int
        let column: Int
        
        var currentSelectionEndPosition: Position?
        var isSelection: Bool {
            currentSelectionEndPosition != nil
        }
        var isMultilineSelection: Bool {
            guard let endPosition = currentSelectionEndPosition else { return false }
            let min = min(endPosition.row, row)
            let max = max(endPosition.row, row)
            return max - min > 0
        }
        
        var visibilityAdjustmentBehaviour: DocumentVisibilityAdjustementBehaviour = .none
        
        @TransientCodable
        var currentTokenStore: (String, Position)?
        
        var indexPath: IndexPath {
            .init(item: row, section: 0)
        }
        
        var selection: Selection? {
            guard let endPosition = currentSelectionEndPosition else { return nil }
            return .init(.init(row: row, column: column), .init(row: endPosition.row, column: endPosition.column))
        }
        
        var readableDescription: String {
            "Line: \(row + 1) Col: \(column + 1)"
        }
        
        init(row: Int, column: Int) {
            self.row = row
            self.column = column
        }
        
        static var zero: Position {
            .init(row: 0, column: 0)
        }
        
        func offsetBy(row: Int, column: Int) -> Position {
            if self.row == 0 && row < 0 { return self }
            var targetColumn: Int = self.column + column
            if targetColumn < 0 {
                targetColumn = 0
            }
            let position: Position = .init(row: self.row + row, column: targetColumn)
            position.visibilityAdjustmentBehaviour = visibilityAdjustmentBehaviour
            return position
        }
        
        func with(selectionTo position: Position) -> Position {
            let start: Position = .init(row: row, column: column)
            start.currentSelectionEndPosition = position
            return start
        }
        
        func withoutSelection() -> Position {
            .init(row: row, column: column)
        }
        
        func isInSelection(idx: Int) -> Bool {
            guard let endPosition = currentSelectionEndPosition else { return false }
            let min = min(endPosition.row, row)
            let max = max(endPosition.row, row)
            return min <= idx && idx <= max
        }
        
        func getSelectedIndexPaths(section: Int = 0) -> [IndexPath] {
            getSelectedIndicies().map { idx in
                .init(row: idx, section: section)
            }
        }
        
        func getSelectedIndicies() -> [Int] {
            guard let endPosition = currentSelectionEndPosition else { return [] }
            var indicies: [Int] = []
            let min = min(row, endPosition.row)
            let max = max(row, endPosition.row)
            for i in min...max {
                indicies.append(i)
            }
            return indicies
        }
        
        static func ==(lhs: Position, rhs: Position) -> Bool {
            return lhs.row == rhs.row && lhs.column == rhs.column
        }
        
        static func < (lhs: Editor.Position, rhs: Editor.Position) -> Bool {
            if lhs.row == rhs.row {
                return lhs.column < rhs.column
            }
            return lhs.row < rhs.row
        }
        
        var debugDescription: String {
            "[Position] \(row):\(column)"
        }
        
        struct Selection: CustomDebugStringConvertible {
            let start: Position
            let end: Position
            
            init(_ lhs: Position, _ rhs: Position) {
                let isReverse: Bool = lhs > rhs
                start = isReverse ? rhs : lhs
                end = isReverse ? lhs : rhs
            }
            
            var debugDescription: String {
                "[Selection] - \(start) to \(end)"
            }
        }
    }
}
