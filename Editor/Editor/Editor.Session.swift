//
//  Editor.Session.swift
//  Magma
//
//  Created by Maximilian Mackh on 15.02.23.
//

import Foundation
import BaseComponents

extension Editor {
    class Session: Codable {
        var UUID: String = Foundation.UUID().uuidString
        var createdDate: Date = Date()
        
        var userInfo: [String: String] = [:]
        
        var indentationStrategy: Indentation.Strategy?
        
        var text: String
        var position: Position
        
        @TransientCodable
        var assistant: Assistant?
        @TransientCodable
        var undoStack: [Container.Result] = []
        @TransientCodable
        var redoStack: [Container.Result] = []
        @TransientCodable
        var temporaryStore: Any?
        
        init(text: String, position: Position) {
            self.text = text
            self.position = position
        }
    }
}
