//
//  Editor.Assistant.Language.swift
//  Magma
//
//  Created by Maximilian Mackh on 07.03.23.
//

import Foundation

extension Editor.Assistant {
    enum Language: String {
        case c = "c"
        case cpp = "cpp"
        case unkown = ""
        
        static func language(for path: String) -> Language {
            .init(rawValue: URL(fileURLWithPath: path).pathExtension) ?? .unkown
        }
        
        var dictionary: Dictionary {
            .init(language: self)
        }
        
        class Dictionary {
            let language: Language
            
            lazy var table: [String:String] = {
                switch language {
                case .c, .cpp:
                    return [
                        "#include": "include",
                        "#import": "include",
                        "#define" : "directive",
                        "#if" : "directive",
                        "#ifdef" : "directive",
                        "#ifndef" : "directive",
                        "#else" : "directive",
                        "#elif" : "directive",
                        "#endif" : "directive",
                        "#error" : "directive",
                        "#pragma" : "directive",
                        "extern" : "typdef",
                        "typedef" : "typdef",
                        "using" : "typdef",
                        "struct" : "structure",
                        "enum" : "structure",
                        "class" : "structure",
                        "namespace" : "keyword",
                        "size_t" : "keyword",
                        "bool" : "keyword",
                        "char" : "keyword",
                        "signed" : "keyword",
                        "unsigned" : "keyword",
                        "const" : "keyword",
                        "volatile" : "keyword",
                        "byte" : "keyword",
                        "String" : "keyword",
                        "int" : "keyword",
                        "int8_t" : "keyword",
                        "int16_t" : "keyword",
                        "int32_t" : "keyword",
                        "int64_t" : "keyword",
                        "uint8_t" : "keyword",
                        "uint16_t" : "keyword",
                        "uint32_t" : "keyword",
                        "uint64_t" : "keyword",
                        "long" : "keyword",
                        "double" : "keyword",
                        "float" : "keyword",
                        "void" : "keyword",
                        "static" : "keyword",
                        "true" : "bool",
                        "false" : "bool",
                        "if" : "flow",
                        "else" : "flow",
                        "for" : "flow",
                        "while" : "flow",
                        "do" : "flow",
                        "return" : "flow",
                        "continue" : "flow",
                        "break" : "flow",
                        "||" : "flow",
                        "&&" : "flow",
                        "==" : "flow",
                        "!=" : "flow",
                        "<" : "flow",
                        ">" : "flow",
                        "<=" : "flow",
                        ">=" : "flow",
                        "=" : "assignement",
                        "|=" : "assignement",
                        "/=" : "assignement",
                        "*=" : "assignement",
                        "&=" : "assignement",
                        "%=" : "assignement",
                        "-=" : "assignement",
                        "+=" : "assignement",
                        "<<=" : "assignement",
                        ">>=" : "assignement",
                        "nil" : "nil",
                        "null" : "nil",
                        "NULL" : "nil",
                        "@mmackh" : "author",
                        "@akurutepe" : "author",
                        "sentionic" : "company",
                        "Sentionic" : "company",
                        "SENTIONIC" : "company",
                        "#TODO" : "todo",
                    ]
                case .unkown:
                    return [:]
                }
            }()
            
            init(language: Language) {
                self.language = language
            }
        }
    }
}
