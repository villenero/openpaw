import SwiftUI
import HighlightSwift

struct MarkdownView: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(inlineMarkdown(text))
                .textSelection(.enabled)

        case .heading(let level, let text):
            Text(inlineMarkdown(text))
                .font(headingFont(level))
                .fontWeight(.semibold)
                .textSelection(.enabled)

        case .code(let lang, let code):
            CodeBlockView(language: lang, code: code)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\u{2022}")
                            .foregroundStyle(.secondary)
                        Text(inlineMarkdown(item))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.leading, 8)

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(idx + 1).")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(inlineMarkdown(item))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.leading, 8)

        case .blockquote(let text):
            BlockquoteView(text: text, renderInline: inlineMarkdown)

        case .table(let table):
            MarkdownTableView(table: table, renderInline: inlineMarkdown)

        case .thematicBreak:
            Divider()
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title
        case 2: .title2
        case 3: .title3
        default: .headline
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
    fileprivate func hoverCopyButton(text: String) -> some View {
        modifier(HoverCopyButton(textToCopy: text))
    }
}

// MARK: - Code Block

private struct CodeBlockView: View {
    let language: String?
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                Text(language)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            CodeText(code)
                .highlightLanguage(highlightLanguage)
                .codeTextColors(.theme(.atomOne))
                .codeTextStyle(.plain)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, language?.isEmpty == false ? 4 : 10)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.textBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .hoverCopyButton(text: code)
    }

    private static let fenceToLanguage: [String: HighlightLanguage] = [
        "js": .javaScript, "javascript": .javaScript,
        "ts": .typeScript, "typescript": .typeScript,
        "cpp": .cPlusPlus, "c++": .cPlusPlus,
        "cs": .cSharp, "csharp": .cSharp,
        "objc": .objectiveC, "objective-c": .objectiveC, "objectivec": .objectiveC,
        "rb": .ruby,
        "py": .python,
        "sh": .bash, "zsh": .bash,
        "yml": .yaml,
        "tex": .latex,
        "gql": .graphQL, "graphql": .graphQL,
        "proto": .protocolBuffers,
        "vb": .visualBasic,
        "wasm": .webAssembly,
        "pg": .postgreSQL, "postgres": .postgreSQL, "postgresql": .postgreSQL,
        "md": .markdown,
        "hs": .haskell,
    ]

    private var highlightLanguage: HighlightLanguage {
        guard let language, !language.isEmpty else { return .plaintext }
        let key = language.lowercased()
        if let mapped = Self.fenceToLanguage[key] { return mapped }
        return HighlightLanguage(rawValue: key) ?? .plaintext
    }
}

// MARK: - Blockquote

private struct BlockquoteView: View {
    let text: String
    let renderInline: (String) -> AttributedString

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(.tertiary)
                .frame(width: 3)
            Text(renderInline(text))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.leading, 10)
        }
        .padding(.leading, 4)
        .hoverCopyButton(text: text)
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

    /// Min width per column proportional to max content length (in chars × 7pt).
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
                if i < lines.count { i += 1 } // skip closing ```
                blocks.append(.code(lang.isEmpty ? nil : lang, codeLines.joined(separator: "\n")))
                continue
            }

            // Heading
            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                i += 1
                continue
            }

            // Thematic break (---, ***, ___)
            if isThematicBreak(trimmed) {
                blocks.append(.thematicBreak)
                i += 1
                continue
            }

            // Table: header line with |, followed by separator line |---|
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
                    stripped = String(stripped.dropFirst(1)) // drop >
                    if stripped.hasPrefix(" ") { stripped = String(stripped.dropFirst(1)) }
                    quoteLines.append(stripped)
                    i += 1
                }
                blocks.append(.blockquote(quoteLines.joined(separator: "\n")))
                continue
            }

            // Empty line — skip
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Paragraph — collect contiguous lines
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

    // MARK: - Table parsing

    private func isTableSeparator(_ line: String) -> Bool {
        let cells = splitTableCells(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let t = cell.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return false }
            // Must be dashes with optional leading/trailing colons: :---, :---:, ---:
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
        // Remove leading and trailing pipes
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
        i += 2 // skip header + separator

        var rows: [[String]] = []
        while i < lines.count {
            let lt = lines[i].trimmingCharacters(in: .whitespaces)
            guard lt.contains("|") else { break }
            var cells = splitTableCells(lt)
            // Pad or trim to match header column count
            while cells.count < colCount { cells.append("") }
            if cells.count > colCount { cells = Array(cells.prefix(colCount)) }
            rows.append(cells)
            i += 1
        }

        return ParsedTable(headers: headerCells, alignments: alignments, rows: rows)
    }
}
