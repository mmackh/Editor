//
//  Editor.Assistant.swift
//  Magma
//
//  Created by Maximilian Mackh on 21.02.23.
//

import UIKit
import BaseComponents

extension Editor {
    class Assistant {
        class Theme {
            lazy var colors: [String: UIColor] = [
                "include" : .init(hex: "#859905"),
                "directive" : .init(hex: "#2AA198"),
                "comment" : .dynamic(light: .init(hex: "#93a1a1"), dark: .tertiaryLabel),
                "keyword" : .init(hex: "#859905"),
                "flow" : .label.alpha(0.8),
                "constant" : .init(hex: "#cb4b16"),
                "string" : .init(hex: "#cb4b16"),
                "decimal" : .init(hex: "#d33682"),
                "hex" : .init(hex: "#d33682"),
                "float" : .init(hex: "#d33682"),
                "nil" : .init(hex: "#d33682"),
                "label" : .init(hex: "#278BD2"),
                "bool" : .init(hex: "#2AA197"),
                "typdef" : .init(hex: "#B58901"),
                "type" : .init(hex: "#B58901"),
                "variable" : .init(hex: "#268bd2"),
                "function" : .init(hex: "#6c71c4"),
                "author" : .init(hex: "#cb4b16"),
                "company" : .label,
                "todo" : .label,
                "assignement" : .hex("#839596"),
                "structure" : .hex("#CD762F"),
                "punctuator" : .tertiaryLabel,
            ]
            
            static var solarized: Theme {
                .init()
            }
        }
        
        struct LSPConfiguration {
            let documentPathURL: URL
            let rootPath: String
            let environmentVariables: [String:String]
        }
        
        struct Suggestion: Hashable, Equatable {
            let UUID: String = Foundation.UUID().uuidString
            
            let label: String
            let score: Float
        }
        
        let language: Language
        let dictionary: Language.Dictionary
        
        let theme: Theme
        let tokenizer: Editor.Tokenizer
        
        let lspConfiguration: LSPConfiguration?
        var lspClient: LSP.Client?
        
        var highlightDictionary: [String:String] = [:]
        
        init?(language: Language, lspConfiguration: LSPConfiguration?, theme: Theme = .solarized) {
            self.lspConfiguration = lspConfiguration
            
            self.language = language
            self.dictionary = language.dictionary
            
            self.theme = theme
            self.tokenizer = .init()
            
            if let lspConfiguration = lspConfiguration {
                if [.c, .cpp].contains(language) {
                    self.lspClient = .init(.clangd, environementVariables: lspConfiguration.environmentVariables)
                    
                    self.lspClient?.message(.initialize(rootPath: lspConfiguration.rootPath), responseHandler: { [weak self] response in
                        guard let self = self else { return }
                        
                        self.redoHighlights()
                    })
                    
                    self.lspClient?.notify(.didOpen(uri: lspConfiguration.documentPathURL))
                }
            }
        }
        
        func redoHighlights() {
            guard let lspConfiguration else { return }
            
            self.lspClient?.message(.symbol(uri: lspConfiguration.documentPathURL), responseHandler: { response in
                for highlight in ((response as? [String:AnyObject])?["result"] as? [[String:AnyObject]]) ?? [] {
                    guard let name = highlight["name"] as? String, let symbolRaw = highlight["kind"] as? Int, let symbol = LSP.Symbol(rawValue: symbolRaw) else { continue }
                    self.highlightDictionary[name] = symbol.string
                }
                print(self.highlightDictionary)
            })
        }
        
        var documentVersion: Int = 1
        
        enum Invalidation {
            case full(source: String)
            case incremental(character: String, position: Position)
        }
        
        func invalidate(invalidation: Invalidation) {
            guard let lspConfiguration else { return }
            
            //LSP.isDebugLogEnabled = true
            
            switch invalidation {
            case .full(source: let source):
                self.lspClient?.notify(.didChange(uri: lspConfiguration.documentPathURL, version: documentVersion, text: source, range: nil))
            case .incremental(character: let character, position: let position):
                break
                //self.lspClient?.notify(.didChange(uri: pathURL, version: documentVersion, text: character, range: .init(start: .init(position: position.offsetBy(row: 0, column: -1)), end: .init(position: position.offsetBy(row: 0, column: character.utf16.count - 1)))))
            }
            
            documentVersion += 1
        }
        
        func suggestions(for position: Editor.Position, completionHandler: @escaping (_ suggestions: [Suggestion])->()) {
            //LSP.isDebugLogEnabled = true
            guard let lspConfiguration else { return }
            
            guard let word = position.currentTokenStore?.0, let lspClient = lspClient else { return }
            
            print("Suggestions for: ", position, word)
            
            lspClient.message(.textCompletion(uri: lspConfiguration.documentPathURL, line: position.row + 1, column: position.column + 1, triggerKind: 1, triggerCharacter: String(word.last!))) { response in
                
                var suggestions: [Suggestion] = []
                
                for item in (response as? [String:AnyObject])?["result"]?["items"] as? [[String:AnyObject]] ?? [] {
                    
                    guard let label: String = item["insertText"] as? String, let score = item["score"] as? Float, let kind = item["kind"] as? Int else { continue }
                    
//                    if kind == LSP.CompletionItemKind.keyword.rawValue {
//                        print("skip", label)
//                        continue
//                    }
                    
                    suggestions.append(.init(label: label, score: score))
                }
                
                let matches = suggestions.fuzzySearch(word) { suggestion in
                    return suggestion.label
                }
                
                DispatchQueue.main.async {
                    completionHandler(Array(matches))
                }
            }
            
        }
        
        
        func highlight(row: Int, container: Editor.Container, mutableString: NSMutableAttributedString) -> NSMutableAttributedString? {
            
            tokenizer.scan(string: mutableString.string) { match in
                var key: String?
                if match.mode == .none {
                    var lookup = String(match.token)
                    
                    if let matchedKey = self.dictionary.table[lookup] {
                        key = matchedKey
                    }
                    if let matchedKey = self.highlightDictionary[lookup] {
                        key = matchedKey
                    }
                } else if match.mode == .angleBracket {
                    key = "constant"
                } else {
                    key = match.mode.rawValue
                }
                
                if match.mode == .string {
                }
            
                if let key = key, let color = self.theme.colors[key] {
                    let range: NSRange = .init(location: match.location, length: match.length)
                    mutableString.addAttributes([.foregroundColor: color], range: range)
                    
                    if key == "flow" || key == "author" || key == "company" || key == "todo" || key == "structure" {
                        mutableString.addAttributes([.strokeWidth: -3], range: range)
                    }
                }
            }
            
            return mutableString
        }
    }
}
