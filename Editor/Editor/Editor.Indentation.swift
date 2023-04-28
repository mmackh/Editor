//
//  Editor.Indentation.swift
//  Magma
//
//  Created by Maximilian Mackh on 15.02.23.
//

import Foundation

extension Editor {
    struct Indentation {
        struct Strategy: Codable {
            let kind: Kind
            let count: Int
            
            static func detect(in lines: [String], fallback: Strategy = .init(kind: .spaces, count: 2)) -> Strategy {
                var bestGuess: (Kind?, Int) = (.spaces, 4)
                lines.forEach { line in
                    let indentation = line.measureIndentation()
                    if indentation.1 > 0 && indentation.1 <= bestGuess.1 {
                        bestGuess = indentation
                    }
                }
                if let kind = bestGuess.0, bestGuess.1 <= fallback.count {
                    return .init(kind: kind, count: bestGuess.1)
                }
                return fallback
            }
        }
        
        enum Kind: String, Codable {
            case spaces = " "
            case tab = "\t"
        }
        
        let strategy: Indentation.Strategy
        let level: Int
        
        var count: Int {
            level * strategy.count
        }

        func offset(by level: Int) -> Indentation {
            .init(strategy: strategy, level: max(0, self.level + level))
        }

        func render(_ string: String) -> String {
            String(repeating: strategy.kind.rawValue, count: count) + string.removeIndentation()
        }
    }
}

extension String {
    func measureIndentation() -> (Editor.Indentation.Kind?, Int) {
        var kind: Editor.Indentation.Kind?
        var count: Int = 0
        for character in self.utf8 {
            if character == 0x20 {
                kind = .spaces
                count += 1
                continue
            }
            if character == 0x09 {
                kind = .tab
                count += 1
                continue
            }
            break
        }
        return (kind, count)
    }
    
    func removeIndentation() -> String {
        String(drop(while: { $0.isWhitespace }))
    }
    
    func indentionation(strategy: Editor.Indentation.Strategy) -> Editor.Indentation {
        return .init(strategy: strategy, level: measureIndentation().1 / strategy.count)
    }
}
