![Editor Window](/Screenshots/c.png?raw=true)

## Editor

Attempt at writing a code editor in UIKit for the Mac from scratch. There are many missing core features and there are occasional crashes. Writing a text editor is a humbling experience that I've spent many months on. No external dependencies, although there are inspirations from all over. Also, there's no SPM for now.

## How to Use

The central idea behind Editor is to use Sessions for state, like cursor position, text content, the undo and redo stack as well as the indentation strategy. You can attach an optional assistant to a session for highlighting, code completion, etc. Hints are used to show errors or warnings.

```swift
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
```

### Todo

- [ ] Code Completion (LSP?, libc?, clangd?, ...)
- [ ] Highlighting (TreeSitter?, LSP?, ...)
- [ ] Improve indentations (strategy, multiple lines, etc.)
- [ ] Highlight matching [] {} ()
- [ ] Redo
- [ ] ...