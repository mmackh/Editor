//
//  Editor.swift
//  Magma
//
//  Created by Maximilian Mackh on 15.01.23.
//

import UIKit
import BaseComponents

class Editor: UIView {
    private var _currentSession: Session?
    
    let document: Document = .init()
    
    var hints: [Hint] {
        set {
            document._hintDictionary.removeAll()
            for hint in newValue {
                document._hintDictionary[hint.position.row] = hint
            }
            self.document.rebindLines()
        }
        get {
            Array(document._hintDictionary.values)
        }
    }
    
    @available(*, unavailable)
    init() {
        super.init(frame: .zero)
    }
    
    private override init(frame: CGRect) {
        super.init(frame: frame)
        
        build { [unowned self] in
            Equal {
                self.document
            }
        }
    }
    
    convenience init(parentViewController: UIViewController) {
        self.init(frame: .zero)
        
        self.document.parentViewController = parentViewController
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func becomeFirstResponder() -> Bool {
        document.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        document.resignFirstResponder()
    }
    
    func resume(session: Session) {
        if let session = _currentSession {
            if let position = document._currentPosition {
                session.position = position
            }
            session.text = document.container.lines.joined(separator: "\n")
        }
        
        _currentSession = session
        
        self.document.session = session
        _ = document.input.field.becomeFirstResponder()
    }
    
    class Document: UIView, UITableViewDelegate, UITableViewDataSource {
        class RowCell: UITableViewCell {
            class CodeLabel: UIView {
                let paragraphStyle: NSMutableParagraphStyle = {
                    let paragraphStyle: NSMutableParagraphStyle = .init()
                    paragraphStyle.alignment = .left
                    paragraphStyle.allowsDefaultTighteningForTruncation = false
                    return paragraphStyle
                }()

                var font: UIFont!
                
                var lineBreakMode: NSLineBreakMode = .byWordWrapping {
                    didSet {
                        textContainer.lineBreakMode = lineBreakMode
                    }
                }
                
                let textStorage: NSTextStorage = .init()
                let textContainer: NSTextContainer = .init()
                let layoutManager: NSLayoutManager = .init()
                
                private var lineHeightOffset: CGFloat = 0
                var index: Int = 0
                static weak var selectionPosition: Position?
                var selectionColor: UIColor!
                var didDrawSelection: Bool = false
                
                var hint: Hint?
                
                override init(frame: CGRect) {
                    super.init(frame: frame)
                    
                    backgroundColor = .clear
                    
                    textStorage.addLayoutManager(layoutManager)
                    layoutManager.addTextContainer(textContainer)
                    
                    textContainer.lineFragmentPadding = 0
                }
                
                required init?(coder: NSCoder) {
                    fatalError("init(coder:) has not been implemented")
                }
                
                func update(row: Int, with text: String?, ui: UI, container: Container, assistant: Assistant?) {
                    lineHeightOffset = (ui.estimatedLineHeight - ui.editorFont.lineHeight) / 2
                    paragraphStyle.minimumLineHeight = ui.estimatedLineHeight
                    
                    selectionColor = ui.editorLineSelectionColor
                    font = ui.editorFont
                    
                    var attributedString: NSMutableAttributedString = .init(string: text ?? "", attributes: [.font: font as Any, .paragraphStyle : paragraphStyle, .foregroundColor : ui.editorForegroundColor, .backgroundColor : selectionColor as Any])
                    
                    
                    if let assistant = assistant, let highlight = assistant.highlight(row: row, container: container, mutableString: attributedString) {
                        attributedString = highlight
                    }
                    
                    if let hint {
                        let length = attributedString.length
                        
                        if length > 0 {
                            let column = length > hint.position.column ? hint.position.column : length - 1
                            
                            attributedString.addAttributes([.underlineStyle : NSUnderlineStyle.thick.rawValue, .underlineColor : UIColor.red], range: .init(location: column, length: 1))
                        }
                    }
                    
                    textStorage.setAttributedString(attributedString)
                    
                    setNeedsDisplay()
                }
                
                override func layoutSubviews() {
                    super.layoutSubviews()
                    
                    textContainer.size = bounds.size
                    
                    setNeedsDisplay()
                }
                
                override func draw(_ rect: CGRect) {
                    super.draw(rect)
                    
                    let range: NSRange = NSRange(location: 0, length: textStorage.length)
                    
                    if let selectionPosition = CodeLabel.selectionPosition, selectionPosition.isInSelection(idx: index), let endPosition = selectionPosition.currentSelectionEndPosition {
                        var location: Int = 0
                        var length: Int = 0
                        if index == endPosition.row && index == selectionPosition.row {
                            location = min(selectionPosition.column, endPosition.column)
                            length = max(selectionPosition.column, endPosition.column) - location
                            
                            layoutManager.drawBackground(forGlyphRange: .init(location: location, length: length), at: rect.origin)
                        } else if index == selectionPosition.row || index == endPosition.row {
                            let relevantPosition: Position = index == endPosition.row ? endPosition : selectionPosition
                            let relevantOtherPosition: Position = index == selectionPosition.row ? endPosition : selectionPosition
                            
                            let isReverse: Bool = relevantPosition.row > relevantOtherPosition.row
                            
                            location = isReverse ? 0 : relevantPosition.column
                            length = isReverse ? relevantPosition.column : textStorage.length - relevantPosition.column
                            
                            if isReverse {
                                layoutManager.drawBackground(forGlyphRange: .init(location: location, length: length), at: rect.origin)
                            } else {
                                let characterRect: CGRect = layoutManager.boundingRect(forGlyphRange: .init(location: location, length: 0), in: textContainer)
                                let width: CGFloat = bounds.size.width
                                let height: CGFloat = bounds.size.height
                                selectionColor.setFill()
                                UIRectFill(.init(x: characterRect.x, y: characterRect.y, width: width - characterRect.x, height: height))
                                if height >= characterRect.size.height * 2 && characterRect.origin.y == 0 {
                                    UIRectFill(.init(x: 0, y: characterRect.size.height, width: width, height: height))
                                }
                            }
                        } else {
                            length = max(selectionPosition.column, endPosition.column)
                            
                            selectionColor.setFill()
                            UIRectFill(rect)
                        }
                        didDrawSelection = true
                    } else {
                        didDrawSelection = false
                    }
                    
                    var origin: CGPoint = rect.origin
                    origin.y = -lineHeightOffset
                    layoutManager.drawGlyphs(forGlyphRange: range, at: origin)
                }
                
                func calculateHeight(with availableWidth: CGFloat, ui: UI) -> CGFloat {
                    textContainer.size = .init(width: availableWidth, height: .infinity)
                    let usedRect: CGRect = layoutManager.usedRect(for: textContainer)
                    let rowCount: CGFloat = (usedRect.height / ui.estimatedLineHeight).rounded(.down)
                    if rowCount < 1.0 {
                        return ui.estimatedLineHeight
                    }
                    return rowCount * ui.estimatedLineHeight
                }
                
                func characterIndex(at point: CGPoint) -> Int {
                    var fractal: CGFloat = 0
                    var index = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: &fractal)
                    
                    if fractal > 0.4 {
                        let string = textStorage.string
                        let character =
                        string[.init(utf16Offset: index, in: string)]
                        index += character.utf16.count
                    }
                    return index
                }
                
                func boundingRectOfCharacter(at index: Int, ui: UI) -> CGRect {
                    let count: Int = textStorage.length
                    if count == 0 {
                        return .init(origin: .init(x: 0, y: 0), size: .init(width: ui.estimatedEditorCharacterWidth, height: height))
                    }
                    if index >= count {
                        var rect = boundingRectOfCharacter(at: count - 1, ui: ui)
                        rect.origin.x += rect.width
                        return rect
                    }
                    return layoutManager.boundingRect(forGlyphRange: .init(location: index, length: 1), in: textContainer)
                }
            }
            
            var gutterWidth: CGFloat = 0
            let gutterPaddingLeading: CGFloat = 8
            let gutterPaddingTrailing: CGFloat = 8
            let gutterLabel: UILabel = UILabel().align(.center)
            
            let content: CodeLabel = .init()
            
            static let reuseIdentifier: String = "RowCell"
            
            var characterWidth: CGFloat = 0
            
            weak var ui: UI? {
                didSet {
                    if let ui = ui, ui.UUID != oldValue?.UUID {
                        characterWidth = ui.estimatedEditorCharacterWidth
                        gutterLabel.font = ui.gutterFont
                        content.font = ui.editorFont
                        
                        selectedBackgroundView?.color(.background, ui.editorLineHighlightColor)
                    }
                }
            }
            
            var line: String!
            weak var container: Editor.Container!
            
            var hint: Hint? {
                didSet {
                    if let hint {
                        hintIndicatorView.isHidden = false
                        hintIndicatorView.backgroundColor = hint.kind.primaryColor
                    } else {
                        hintIndicatorView.isHidden = true
                    }
                }
            }
            var hintIndicatorView: UIView = UIView().cornerRadius(2)
            var onHoverIndicatorView: ((_ isActive: Bool)->())?
            
            override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
                super.init(style: style, reuseIdentifier: reuseIdentifier)
                
                color(.background, .clear)
                selectedBackgroundView = UIView()
                
                contentView.build { [unowned self] in
                    ZSplit {
                        HSplit {
                            Padding {
                                .fixed(self.gutterPaddingLeading)
                            }
                            Dynamic {
                                self.gutterLabel
                            } size: {
                                .fixed(self.gutterWidth)
                            }
                            Padding {
                                .fixed(self.gutterPaddingTrailing)
                            }
                            Percentage(100) {
                                self.content
                            }
                        }
                        HSplit {
                            Padding(5)
                            Fixed(4) {
                                let hover: UIHoverGestureRecognizer = .init { gesture in
                                    if gesture.state == .began {
                                        self.onHoverIndicatorView?(true)
                                    } else if gesture.state == .ended || gesture.state == .cancelled {
                                        self.onHoverIndicatorView?(false)
                                    }
                                }
                                self.hintIndicatorView.addGestureRecognizer(hover)
                                return self.hintIndicatorView
                            } insets: {
                                .init(vertical: 2)
                            }
                        }
                    }
                }
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func bind(line: String, container: Editor.Container, assistant: Assistant?, hint: Hint?, idx: Int, ui: UI) {
                self.line = line
                self.container = container
                
                self.hint = hint
                
                content.hint = hint
                content.index = idx
                
                self.gutterLabel.text = "\(idx + 1)"
                content.update(row: idx, with: line, ui: ui, container: container, assistant: assistant)
                self.ui = ui
            }
            
            override func setSelected(_ selected: Bool, animated: Bool) {
                super.setSelected(selected, animated: animated)
                
                gutterLabel.alpha = selected ? 1 : 0.3
                
                content.setNeedsDisplay()
            }
            
            override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
                guard let ui = ui else { return .zero }
                
                let collectionViewWidth: CGFloat = superview?.width ?? 0
                
                self.gutterWidth = 30
                let availableContentWidth: CGFloat = collectionViewWidth - gutterPaddingLeading - gutterPaddingTrailing - gutterWidth
                
                return .init(width: collectionViewWidth, height: content.calculateHeight(with: availableContentWidth, ui: ui))
            }
            
            override func layoutSubviews() {
                super.layoutSubviews()
                
                selectedBackgroundView?.alpha = CodeLabel.selectionPosition?.currentSelectionEndPosition == nil ? 1 : 0
            }
            
            /// point must be converted to local coordinate system
            func column(for point: CGPoint) -> Int {
                return content.characterIndex(at: point)
            }
            
            func inputFrame(for position: Position) -> CGRect {
                return content.convert(content.boundingRectOfCharacter(at: position.column, ui: ui!), to: superview)
            }
        }
        
        weak var parentViewController: UIViewController!
        
        lazy var tableView: TableView = {
            let tableView: TableView = TableView(frame: bounds, style: .plain)
            tableView.delegate = self
            tableView.dataSource = self
            tableView.separatorStyle = .none
            tableView.alwaysBounceVertical = true
            tableView.allowsMultipleSelection = true
            tableView.register(RowCell.self, forCellReuseIdentifier: RowCell.reuseIdentifier)
            return tableView
        }()
        
        var text: String {
            container.string
        }
        
        var onContentChange: (()->())?
        
        lazy var container: Editor.Container = Editor.Container(onUpdateHandler: { [weak self] update, position in
            guard let self = self else { return }
            
            switch update {
            case .none:
                break
            case .reload(let index):
                UIView.performWithoutAnimation {
                    let indexPath: IndexPath = .init(row: index, section: 0)
                    guard let cell = self.tableView.cellForRow(at: indexPath) as? RowCell else { return }
                    cell.bind(line: self.container.lines[index], container: self.container, assistant: self.session.assistant, hint: self._hintDictionary[index], idx: index, ui: self.ui)
                    UIView.performWithoutAnimation {
                        self.tableView.beginUpdates()
                        self.tableView.endUpdates()
                    }
                }
            case .reloadVisible:
                self.tableView.reloadData()
            case .reloadAll:
                self.tableView.reloadData()
            }
            
            if update != .none && update != .reloadAll {
                self.onContentChange?()
            }
            
            self.updatePosition(position, using: .virtual)
        })
        
        var overflowColumnHint: Int = 0
        
        lazy var input: TextInput = { [unowned self] in
            let input: TextInput = .init()
            input.field.modifierKeyPressStateDidChange = { key, isEnabled in
                if !isEnabled {
                    self.cursorGesture.cancel()
                }
            }
            input.field.textInsertionHandler = { text in
                guard let position = self._currentPosition else { return }
                
                self.container.performOperation(.insert(position: position, value: text))
            }
            input.field.textDeletionHandler = { delete in
                guard let position = self._currentPosition else { return }
                
                self.container.performOperation(.delete(position: position, length: delete == .backward ? -1 : 1))
            }
            input.field.textFieldNavigationHandler = { arrow in
                guard let position = self._currentPosition else { return }
                
                let isShiftKeyPressed = self.input.field.isShiftKeyPressed
                
                switch arrow {
                case .up:
                    if isShiftKeyPressed {
                        self.selectUp(rows: 1)
                    } else {
                        self.moveUp(rows: 1)
                    }
                case .down:
                    if isShiftKeyPressed{
                        self.selectDown(rows: 1)
                    } else {
                        self.moveDown(rows: 1)
                    }
                case .left:
                    if isShiftKeyPressed == false, let selection = position.selection {
                        self.updatePosition(selection.start, using: .keyboardHorizontalArrow)
                        return
                    }
                    
                    if position.column > 0, let character: String = self.container.characterString(at: position.offsetBy(row: 0, column: -1)) {
                        if isShiftKeyPressed {
                            self.selectLeft(columns: character.utf16.count)
                        } else {
                            self.updatePosition(position.offsetBy(row: 0, column: -character.utf16.count), using: .keyboardHorizontalArrow)
                        }
                        return
                    }
                    if isShiftKeyPressed {
                        self.selectLeft(columns: 1)
                    } else {
                        self.moveLeft(columns: 1)
                    }
                case .right:
                    if isShiftKeyPressed == false, let selection = position.selection {
                        self.updatePosition(selection.end, using: .keyboardHorizontalArrow)
                        return
                    }
                    
                    if let character: String = self.container.characterString(at: position.offsetBy(row: 0, column: 1)) {
                        if isShiftKeyPressed {
                            self.selectRight(columns: character.utf16.count)
                        } else {
                            self.updatePosition(position.offsetBy(row: 0, column: character.utf16.count), using: .keyboardHorizontalArrow)
                        }
                        return
                    }
                    if isShiftKeyPressed {
                        self.selectRight(columns: 1)
                    } else {
                        self.moveRight(columns: 1)
                    }
                }
            }
            input.field.textFieldActionHandler = { action in
                guard let position = self._currentPosition else { return }
                switch action {
                case .newline:
                    self.container.performOperation(.newline(position: position))
                case .indent:
                    self.container.performOperation(.indent(position: position, offset: 1))
                case .unindent:
                    self.container.performOperation(.indent(position: position, offset: -1))
                case .undo:
                    self.container.undo()
                case .redo:
                    self.container.redo()
                case .copy:
                    UIPasteboard.general.string = self.container.performOperation(.read(position: position))?.output
                case .cut:
                    guard let selection = position.selection else { return }
                    
                    let string: String = self.container.performOperation(.read(position: position))?.output ?? ""
                    UIPasteboard.general.string = string
                    self.container.performOperation(.delete(position: selection.end, length: -string.utf16.count))
                case .paste:
                    self.container.performOperation(.insert(position: position, value: UIPasteboard.general.string ?? ""))
                case .selectAll:
                    self.updatePosition(self.container.selectAllPosition, using: .virtual)
                case .toggleComment:
                    let rows: [Int] = position.isSelection ? position.getSelectedIndicies() : [position.row]
                    
                    for row in rows {
                        guard let line: String = self.container.line(for: row), line.isEmpty == false else { continue }
                        
                        let shouldComment: Bool = line.hasPrefix("//") == false
                        
                        if shouldComment {
                            self.container.performOperation(.insert(position: .init(row: row, column: 0), value: "//"))
                        } else {
                            self.container.performOperation(.delete(position: .init(row: row, column: 2), length: -2))
                        }
                    }
                    
                    self.container.registerUpdate(.none, position: position)
                case .escapeKey:
                    position.currentTokenStore = self.container.seekToken(at: position.offsetBy(row: 0, column: -1))
                    
                    self.session.assistant?.suggestions(for: position, completionHandler: { suggestions in
                        print(suggestions.map({ $0.label }).prefix(10).joined(separator: ", "))
                    })
                }
            }
            return input
        }()
        
        var _currentPosition: Position? = .zero {
            didSet {
                if let currentPosition = _currentPosition {
                    
                    tableView.deselectAll()
                    
                    if currentPosition.isSelection {
                        RowCell.CodeLabel.selectionPosition = currentPosition
                        
                        for position in currentPosition.getSelectedIndexPaths() {
                            tableView.selectRow(at: position, animated: false, scrollPosition: .none)
                        }
                        
                        tableView.scrollTo(position: currentPosition)
                        
                        input.alpha = 0.01
                        
                        if input.field.isFirstResponder == false {
                            input.becomeFirstResponder()
                        }
                        return
                    } else {
                        RowCell.CodeLabel.selectionPosition = nil
                        
                        tableView.selectRow(at: .init(row: currentPosition.row, section: 0), animated: false, scrollPosition: .none)
                    }
                } else {
                    tableView.deselectAll()
                }
                
                input.alpha = 1
                
                positionTrackerLabel.text = _currentPosition?.readableDescription ?? ""
                (positionTrackerLabel.superview as? SplitView)?.invalidateLayout()
                
                if oldValue == _currentPosition && oldValue?.isSelection == _currentPosition?.isSelection {
                    return
                }
                
                updateInputPosition(scroll: true)
            }
        }
        
        enum Method {
            case virtual
            case mouse
            case keyboardVerticalArrow
            case keyboardHorizontalArrow
        }
        
        func updatePosition(_ position: Position, using method: Method) {
            if method != .keyboardVerticalArrow {
                overflowColumnHint = position.column
            }
            
            if method != .virtual && input.field.isShiftKeyPressed {
                print("shiftkeypress")
                _currentPosition?.currentSelectionEndPosition = position
                _currentPosition = { _currentPosition }()
                return
            }
            
            _currentPosition = position
        }
        
        var positionTrackerLabel: UILabel = .init().align(.center).size(using: .monospacedSystemFont(ofSize: 10, weight: .medium)).color(.text, .secondaryLabel)
        
        var session: Session = .init(text: "", position: .zero) {
            didSet {
                session.position.visibilityAdjustmentBehaviour = .scrollToLine
                container.session = session
            }
        }
        
        var ui: UI = .init() {
            didSet {
                updateUI()
            }
        }
        
        var clickTimeInterval: TimeInterval = 0.4
        private var clickCountTracker: Int = 1
        private var previousCursorClickTimeInterval: TimeInterval = 0
        
        lazy var cursorGesture: UILongPressPanGestureRecognizer = UILongPressPanGestureRecognizer { [unowned self] gesture in
            if gesture.state == .cancelled { return }
            
            let point = gesture.location(in: self.tableView)
            
            let isSelecting: Bool = (gesture.state == .changed || gesture.state == .ended)

            guard let indexPath = self.tableView.indexPathForRow(at: .init(x: 0, y: point.y)), let cell = tableView.cellForRow(at: indexPath) as? RowCell else {
                // if point is > than available cells, put cursor at very end
                if isSelecting || point.y < tableView.contentInset.top {
                    return
                }
                
                let lastIdx: Int = container.lines.count - 1
                if lastIdx < 0 { return }
                let lastLine: String = container.lines[lastIdx]
                self.updatePosition(.init(row: lastIdx, column: lastLine.utf16.count), using: .mouse)
                return
            }
            
            let resolvedPosition: Position = .init(row: indexPath.row, column: cell.column(for: self.tableView.convert(point, to: cell.content)))
            
            if !isSelecting {
                let timeInterval: TimeInterval = Date().timeIntervalSinceReferenceDate
                defer {
                    previousCursorClickTimeInterval = timeInterval
                }
                if timeInterval - previousCursorClickTimeInterval < self.clickTimeInterval {
                    clickCountTracker += 1
                    if clickCountTracker == 2 {
                        // highlight current token
                        if let match = self.container.seekToken(at: resolvedPosition) {
                            self._currentPosition = match.1
                            gesture.cancel()
                        }
                        return
                    }
                    if clickCountTracker == 3 {
                        // highlight current line
                        self._currentPosition = .init(row: resolvedPosition.row, column: 0).with(selectionTo: .init(row: resolvedPosition.row + 1, column: 0))
                        gesture.cancel()
                        return
                    }
                } else {
                    clickCountTracker = 1
                }
            }
            
            // cell is out of bounds, cancel gesture to prevent further movement
            if !isSelecting, !self.tableView.visibility(for: resolvedPosition).isFullyVisible {
                resolvedPosition.visibilityAdjustmentBehaviour = .contentOffset
                self.updatePosition(resolvedPosition, using: .mouse)
                gesture.cancel()
                return
            }
            
            if isSelecting {
                if resolvedPosition != self._currentPosition, let position = self._currentPosition {
                    position.currentSelectionEndPosition = resolvedPosition
                    position.visibilityAdjustmentBehaviour = .contentOffset
                    self.updatePosition(position, using: .mouse)
                }
            } else {
                resolvedPosition.visibilityAdjustmentBehaviour = .none
                self.updatePosition(resolvedPosition, using: .mouse)
            }
        }
        
        fileprivate var _hintDictionary: [Int: Hint] = [:]
        let hintLabel: HintLabel = .init()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(tableView)
            
            build { [unowned self] in
                Equal()
                HSplit {
                    Equal()
                    Automatic {
                        self.positionTrackerLabel
                    } insets: {
                        .init(horizontal: 8)
                    }
                    Padding(10)
                } size: {
                    .fixed(22)
                }
                Padding(10)
            }
            
            tableView.addSubview(self.input)
            
            let cursorHoverGesture = UIHoverGestureRecognizer { gesture in
                let state = gesture.state
                                
                if state == .began {
                    NSCursor.iBeam.set()
                }
                if state == .ended || state == .cancelled {
                    NSCursor.arrow.set()
                }
            }
            addGestureRecognizer(cursorHoverGesture)
            
            cursorGesture.minimumPressDuration = 0
            addGestureRecognizer(cursorGesture)
            
            updateUI()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override var canBecomeFirstResponder: Bool {
            true
        }
        
        override func becomeFirstResponder() -> Bool {
            input.becomeFirstResponder()
        }
        
        override func resignFirstResponder() -> Bool {
            input.resignFirstResponder()
        }
        
        func updateUI() {
            input.field.caretHeight = ui.estimatedLineHeight
            
            backgroundColor = ui.editorBackgroundColor
            tableView.backgroundColor = ui.editorBackgroundColor
            
            positionTrackerLabel.backgroundColor = ui.editorBackgroundColor
            positionTrackerLabel.border(.hairline, width: .onePixel * 2, cornerRadius: 4)
        }
        
        func reloadData() {
            tableView.reloadData()
        }
        
        func rebindLines() {
            for indexPath in tableView.indexPathsForVisibleRows ?? [] {
                guard let cell = tableView.cellForRow(at: indexPath) as? RowCell else { continue }
                cell.bind(line: container.lines[indexPath.row], container: container, assistant: session.assistant, hint: _hintDictionary[indexPath.row], idx: indexPath.row, ui: ui)
            }
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            container.lines.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: RowCell.reuseIdentifier, for: indexPath) as! RowCell
            let idx: Int = indexPath.row
            cell.bind(line: container.lines[idx], container: container, assistant: session.assistant, hint: _hintDictionary[indexPath.row], idx: idx, ui: ui)
            return cell
        }
        
        func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
            guard let cell = cell as? RowCell else { return }
            
            let isSelectedRow: Bool = _currentPosition?.row == indexPath.row
            if isSelectedRow {
                updateInputPosition(scroll: false, cellHint: cell)
            }
            
            cell.onHoverIndicatorView = { [unowned self, weak cell] isActive in
                
                if isActive, let hint = cell?.hint {
                    guard let cell else { return }
                    
                    NSCursor.pointingHand.set()
                    
                    self.hintLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
                    self.hintLabel.text = hint.text
                    self.hintLabel.textColor = hint.kind.textColor
                    self.hintLabel.backgroundColor = hint.kind.secondaryColor
                    
                    let indicatorViewFrame = cell.hintIndicatorView.convert(cell.hintIndicatorView.bounds, to: self.tableView)
                    
                    let inputFrame: CGRect = self.inputFrame(for: .init(row: indexPath.row, column: self.container.lines[indexPath.row].utf16.count - 1), cellHint: nil) ?? .zero
                    
                    let xOffset: CGFloat = inputFrame.x + 14
                    
                    let width: CGFloat = self.width - xOffset
                    let calculatedSize: CGSize = self.hintLabel.sizeThatFits(.init(width: width, height: .infinity))
                    self.hintLabel.frame = .init(x: xOffset, y: indicatorViewFrame.y - self.hintLabel.padding/2, width: min(width, calculatedSize.width), height: calculatedSize.height)
                    self.tableView.addSubview(self.hintLabel)
                } else {
                    NSCursor.iBeam.set()
                    
                    self.hintLabel.removeFromSuperview()
                }
            }
        }
        
        func updateInputPosition(scroll: Bool, cellHint: RowCell? = nil) {
            guard let position = _currentPosition else {
                input.resignFirstResponder()
                print("resign first")
                return
            }
            
            if scroll {
                tableView.scrollTo(position: position)
            }
            
            guard let frame = self.inputFrame(for: position, cellHint: cellHint) else { return }
            
            input.frame = frame
            
//            DispatchQueue.main.async(after: 0.5) {
//                self.session.assistant?.suggestions(for: position) { [weak self] suggestions in
//                    self?.xt.reloadData(suggestions)
//                }
//            }
//
//            if xt.view.window == nil, xt.isBeingPresented == false, position.currentTokenStore != nil {
//                xtAnchorView.frame = input.frame
//                tableView.addSubview(xtAnchorView)
//
//                xt.preferredContentSize = .init(width: 320, height: 200)
//                xt.modalPresentationStyle = .popover
//                if let presentationController = xt.popoverPresentationController {
//                    presentationController.sourceView = xtAnchorView
//                    presentationController.passthroughViews = [self]
//                    presentationController.permittedArrowDirections = .up
//                }
//                self.parentViewController.present(self.xt, animated: true)
//            } else if xt.view.window != nil, _currentPosition?.currentTokenStore == nil {
//                xt.dismiss(animated: false)
//
//                xtAnchorView.removeFromSuperview()
//            }
            
            if !input.isFirstResponder {
                input.becomeFirstResponder()
            }
        }
        
        func inputFrame(for position: Position, cellHint: RowCell?) -> CGRect? {
            let indexPath: IndexPath = .init(row: position.row, section: 0)
            
            guard let cell = cellHint ?? tableView.cellForRow(at: indexPath) as? RowCell else { return nil }
            
            return cell.inputFrame(for: position)
        }
        
        class CompletionViewController: UIViewController, UICollectionViewDelegate {
            
            let render: ComponentRender<Assistant.Suggestion> = .init(layout: .list(style: .plain, configuration: { listConfiguration in
                listConfiguration.backgroundColor = .clear
                listConfiguration.showsSeparators = false
            }))
            
            class Cell: UICollectionViewListCell {
                override func bindObject(_ obj: AnyObject) {
                    guard let suggestion = obj as? Assistant.Suggestion else { return }
                    
                    var configuration = defaultContentConfiguration()
                    configuration.text = suggestion.label
                    configuration.textProperties.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
                    contentConfiguration = configuration
                }
                
                override func updateConfiguration(using state: UICellConfigurationState) {
                    super.updateConfiguration(using: state)
                    
                    guard var contentConfiguration = self.contentConfiguration?.updated(for: state) as? UIListContentConfiguration else { return }
                    contentConfiguration.textProperties.colorTransformer = UIConfigurationColorTransformer { color in
                        state.isSelected ? .white : .label
                    }
                    self.contentConfiguration = contentConfiguration
                    
                    if #available(macCatalyst 16.0, *) {
                        var backgroundConfiguration = defaultBackgroundConfiguration()
                        backgroundConfiguration.backgroundColorTransformer = .init({ color in
                            return state.isSelected ? .systemBlue : .clear
                        })
                        self.backgroundConfiguration = backgroundConfiguration
                    } else {
                        // Fallback on earlier versions
                    }
                }
            }
            
            override func viewDidLoad() {
                super.viewDidLoad()
                
                view.build { [unowned self] in
                    Equal {
                        self.render
                    }
                }
                
                render.backgroundColor = .clear
                render.collectionView.backgroundColor = .clear
                render.collectionView.delegate = self
            }
            
            override var canBecomeFirstResponder: Bool {
                false
            }
            
            override func becomeFirstResponder() -> Bool {
                false
            }
            
            func reloadData(_ suggestions: [Assistant.Suggestion]) {
                render.updateSnapshot { builder in
                    builder.appendSection(using: Cell.self, items: suggestions)
                }
            }
        }
        
        let xtAnchorView: UIView = UIView()
        let xt: CompletionViewController = CompletionViewController()
        
        var cachedWidth: CGFloat = 0
        var isLiveResizing: Bool = false
        override func layoutSubviews() {
          
            let width: CGFloat = self.width
            if width == cachedWidth { return }
            cachedWidth = width
            
            if !isLiveResizing {
                lazilyLayoutSubviews()
                isLiveResizing = true
            }
            
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(lazilyLayoutSubviews), object: nil)
            perform(#selector(lazilyLayoutSubviews), with: nil, afterDelay: 0.1)
        }
        
        @objc func lazilyLayoutSubviews() {
            UIView.performWithoutAnimation {
                tableView.estimatedRowHeight = ui.estimatedLineHeight
                tableView.frame = bounds
                
                var contentInsets: UIEdgeInsets = ui.editorContentInset
                contentInsets.bottom += bounds.height * ui.editorContentOverscroll
                tableView.contentInset = contentInsets
            }
            
            tableView.beginUpdates()
            tableView.endUpdates()
            updateInputPosition(scroll: false)
            
            isLiveResizing = false
        }
    }
}

extension Editor {
    struct Hint: Codable {
        enum Kind: Codable {
            case error
            case warning
            
            var textColor: UIColor {
                .black
            }
            
            var primaryColor: UIColor {
                switch self {
                case .error:
                    return .systemRed
                case .warning:
                    return .systemYellow
                }
            }
            
            var secondaryColor: UIColor {
                switch self {
                case .error:
                    return .dynamic(light: .hex("#FFBFC0"), dark: .systemRed)
                case .warning:
                    return .dynamic(light: .hex("#FFEAAC"), dark: .systemYellow)
                }
            }
        }
        
        let position: Editor.Position
        let text: String
        let kind: Hint.Kind
    }
    
    class HintLabel: UIView {
        private let label: UILabel = .init("")
        
        var padding: CGFloat = 12
        
        var text: String = "" {
            didSet {
                label.text = text
            }
        }
        
        var textColor: UIColor? {
            set {
                label.textColor = newValue
            }
            get {
                label.textColor
            }
        }
        
        var font: UIFont? {
            set {
                label.font = newValue
            }
            get {
                label.font
            }
        }
        
        init() {
            super.init(frame: .zero)
            
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(label)
            
            cornerRadius(6)
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            label.frame = bounds.insetBy(dx: padding / 2, dy: padding  / 2)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func sizeThatFits(_ size: CGSize) -> CGSize {
            var size: CGSize = label.sizeThatFits(size)
            size.width += padding
            size.height += padding
            return size
        }
    }
}

extension Editor.Document {
    private func calculateVerticalMovement(rows: Int, from position: Editor.Position? = nil) -> Editor.Position {
        guard let position = position ?? _currentPosition else { return .zero }
        let isUpMovement: Bool = rows > 0
        let targetIdx: Int = position.row + rows
        var targetPosition: Editor.Position = position
        if position.row + rows < 0 {
            targetPosition = .zero
            self.overflowColumnHint = 0
        } else  if let line = self.container.line(for: targetIdx) {
            targetPosition = .init(row: targetIdx, column: line.utf16.count < self.overflowColumnHint ? line.utf16.count : self.overflowColumnHint)
        } else if isUpMovement == true {
            targetPosition = .zero
        } else if isUpMovement == false {
            targetPosition = .init(row: position.row, column: self.container.lines[position.row].utf16.count)
        }
        return targetPosition
    }
    
    func moveUp(rows: Int, method: Method = .keyboardVerticalArrow) {
        let targetPosition: Editor.Position = calculateVerticalMovement(rows: -rows)
        targetPosition.visibilityAdjustmentBehaviour = .contentOffset
        self.updatePosition(targetPosition, using: method)
    }
    
    func moveDown(rows: Int, method: Method = .keyboardVerticalArrow) {
        let targetPosition: Editor.Position = calculateVerticalMovement(rows: rows)
        targetPosition.visibilityAdjustmentBehaviour = .contentOffset
        self.updatePosition(targetPosition, using: method)
    }
    
    private func calculateHorizontalMovement(columns: Int, from position: Editor.Position? = nil) -> Editor.Position {
        guard let position = position ?? _currentPosition else { return .zero }
        return self.container.calculateSafePositionOffset(at: position, length: columns)
    }
    
    func moveLeft(columns: Int, method: Method = .keyboardHorizontalArrow) {
        self.updatePosition(self.calculateHorizontalMovement(columns: -columns), using: method)
    }
    
    func moveRight(columns: Int, method: Method = .keyboardHorizontalArrow) {
        self.updatePosition(self.calculateHorizontalMovement(columns: columns), using: method)
    }
    
    func moveToTop() {
        let position: Editor.Position = .zero
        position.visibilityAdjustmentBehaviour = .scrollToLine
        self.updatePosition(position, using: .virtual)
    }
    
    func moveToBottom() {
        let maxRow: Int = self.container.lines.count - 1
        let line: String = self.container.lines[maxRow]
        let position: Editor.Position = .init(row: maxRow, column: line.count)
        position.visibilityAdjustmentBehaviour = .scrollToLine
        self.updatePosition(position, using: .virtual)
    }
    
    func moveToBeginningOfLine(method: Method = .keyboardHorizontalArrow) {
        guard let position = _currentPosition else { return }
        let updatedPosition: Editor.Position = .init(row: position.row, column: 0)
        self.updatePosition(updatedPosition, using: method)
    }
    
    func moveToEndOfLine(method: Method = .keyboardHorizontalArrow) {
        guard let position = _currentPosition else { return }
        let line: String = self.container.lines[position.row]
        let updatedPosition: Editor.Position = .init(row: position.row, column: line.utf16.count)
        self.updatePosition(updatedPosition, using: method)
    }
    
    func moveToBeginningOfWord(method: Method = .keyboardHorizontalArrow) {
        print("moveToBeginningOfWord")
    }
    
    func moveToEndOfWord(method: Method = .keyboardHorizontalArrow) {
        print("moveToEndOfWord")
    }
    
    func selectToPosition(position: Editor.Position, method: Method = .mouse) {
        guard let position = _currentPosition else { return }
        position.currentSelectionEndPosition = position
        self.updatePosition(position, using: method)
    }
    
    func selectUp(rows: Int, method: Method = .keyboardVerticalArrow) {
        guard let position = _currentPosition else { return }
        self.updatePosition(calculateVerticalMovement(rows: -rows, from: position.currentSelectionEndPosition ?? position), using: method)
    }
    
    func selectDown(rows: Int, method: Method = .keyboardVerticalArrow) {
        guard let position = _currentPosition else { return }
        self.updatePosition(calculateVerticalMovement(rows: rows, from: position.currentSelectionEndPosition ?? position), using: method)
    }
    
    func selectLeft(columns: Int, method: Method = .keyboardHorizontalArrow) {
        guard let position = _currentPosition else { return }
        self.updatePosition(calculateHorizontalMovement(columns: -columns, from: position.currentSelectionEndPosition ?? position), using: method)
    }
    
    func selectRight(columns: Int, method: Method = .keyboardHorizontalArrow) {
        guard let position = _currentPosition else { return }
        self.updatePosition(calculateHorizontalMovement(columns: columns, from: position.currentSelectionEndPosition ?? position), using: method)
    }
    
    
    /*
     selectToTop()
     selectToBottom()
     selectAll()
     selectToBeginningOfLine()
     selectToEndOfLine()
     selectWordsContainingCursors()
     selectToBeginningOfWord()
     selectToEndOfWord()
     scrollToCursorPosition()
     scrollToPosition(position)
     */
}

extension Editor {
    class TableView: UITableView {
        struct Visibility {
            let isFullyVisible: Bool
            let cellRect: CGRect
        }
        
        func immediatlyStopScrolling() {
            setContentOffset(contentOffset, animated: false)
        }
        
        func deselectAll() {
            for indexPath in indexPathsForSelectedRows ?? [] {
                deselectRow(at: indexPath, animated: false)
            }
        }
        
        func scrollTo(position: Position) {
            switch position.visibilityAdjustmentBehaviour {
            case .none:
                break
            case .followCursor:
                let visibility: Visibility = visibility(for: position, yOffset: -50)
                if  visibility.isFullyVisible { return }
                DispatchQueue.main.async {
                    self.contentOffset.y += visibility.cellRect.height
                }
                break
            case .contentOffset:
                let indexPath: IndexPath = (position.currentSelectionEndPosition ?? position).indexPath
                
                let rect: CGRect = convert(rectForRow(at: indexPath), to: superview)
                
                if rect.y - rect.height <= 0 + rect.height + contentInset.top {
                    let startOffsetY: CGFloat = safeAreaInsets.top + contentInset.top
                    if contentOffset.y + startOffsetY - rect.height <= 0 {
                        contentOffset.y = -startOffsetY
                        return
                    }
                    
                    contentOffset.y -= rect.height
                }
                
                if rect.y > bounds.height - rect.height {
                    contentOffset.y += rect.height
                }
            case .scrollToLine:
                self.scrollToRow(at: position.indexPath, at: .middle, animated: false)
            }
        }
        
        func visibility(for position: Position, yOffset: CGFloat = 0) -> Visibility {
            let rect = rectForRow(at: position.indexPath)
            return .init(isFullyVisible: bounds.offsetBy(dx: 0, dy: yOffset).contains(rect), cellRect: rect)
        }
        
        override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
            // prevents unwanted automatic scroll
        }
    }
}
