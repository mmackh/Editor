//
//  Editor.UI.swift
//  Magma
//
//  Created by Maximilian Mackh on 15.02.23.
//

import UIKit

extension Editor {
    class UI {
        let UUID: String = Foundation.UUID().uuidString
        
        var gutterMinimumCharacterCount: Int = 2
        var gutterFont: UIFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        var gutterInactiveColor: UIColor = .secondaryLabel
        
        var editorFont: UIFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        var editorForegroundColor: UIColor = .dynamic(light: .hex("#586E75"), dark: .hex("#94A0A1"))
        var editorBackgroundColor: UIColor = .dynamic(light: .hex("#FDF6E3"), dark: .hex("#063642"))
        var editorLineSelectionColor: UIColor = .dynamic(light: .hex("#777777").alpha(0.1), dark: .hex("#AAAAAA").alpha(0.2))
        var editorLineSpacing: CGFloat = 5
        var editorContentInset: UIEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        var editorContentOverscroll: CGFloat = 0.3
        
        var editorLineHighlightColor: UIColor = .dynamic(light: .hex("#CCCCCC").alpha(0.2), dark: .hex("#AAAAAA").alpha(0.1))
        
        static var `default`: UI {
            .init()
        }
        
        lazy var estimatedLineHeight: CGFloat = {
            (editorLineSpacing + editorFont.lineHeight)
        }()
        
        lazy var estimatedEditorCharacterWidth: CGFloat = {
            "8".size(withAttributes: [.font : editorFont]).width
        }()
    }
}
