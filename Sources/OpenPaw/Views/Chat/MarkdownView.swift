import SwiftUI
import HighlightSwift

struct MarkdownView: View {
    let source: String

    @State private var renderedItems: [RenderItem] = []
    @State private var lastSource: String = ""

    private static let highlighter = Highlight()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(renderedItems.enumerated()), id: \.offset) { _, item in
                renderItemView(item)
            }
        }
        .task(id: source) {
            // First pass: immediate render without syntax highlighting
            if source != lastSource {
                renderedItems = buildRenderItems(from: parseBlocks(), highlightedCode: [:])
                lastSource = source
            }
            // Second pass: apply syntax highlighting to code blocks
            let blocks = parseBlocks()
            let highlighted = await highlightCodeBlocks(blocks)
            if !highlighted.isEmpty {
                renderedItems = buildRenderItems(from: blocks, highlightedCode: highlighted)
            }
        }
    }

    // MARK: - Render items

    private enum RenderItem {
        case textRun(NSAttributedString)
        case image(alt: String, url: URL)
        case table(ParsedTable)
    }

    /// Highlight all code blocks concurrently.
    private func highlightCodeBlocks(_ blocks: [MarkdownBlock]) async -> [Int: NSAttributedString] {
        var results: [Int: NSAttributedString] = [:]
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let colors: HighlightColors = isDark ? .dark(.atomOne) : .light(.atomOne)

        for (index, block) in blocks.enumerated() {
            guard case .code(let lang, let code) = block else { continue }
            do {
                let mode: HighlightMode = if let lang, !lang.isEmpty {
                    .languageAlias(lang.lowercased())
                } else {
                    .automatic
                }
                let result = try await Self.highlighter.request(code, mode: mode, colors: colors)
                let highlighted = result.attributedText
                results[index] = NSAttributedString(highlighted)
            } catch {
                // Highlighting failed — will use plain monospace fallback
            }
        }
        return results
    }

    /// Build render items, optionally using pre-highlighted code.
    private func buildRenderItems(from blocks: [MarkdownBlock], highlightedCode: [Int: NSAttributedString]) -> [RenderItem] {
        var items: [RenderItem] = []
        var current = NSMutableAttributedString()

        func flushText() {
            if current.length > 0 {
                items.append(.textRun(current.copy() as! NSAttributedString))
                current = NSMutableAttributedString()
            }
        }

        func blockSep() {
            if current.length > 0 {
                let sep = NSAttributedString(string: "\n\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 4),
                    .foregroundColor: NSColor.clear
                ])
                current.append(sep)
            }
        }

        let defaultFont = NSFont.systemFont(ofSize: 14)
        let defaultColor = NSColor.labelColor
        let monoFont = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 4
        bodyStyle.paragraphSpacing = 6

        let codeBg = NSColor(white: 0.12, alpha: 1.0)
        let codePadStyle = NSMutableParagraphStyle()
        codePadStyle.headIndent = 16
        codePadStyle.firstLineHeadIndent = 16
        codePadStyle.tailIndent = -16
        let codeLabelColor = NSColor(white: 0.55, alpha: 1.0)

        for (index, block) in blocks.enumerated() {
            switch block {
            case .paragraph(let text):
                blockSep()
                let paraAttr = NSMutableAttributedString(attributedString: inlineToNS(text, font: defaultFont, color: defaultColor))
                paraAttr.addAttribute(.paragraphStyle, value: bodyStyle, range: NSRange(location: 0, length: paraAttr.length))
                current.append(paraAttr)

            case .heading(let level, let text):
                blockSep()
                let headingStyle = NSMutableParagraphStyle()
                headingStyle.lineSpacing = 4
                headingStyle.paragraphSpacing = 4
                let headingAttr = NSMutableAttributedString(attributedString: inlineToNS(text, font: headingNSFont(level), color: defaultColor))
                headingAttr.addAttribute(.paragraphStyle, value: headingStyle, range: NSRange(location: 0, length: headingAttr.length))
                current.append(headingAttr)

            case .code(let lang, let code):
                blockSep()

                // Top padding line
                current.append(NSAttributedString(string: "\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 6),
                    .backgroundColor: codeBg,
                    .foregroundColor: NSColor.clear,
                    .paragraphStyle: codePadStyle
                ]))

                // Language label
                if let lang, !lang.isEmpty {
                    let labelStyle = codePadStyle.mutableCopy() as! NSMutableParagraphStyle
                    labelStyle.paragraphSpacingBefore = 0
                    current.append(NSAttributedString(string: lang.uppercased() + "\n", attributes: [
                        .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                        .foregroundColor: codeLabelColor,
                        .backgroundColor: codeBg,
                        .paragraphStyle: labelStyle
                    ]))
                }

                // Code content
                let codeAttr: NSMutableAttributedString
                if let highlighted = highlightedCode[index] {
                    codeAttr = NSMutableAttributedString(attributedString: highlighted)
                    let range = NSRange(location: 0, length: codeAttr.length)
                    codeAttr.enumerateAttribute(.font, in: range, options: []) { value, r, _ in
                        if value == nil {
                            codeAttr.addAttribute(.font, value: monoFont, range: r)
                        } else if let f = value as? NSFont {
                            let traits = f.fontDescriptor.symbolicTraits
                            var desc = monoFont.fontDescriptor
                            desc = desc.withSymbolicTraits(traits)
                            codeAttr.addAttribute(.font, value: NSFont(descriptor: desc, size: monoFont.pointSize) ?? monoFont, range: r)
                        }
                    }
                    codeAttr.addAttribute(.backgroundColor, value: codeBg, range: range)
                    codeAttr.addAttribute(.paragraphStyle, value: codePadStyle, range: range)
                } else {
                    codeAttr = NSMutableAttributedString(string: code)
                    let range = NSRange(location: 0, length: codeAttr.length)
                    codeAttr.addAttribute(.font, value: monoFont, range: range)
                    codeAttr.addAttribute(.foregroundColor, value: NSColor(white: 0.85, alpha: 1.0), range: range)
                    codeAttr.addAttribute(.backgroundColor, value: codeBg, range: range)
                    codeAttr.addAttribute(.paragraphStyle, value: codePadStyle, range: range)
                }
                current.append(codeAttr)

                // Bottom padding line
                current.append(NSAttributedString(string: "\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 6),
                    .backgroundColor: codeBg,
                    .foregroundColor: NSColor.clear,
                    .paragraphStyle: codePadStyle
                ]))

            case .unorderedList(let listItems):
                blockSep()
                let listStyle = NSMutableParagraphStyle()
                listStyle.headIndent = 20
                listStyle.firstLineHeadIndent = 8
                listStyle.lineSpacing = 4
                listStyle.paragraphSpacing = 2
                let tabStop = NSTextTab(textAlignment: .left, location: 20)
                listStyle.tabStops = [tabStop]

                for (idx, item) in listItems.enumerated() {
                    if idx > 0 {
                        current.append(NSAttributedString(string: "\n", attributes: [.font: defaultFont]))
                    }
                    let bullet = NSMutableAttributedString(string: "\u{2022}\t", attributes: [
                        .font: defaultFont,
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .paragraphStyle: listStyle
                    ])
                    current.append(bullet)
                    let itemAttr = inlineToNS(item, font: defaultFont, color: defaultColor)
                    let mutable = NSMutableAttributedString(attributedString: itemAttr)
                    mutable.addAttribute(.paragraphStyle, value: listStyle, range: NSRange(location: 0, length: mutable.length))
                    current.append(mutable)
                }

            case .orderedList(let listItems):
                blockSep()
                let listStyle = NSMutableParagraphStyle()
                listStyle.headIndent = 24
                listStyle.firstLineHeadIndent = 8
                listStyle.lineSpacing = 4
                listStyle.paragraphSpacing = 2
                let tabStop = NSTextTab(textAlignment: .left, location: 24)
                listStyle.tabStops = [tabStop]

                for (idx, item) in listItems.enumerated() {
                    if idx > 0 {
                        current.append(NSAttributedString(string: "\n", attributes: [.font: defaultFont]))
                    }
                    let num = NSMutableAttributedString(string: "\(idx + 1).\t", attributes: [
                        .font: defaultFont,
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .paragraphStyle: listStyle
                    ])
                    current.append(num)
                    let itemAttr = inlineToNS(item, font: defaultFont, color: defaultColor)
                    let mutable = NSMutableAttributedString(attributedString: itemAttr)
                    mutable.addAttribute(.paragraphStyle, value: listStyle, range: NSRange(location: 0, length: mutable.length))
                    current.append(mutable)
                }

            case .blockquote(let text):
                blockSep()
                let quoteStyle = NSMutableParagraphStyle()
                quoteStyle.headIndent = 16
                quoteStyle.firstLineHeadIndent = 16
                quoteStyle.lineSpacing = 4
                let quoteAttr = inlineToNS(text, font: defaultFont, color: NSColor.secondaryLabelColor)
                let mutable = NSMutableAttributedString(attributedString: quoteAttr)
                mutable.addAttribute(.paragraphStyle, value: quoteStyle, range: NSRange(location: 0, length: mutable.length))
                current.append(mutable)

            case .thematicBreak:
                blockSep()
                let hr = NSAttributedString(string: "\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}", attributes: [
                    .font: defaultFont,
                    .foregroundColor: NSColor.separatorColor
                ])
                current.append(hr)

            case .image(let alt, let url):
                flushText()
                items.append(.image(alt: alt, url: url))

            case .table(let t):
                flushText()
                items.append(.table(t))
            }
        }
        flushText()
        return items
    }

    @ViewBuilder
    private func renderItemView(_ item: RenderItem) -> some View {
        switch item {
        case .textRun(let nsAttr):
            SelectableTextView(nsAttributedString: nsAttr)

        case .image(let alt, let url):
            ImageThumbnailView(item: .imageURL(url: url, alt: alt))

        case .table(let table):
            MarkdownTableView(table: table, renderInline: inlineMarkdown)
        }
    }

    // MARK: - NSAttributedString helpers

    private func inlineToNS(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        let swiftAttr = inlineMarkdown(text)
        let nsAttr = NSMutableAttributedString(attributedString: NSAttributedString(swiftAttr))
        let fullRange = NSRange(location: 0, length: nsAttr.length)

        nsAttr.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            if value == nil {
                nsAttr.addAttribute(.font, value: font, range: range)
            } else if let existingFont = value as? NSFont {
                let traits = existingFont.fontDescriptor.symbolicTraits
                var descriptor = font.fontDescriptor
                descriptor = descriptor.withSymbolicTraits(traits)
                nsAttr.addAttribute(.font, value: NSFont(descriptor: descriptor, size: font.pointSize) ?? font, range: range)
            }
        }
        nsAttr.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if value == nil {
                nsAttr.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
        return nsAttr
    }

    private func headingNSFont(_ level: Int) -> NSFont {
        switch level {
        case 1: .systemFont(ofSize: 24, weight: .bold)
        case 2: .systemFont(ofSize: 20, weight: .bold)
        case 3: .systemFont(ofSize: 17, weight: .semibold)
        default: .systemFont(ofSize: 15, weight: .semibold)
        }
    }

    func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

// MARK: - Hover Copy Button

private struct HoverCopyButton: ViewModifier {
    let textToCopy: String
    @State private var isHovering = false
    @State private var copied = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if isHovering || copied {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(textToCopy, forType: .string)
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if copied {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                                Text("Copied!")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .transition(.opacity)
                }
            }
            .onHover { isHovering = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .animation(.easeInOut(duration: 0.15), value: copied)
    }
}

extension View {
    func hoverCopyButton(text: String) -> some View {
        modifier(HoverCopyButton(textToCopy: text))
    }
}

// MARK: - Selectable Text (NSTextView wrapper)

class SelectableNSTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let layoutManager, let textContainer else {
            return super.intrinsicContentSize
        }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(usedRect.height))
    }

    override func layout() {
        super.layout()
        invalidateIntrinsicContentSize()
    }
}

struct SelectableTextView: NSViewRepresentable {
    let nsAttributedString: NSAttributedString

    func makeNSView(context: Context) -> SelectableNSTextView {
        let tv = SelectableNSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        tv.isVerticallyResizable = false
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.required, for: .vertical)
        return tv
    }

    func updateNSView(_ tv: SelectableNSTextView, context: Context) {
        tv.textStorage?.setAttributedString(nsAttributedString)
        tv.invalidateIntrinsicContentSize()
    }
}

// MARK: - Table

struct ParsedTable {
    let headers: [String]
    let alignments: [Alignment]
    let rows: [[String]]
}

private struct MarkdownTableView: View {
    let table: ParsedTable
    let renderInline: (String) -> AttributedString

    private var columnMinWidths: [CGFloat] {
        (0..<table.headers.count).map { col in
            var maxLen = table.headers[col].count
            for row in table.rows {
                if col < row.count { maxLen = max(maxLen, row[col].count) }
            }
            return CGFloat(max(maxLen, 2)) * 7
        }
    }

    var body: some View {
        let minWidths = columnMinWidths

        VStack(spacing: 0) {
            tableRow(cells: table.headers, isHeader: true, rowIndex: -1, minWidths: minWidths)
            Divider()

            ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIdx, row in
                tableRow(cells: row, isHeader: false, rowIndex: rowIdx, minWidths: minWidths)
                if rowIdx < table.rows.count - 1 {
                    Divider().opacity(0.5)
                }
            }
        }
        .font(.callout)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private func tableRow(cells: [String], isHeader: Bool, rowIndex: Int, minWidths: [CGFloat]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { col, cell in
                Text(isHeader ? renderInline("**\(cell)**") : renderInline(cell))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(minWidth: minWidths[safe: col] ?? 20, maxWidth: .infinity, alignment: table.alignments[safe: col] ?? .leading)
            }
        }
        .background(
            isHeader
                ? Color.secondary.opacity(0.2)
                : (rowIndex % 2 != 0 ? Color.secondary.opacity(0.07) : Color.clear)
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Block Parser

private enum MarkdownBlock {
    case paragraph(String)
    case heading(Int, String)
    case code(String?, String)
    case unorderedList([String])
    case orderedList([String])
    case blockquote(String)
    case table(ParsedTable)
    case thematicBreak
    case image(alt: String, url: URL)
}

extension MarkdownView {
    private func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 }
                blocks.append(.code(lang.isEmpty ? nil : lang, codeLines.joined(separator: "\n")))
                continue
            }

            // Heading
            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                i += 1
                continue
            }

            // Thematic break
            if isThematicBreak(trimmed) {
                blocks.append(.thematicBreak)
                i += 1
                continue
            }

            // Table
            if trimmed.contains("|"),
               i + 1 < lines.count,
               isTableSeparator(lines[i + 1].trimmingCharacters(in: .whitespaces)) {
                if let table = parseTable(lines: lines, from: &i) {
                    blocks.append(.table(table))
                    continue
                }
            }

            // Unordered list
            if parseUnorderedItem(trimmed) != nil {
                var items: [String] = []
                while i < lines.count, let item = parseUnorderedItem(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(item)
                    i += 1
                }
                blocks.append(.unorderedList(items))
                continue
            }

            // Ordered list
            if parseOrderedItem(trimmed) != nil {
                var items: [String] = []
                while i < lines.count, let item = parseOrderedItem(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(item)
                    i += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    var stripped = lines[i].trimmingCharacters(in: .whitespaces)
                    stripped = String(stripped.dropFirst(1))
                    if stripped.hasPrefix(" ") { stripped = String(stripped.dropFirst(1)) }
                    quoteLines.append(stripped)
                    i += 1
                }
                blocks.append(.blockquote(quoteLines.joined(separator: "\n")))
                continue
            }

            // Standalone image
            if let imageBlock = parseImageLine(trimmed) {
                blocks.append(imageBlock)
                i += 1
                continue
            }

            // Empty line
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Paragraph
            var paraLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                let lt = l.trimmingCharacters(in: .whitespaces)
                if lt.isEmpty
                    || lt.hasPrefix("```")
                    || parseHeading(lt) != nil
                    || parseUnorderedItem(lt) != nil
                    || parseOrderedItem(lt) != nil
                    || lt.hasPrefix(">")
                    || isThematicBreak(lt)
                    || parseImageLine(lt) != nil
                    || (lt.contains("|") && i + 1 < lines.count && isTableSeparator(lines[i + 1].trimmingCharacters(in: .whitespaces))) {
                    break
                }
                paraLines.append(l)
                i += 1
            }
            if !paraLines.isEmpty {
                blocks.append(.paragraph(paraLines.joined(separator: "\n")))
            }
        }

        return blocks
    }

    private func parseImageLine(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix("![") else { return nil }
        guard let closeBracket = line.firstIndex(of: "]"),
              closeBracket < line.endIndex else { return nil }
        let afterBracket = line.index(after: closeBracket)
        guard afterBracket < line.endIndex, line[afterBracket] == "(" else { return nil }
        guard let closeParen = line.lastIndex(of: ")") else { return nil }
        let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<closeBracket])
        let urlStr = String(line[line.index(after: afterBracket)..<closeParen])
        guard let url = URL(string: urlStr) else { return nil }
        return .image(alt: alt, url: url)
    }

    private func parseHeading(_ line: String) -> MarkdownBlock? {
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 }
            else { break }
        }
        guard level >= 1, level <= 6, line.count > level, line[line.index(line.startIndex, offsetBy: level)] == " " else {
            return nil
        }
        let text = String(line.dropFirst(level + 1))
        return .heading(level, text)
    }

    private func parseUnorderedItem(_ line: String) -> String? {
        guard line.count >= 2 else { return nil }
        let first = line.first!
        guard first == "-" || first == "*" || first == "+" else { return nil }
        let second = line[line.index(after: line.startIndex)]
        guard second == " " else { return nil }
        return String(line.dropFirst(2))
    }

    private func parseOrderedItem(_ line: String) -> String? {
        var digitEnd = line.startIndex
        while digitEnd < line.endIndex && line[digitEnd].isNumber {
            digitEnd = line.index(after: digitEnd)
        }
        guard digitEnd > line.startIndex, digitEnd < line.endIndex else { return nil }
        let sep = line[digitEnd]
        guard sep == "." || sep == ")" else { return nil }
        let afterSep = line.index(after: digitEnd)
        guard afterSep < line.endIndex, line[afterSep] == " " else { return nil }
        return String(line[line.index(after: afterSep)...])
    }

    private func isThematicBreak(_ line: String) -> Bool {
        let stripped = line.filter { !$0.isWhitespace }
        guard stripped.count >= 3 else { return false }
        let first = stripped.first!
        guard first == "-" || first == "*" || first == "_" else { return false }
        return stripped.allSatisfy { $0 == first }
    }

    private func isTableSeparator(_ line: String) -> Bool {
        let cells = splitTableCells(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let t = cell.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return false }
            let inner = t.filter { $0 != "-" && $0 != ":" }
            return inner.isEmpty && t.contains("-")
        }
    }

    private func parseTableAlignment(_ cell: String) -> Alignment {
        let t = cell.trimmingCharacters(in: .whitespaces)
        let left = t.hasPrefix(":")
        let right = t.hasSuffix(":")
        if left && right { return .center }
        if right { return .trailing }
        return .leading
    }

    private func splitTableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func parseTable(lines: [String], from i: inout Int) -> ParsedTable? {
        let headerCells = splitTableCells(lines[i])
        let separatorCells = splitTableCells(lines[i + 1])
        guard !headerCells.isEmpty, headerCells.count == separatorCells.count else { return nil }

        let alignments = separatorCells.map { parseTableAlignment($0) }
        let colCount = headerCells.count
        i += 2

        var rows: [[String]] = []
        while i < lines.count {
            let lt = lines[i].trimmingCharacters(in: .whitespaces)
            guard lt.contains("|") else { break }
            var cells = splitTableCells(lt)
            while cells.count < colCount { cells.append("") }
            if cells.count > colCount { cells = Array(cells.prefix(colCount)) }
            rows.append(cells)
            i += 1
        }

        return ParsedTable(headers: headerCells, alignments: alignments, rows: rows)
    }
}
