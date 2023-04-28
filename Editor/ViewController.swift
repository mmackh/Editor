//
//  ViewController.swift
//  Editor
//
//  Created by Maximilian Mackh on 28.04.23.
//

import UIKit
import BaseComponents

class ViewController: UIViewController {
    lazy var editor: Editor = .init(parentViewController: self)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.build { [unowned self] in
            Equal {
                self.editor
            }
        }
        
        let session: Editor.Session = .init(text: File(bundleResource: "sample-c", extension: "txt").read(as: String.self) ?? "", position: .zero)
        session.assistant = .init(language: .c, lspConfiguration: nil)
        editor.resume(session: session)
    }

}

