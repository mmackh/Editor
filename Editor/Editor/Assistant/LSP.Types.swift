//
//  LSP.Types.swift
//  Magma
//
//  Created by Maximilian Mackh on 12.03.23.
//

import Foundation
extension LSP {
    struct Position {
        let line: Int
        let character: Int
        
        init(position: Editor.Position) {
            self.line = position.row + 1
            self.character = position.column + 1
        }
        
        init(line: Int, character: Int) {
            self.line = line
            self.character = character
        }
        
        var dictionary: NSDictionary {
            [
                "line" : self.line,
                "character" : self.character
            ]
        }
    }
    
    struct Range {
        let start: Position
        let end: Position
        
        var dictionary: NSDictionary {
            [
                "start" : start.dictionary,
                "end" : end.dictionary
            ]
        }
    }
    
    // https://github.com/ChimeHQ/SwiftLSPClient/blob/main/SwiftLSPClient/Types/SymbolKind.swift
    public enum Symbol: Int, CaseIterable, Codable {
        case file = 1
        case module = 2
        case namespace = 3
        case package = 4
        case `class` = 5
        case method = 6
        case property = 7
        case field = 8
        case constructor = 9
        case `enum` = 10
        case interface = 11
        case function = 12
        case variable = 13
        case constant = 14
        case string = 15
        case number = 16
        case boolean = 17
        case array = 18
        case object = 19
        case key = 20
        case null = 21
        case enumMember = 22
        case `struct` = 23
        case event = 24
        case `operator` = 25
        case typeParameter = 26
        
        var string: String {
            "\(self)"
        }
    }
    
    //https://github.com/ChimeHQ/LanguageServerProtocol/blob/4ae3b11542efccc1d3b95c7bb9b6580b27666d2b/Sources/LanguageServerProtocol/LanguageFeatures/Completion.swift#L84
    public enum CompletionItemKind: Int, CaseIterable, Codable, Hashable {
        case text = 1
        case method = 2
        case function = 3
        case constructor = 4
        case field = 5
        case variable = 6
        case `class` = 7
        case interface = 8
        case module = 9
        case property = 10
        case unit = 11
        case value = 12
        case `enum` = 13
        case keyword = 14
        case snippet = 15
        case color = 16
        case file = 17
        case reference = 18
        case folder = 19
        case enumMember = 20
        case constant = 21
        case `struct` = 22
        case event = 23
        case `operator` = 24
        case typeParameter = 25
    }
}
