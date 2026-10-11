import SwiftUI
import JavaQuestKit
#if os(iOS)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
#else
import AppKit
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
#endif

/// Fügt Code an der Cursorstelle ein – für Baupläne und Bausteine neben dem Editor.
@MainActor
final class CodeEditorController {
    fileprivate var insertHandler: ((String) -> Void)?
    fileprivate var focusHandler: (() -> Void)?

    func insert(_ snippet: String) { insertHandler?(snippet) }
    func focus() { focusHandler?() }
}

/// Ein echter Code-Editor: Zeilennummern, Syntaxfarben beim Tippen, automatische Einrückung,
/// Klammerpaare und ein Compiler, der mitliest – Fehler werden rot markiert, Namenshinweise gelb.
struct JavaCodeEditor: View {
    @Binding var text: String
    /// Zeile, an der ein Lauf gescheitert ist (Absturz, Test) – zusätzlich zur Prüfung beim Tippen.
    var runErrorLine: Int?
    var controller: CodeEditorController?
    var minHeight: CGFloat = 240
    /// Unter dem Editor zeigen, was der Compiler beim Tippen findet.
    var showsLint = true
    var isEditable = true

    @State private var lint = Lint()

    struct Lint: Equatable {
        var problem: JavaProblem?
        var hints: [QualityFinding] = []
        var checked = false
    }

    var body: some View {
        VStack(spacing: 0) {
            PlatformCodeView(text: $text, marks: marks, controller: controller, isEditable: isEditable)
                .frame(minHeight: minHeight)
            if showsLint && isEditable {
                lintBar
            }
        }
        .background(CodeTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.innerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        }
        .environment(\.colorScheme, .dark)
        .task(id: text) {
            // Der Compiler liest mit – kurz nach der letzten Taste, nicht bei jedem Buchstaben.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let source = JavaSource.normalizingTypography(text)
            let problem = JavaRunner.check(source)
            let hints = problem == nil ? CodeQuality.naming(source) : []
            withAnimation(.easeOut(duration: 0.15)) { lint = Lint(problem: problem, hints: hints, checked: true) }
        }
    }

    private var marks: [EditorMark] {
        var marks: [EditorMark] = []
        if let line = lint.problem?.line { marks.append(EditorMark(line: line, isError: true)) }
        if let runErrorLine { marks.append(EditorMark(line: runErrorLine, isError: true)) }
        for hint in lint.hints { if let line = hint.line { marks.append(EditorMark(line: line, isError: false)) } }
        return marks
    }

    private var lintBar: some View {
        let (symbol, tint, message): (String, Color, String) = {
            if let problem = lint.problem {
                let line = problem.line.map { "Zeile \($0): " } ?? ""
                return ("xmark.octagon.fill", Theme.ember, line + problem.message)
            }
            if let hint = lint.hints.first {
                return ("lightbulb.fill", .yellow, hint.message)
            }
            return ("checkmark.circle.fill", Theme.success, lint.checked ? "Übersetzt ohne Fehler" : "Der Compiler liest mit …")
        }()
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(message)
                .foregroundStyle(lint.problem == nil && lint.hints.isEmpty ? CodeTheme.plain.opacity(0.55) : CodeTheme.plain)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            Spacer(minLength: 0)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CodeTheme.chrome)
        .accessibilityElement(children: .combine)
    }
}

struct EditorMark: Equatable {
    let line: Int
    let isError: Bool
}

// MARK: - Farben und Schrift

@MainActor
enum EditorStyle {
    #if os(iOS)
    static let fontSize: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 13 : 14
    #else
    static let fontSize: CGFloat = 13.5
    #endif
    static var font: PlatformFont { .monospacedSystemFont(ofSize: fontSize, weight: .regular) }
    static var gutterFont: PlatformFont { .monospacedDigitSystemFont(ofSize: fontSize - 2.5, weight: .regular) }
    static let gutterWidth: CGFloat = 34

    static func color(_ color: Color) -> PlatformColor { PlatformColor(color) }

    static var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        return [.font: font, .foregroundColor: color(CodeTheme.plain), .paragraphStyle: paragraph]
    }

    /// Färbt den ganzen Text neu ein und markiert Fehler- und Hinweiszeilen.
    static func apply(to storage: NSTextStorage, marks: [EditorMark]) {
        let text = storage.string
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: full)
        var location = 0
        for token in JavaHighlighter.tokenize(text) {
            let length = token.text.utf16.count
            if token.kind != .plain {
                storage.addAttribute(.foregroundColor, value: color(CodeTheme.color(for: token.kind)), range: NSRange(location: location, length: length))
            }
            location += length
        }
        let ns = text as NSString
        for mark in marks {
            guard let range = lineRange(mark.line, in: ns) else { continue }
            if mark.isError {
                storage.addAttribute(.backgroundColor, value: color(Theme.ember).withAlphaComponent(0.28), range: range)
            } else {
                storage.addAttributes([
                    .underlineStyle: NSUnderlineStyle([.single, .patternDot]).rawValue,
                    .underlineColor: PlatformColor.systemYellow,
                ], range: range)
            }
        }
        storage.endEditing()
    }

    static func lineRange(_ line: Int, in ns: NSString) -> NSRange? {
        guard line >= 1 else { return nil }
        var current = 1
        var location = 0
        while current < line {
            let next = ns.range(of: "\n", range: NSRange(location: location, length: ns.length - location))
            guard next.location != NSNotFound else { return nil }
            location = next.location + 1
            current += 1
        }
        let end = ns.range(of: "\n", range: NSRange(location: location, length: ns.length - location))
        let length = (end.location == NSNotFound ? ns.length : end.location) - location
        return length > 0 ? NSRange(location: location, length: length) : nil
    }

    /// Zeichnet die Zeilennummern für alle Zeilen, deren Fragmente `fragments` liefert.
    static func drawLineNumbers(layoutManager: NSLayoutManager, container: NSTextContainer, text: NSString, glyphRange: NSRange,
                                errorLines: Set<Int>, width: CGFloat, yOffset: @escaping (CGFloat) -> CGFloat) {
        func startsLine(_ index: Int) -> Bool { index == 0 || index > text.length || text.character(at: index - 1) == 0x0A }
        // Nummer der ersten sichtbaren Zeile: Zeilenumbrüche davor zählen. Beginnt die Ansicht mitten in einer
        // umbrochenen Zeile, trägt erst die nächste Zeile eine Nummer.
        let firstChar = glyphRange.length > 0 ? layoutManager.characterIndexForGlyph(at: glyphRange.location) : 0
        let before = text.substring(to: min(firstChar, text.length)) as NSString
        var number = before.components(separatedBy: "\n").count + (startsLine(firstChar) ? 0 : 1)
        func draw(_ n: Int, at y: CGFloat, height: CGFloat) {
            let isError = errorLines.contains(n)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: gutterFont,
                .foregroundColor: isError ? color(Theme.ember) : color(CodeTheme.plain).withAlphaComponent(0.32),
            ]
            let label = "\(n)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: CGPoint(x: width - size.width - 8, y: yOffset(y) + (height - size.height) / 2), withAttributes: attributes)
        }
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, range, _ in
            if startsLine(layoutManager.characterIndexForGlyph(at: range.location)) {
                draw(number, at: rect.minY, height: rect.height)
                number += 1
            }
        }
        let extra = layoutManager.extraLineFragmentRect
        if !extra.isEmpty {
            draw(text.components(separatedBy: "\n").count, at: extra.minY, height: extra.height)
        }
    }
}

// MARK: - Gemeinsames Verhalten

@MainActor
private class EditorCoordinator: NSObject {
    var parent: PlatformCodeView
    /// Während der Editor selbst Text ersetzt, sollen die Eingabe-Regeln nicht noch einmal greifen.
    var isApplying = false

    init(parent: PlatformCodeView) { self.parent = parent }

    /// Wendet die Regeln aus CodeEditing an. true = selbst erledigt, die Eingabe nicht mehr übernehmen.
    func handle(_ input: String, range: NSRange, text: String, apply: (CodeEditing.Edit) -> Void) -> Bool {
        guard !isApplying, let edit = CodeEditing.edit(for: input, in: text, selection: range) else { return false }
        isApplying = true
        apply(edit)
        isApplying = false
        return true
    }
}

// MARK: - iOS

#if os(iOS)
private struct PlatformCodeView: UIViewRepresentable {
    @Binding var text: String
    let marks: [EditorMark]
    let controller: CodeEditorController?
    let isEditable: Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> CodeTextView {
        let view = CodeTextView()
        view.delegate = context.coordinator
        view.isEditable = isEditable
        view.text = text
        view.marks = marks
        view.restyle()
        view.smartInput = { [weak view, weak coordinator = context.coordinator] input in
            // Symbolleiste (und alles, was nicht über die Tastatur kommt): dieselben Regeln wie beim Tippen.
            guard let view, let coordinator else { return }
            if !coordinator.handle(input, range: view.selectedRange, text: view.text, apply: { view.apply($0) }) {
                view.insertText(input)
            }
            coordinator.textViewDidChange(view)
        }
        connect(controller, to: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: CodeTextView, context: Context) {
        context.coordinator.parent = self
        view.isEditable = isEditable
        connect(controller, to: view, coordinator: context.coordinator)
        var needsStyle = false
        if view.text != text {
            let selection = view.selectedRange
            view.text = text
            view.selectedRange = NSRange(location: min(selection.location, (text as NSString).length), length: 0)
            needsStyle = true
        }
        if view.marks != marks {
            view.marks = marks
            needsStyle = true
        }
        if needsStyle { view.restyle() }
    }

    private func connect(_ controller: CodeEditorController?, to view: CodeTextView, coordinator: Coordinator) {
        controller?.insertHandler = { [weak view, weak coordinator] snippet in
            guard let view, let coordinator else { return }
            let edit = CodeEditing.insertion(snippet, in: view.text, selection: view.selectedRange)
            coordinator.isApplying = true
            view.apply(edit)
            coordinator.isApplying = false
            coordinator.textViewDidChange(view)
        }
        controller?.focusHandler = { [weak view] in view?.becomeFirstResponder() }
    }

    final class Coordinator: EditorCoordinator, UITextViewDelegate {
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard let view = textView as? CodeTextView else { return true }
            let handled = handle(text, range: range, text: view.text) { view.apply($0) }
            if handled { textViewDidChange(view) }
            return !handled
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let view = textView as? CodeTextView else { return }
            parent.text = view.text
            view.restyle()
        }
    }
}

/// UITextView mit TextKit 1 – für Zeilennummern und Markierungen.
final class CodeTextView: UITextView {
    private let storage = NSTextStorage()
    private let gutter = GutterView()
    var marks: [EditorMark] = []
    /// Eingabe mit den Editor-Regeln (Einrücken, Klammerpaare) – für die Symbolleiste.
    var smartInput: ((String) -> Void)?

    init() {
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)
        backgroundColor = .clear
        font = EditorStyle.font
        textColor = EditorStyle.color(CodeTheme.plain)
        tintColor = EditorStyle.color(Theme.orange)
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        keyboardType = .asciiCapable
        keyboardAppearance = .dark
        alwaysBounceVertical = true
        textContainerInset = UIEdgeInsets(top: 10, left: EditorStyle.gutterWidth + 4, bottom: 10, right: 8)
        typingAttributes = EditorStyle.baseAttributes
        gutter.textView = self
        addSubview(gutter)
        inputAccessoryView = SymbolBar(onSymbol: { [weak self] in self?.smartInput?($0) },
                                       onDone: { [weak self] in self?.resignFirstResponder() })
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func restyle() {
        // Während einer Tottaste (^, ´ auf deutschen Tastaturen) nicht umfärben – das bräche die Eingabe ab.
        guard markedTextRange == nil else { return }
        EditorStyle.apply(to: storage, marks: marks)
        typingAttributes = EditorStyle.baseAttributes
        gutter.errorLines = Set(marks.filter(\.isError).map(\.line))
        gutter.setNeedsDisplay()
    }

    func apply(_ edit: CodeEditing.Edit) {
        if let start = position(from: beginningOfDocument, offset: edit.range.location),
           let end = position(from: start, offset: edit.range.length),
           let range = textRange(from: start, to: end), !(edit.replacement.isEmpty && edit.range.length == 0) {
            replace(range, withText: edit.replacement)
        }
        selectedRange = NSRange(location: edit.cursor, length: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = max(contentSize.height, bounds.height)
        let frame = CGRect(x: 0, y: 0, width: EditorStyle.gutterWidth, height: height)
        if gutter.frame != frame {
            gutter.frame = frame
            gutter.setNeedsDisplay()
        }
    }

    /// Zeilennummern als Teil des Inhalts – sie scrollen mit dem Text.
    final class GutterView: UIView {
        weak var textView: CodeTextView?
        var errorLines: Set<Int> = []

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = EditorStyle.color(CodeTheme.chrome).withAlphaComponent(0.55)
            isUserInteractionEnabled = false
            contentMode = .redraw
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func draw(_ rect: CGRect) {
            guard let textView else { return }
            let layoutManager = textView.layoutManager
            let container = textView.textContainer
            layoutManager.ensureLayout(for: container)
            let inset = textView.textContainerInset.top
            EditorStyle.drawLineNumbers(layoutManager: layoutManager, container: container, text: textView.text as NSString,
                                            glyphRange: layoutManager.glyphRange(for: container), errorLines: errorLines,
                                            width: bounds.width) { $0 + inset }
        }
    }
}

/// Die Zeichen, die auf der iPhone-Tastatur tief versteckt sind – eine Reihe über der Tastatur.
private final class SymbolBar: UIInputView {
    private static let symbols = ["⇥", "{", "}", "(", ")", ";", "\"", "=", "+", "-", "<", ">", "[", "]", "!", "&&", "||", ".", ",", "*", "/", "%", "'"]

    init(onSymbol: @escaping (String) -> Void, onDone: @escaping () -> Void) {
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 46), inputViewStyle: .default)
        allowsSelfSizing = true
        // Passend zur dunklen Code-Tastatur (die Tastatur selbst ist .dark).
        overrideUserInterfaceStyle = .dark
        backgroundColor = UIColor(white: 0.2, alpha: 1)
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        for symbol in Self.symbols {
            var configuration = UIButton.Configuration.filled()
            configuration.title = symbol
            configuration.baseBackgroundColor = UIColor(white: 1, alpha: 0.16)
            configuration.baseForegroundColor = .white
            configuration.cornerStyle = .medium
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold)
                return attributes
            }
            let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in
                UIDevice.current.playInputClick()
                onSymbol(symbol == "⇥" ? "\t" : symbol)
            })
            button.accessibilityLabel = symbol == "⇥" ? "Einrücken" : symbol
            stack.addArrangedSubview(button)
        }
        var doneConfiguration = UIButton.Configuration.plain()
        doneConfiguration.image = UIImage(systemName: "keyboard.chevron.compact.down")
        doneConfiguration.baseForegroundColor = .white
        let done = UIButton(configuration: doneConfiguration, primaryAction: UIAction { _ in onDone() })
        done.accessibilityLabel = "Tastatur ausblenden"

        scroll.addSubview(stack)
        addSubview(scroll)
        addSubview(done)
        for view in [scroll, stack, done] as [UIView] { view.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            scroll.trailingAnchor.constraint(equalTo: done.leadingAnchor, constant: -4),
            done.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            done.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

extension SymbolBar: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

#else

// MARK: - macOS

private struct PlatformCodeView: NSViewRepresentable {
    @Binding var text: String
    let marks: [EditorMark]
    let controller: CodeEditorController?
    let isEditable: Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // TextKit 1 – für Zeilennummern über den Layout-Manager.
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        let textView = CodeNSTextView(frame: .zero, textContainer: container)
        textView.storage = storage
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.drawsBackground = false
        textView.insertionPointColor = EditorStyle.color(Theme.orange)
        textView.selectedTextAttributes = [.backgroundColor: EditorStyle.color(Theme.indigo).withAlphaComponent(0.45)]
        textView.textContainerInset = NSSize(width: 4, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.typingAttributes = EditorStyle.baseAttributes
        textView.font = EditorStyle.font
        textView.string = text
        textView.isEditable = isEditable
        scrollView.documentView = textView

        let ruler = LineNumberRuler(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        textView.ruler = ruler
        textView.marks = marks
        textView.restyle()

        connect(controller, to: textView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? CodeNSTextView else { return }
        textView.isEditable = isEditable
        connect(controller, to: textView, coordinator: context.coordinator)
        var needsStyle = false
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
            needsStyle = true
        }
        if textView.marks != marks {
            textView.marks = marks
            needsStyle = true
        }
        if needsStyle { textView.restyle() }
    }

    private func connect(_ controller: CodeEditorController?, to textView: CodeNSTextView, coordinator: Coordinator) {
        controller?.insertHandler = { [weak textView, weak coordinator] snippet in
            guard let textView, let coordinator else { return }
            let edit = CodeEditing.insertion(snippet, in: textView.string, selection: textView.selectedRange())
            coordinator.isApplying = true
            textView.apply(edit)
            coordinator.isApplying = false
            textView.window?.makeFirstResponder(textView)
        }
        controller?.focusHandler = { [weak textView] in textView?.window?.makeFirstResponder(textView) }
    }

    final class Coordinator: EditorCoordinator, NSTextViewDelegate {
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let view = textView as? CodeNSTextView, let replacement = replacementString else { return true }
            return !handle(replacement, range: affectedCharRange, text: view.string) { view.apply($0) }
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? CodeNSTextView else { return }
            parent.text = view.string
            view.restyle()
        }
    }
}

final class CodeNSTextView: NSTextView {
    var storage: NSTextStorage?
    weak var ruler: LineNumberRuler?
    var marks: [EditorMark] = []

    func restyle() {
        // Während einer Tottaste (^, ´ auf deutschen Tastaturen) nicht umfärben – das bräche die Eingabe ab.
        guard let textStorage, !hasMarkedText() else { return }
        EditorStyle.apply(to: textStorage, marks: marks)
        typingAttributes = EditorStyle.baseAttributes
        ruler?.errorLines = Set(marks.filter(\.isError).map(\.line))
        ruler?.needsDisplay = true
    }

    func apply(_ edit: CodeEditing.Edit) {
        if !(edit.replacement.isEmpty && edit.range.length == 0) {
            // insertText registriert die Änderung fürs Rückgängigmachen.
            insertText(edit.replacement, replacementRange: edit.range)
        }
        setSelectedRange(NSRange(location: edit.cursor, length: 0))
    }

    override func didChangeText() {
        super.didChangeText()
        ruler?.needsDisplay = true
    }
}

/// Zeilennummern links vom Text – mit roter Nummer an Fehlerzeilen.
final class LineNumberRuler: NSRulerView {
    weak var textView: NSTextView?
    var errorLines: Set<Int> = []

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = EditorStyle.gutterWidth
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(redraw), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func redraw() { needsDisplay = true }

    override var requiredThickness: CGFloat { EditorStyle.gutterWidth }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        EditorStyle.color(CodeTheme.chrome).withAlphaComponent(0.55).setFill()
        bounds.fill()
        guard let textView, let layoutManager = textView.layoutManager, let container = textView.textContainer else { return }
        let visible = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let inset = textView.textContainerInset.height
        EditorStyle.drawLineNumbers(layoutManager: layoutManager, container: container, text: textView.string as NSString,
                                        glyphRange: glyphRange, errorLines: errorLines, width: bounds.width) { y in
            self.convert(NSPoint(x: 0, y: y + inset), from: textView).y
        }
    }
}
#endif
