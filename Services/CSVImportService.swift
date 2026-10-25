import Foundation

// MARK: - CSVImportService
/// Parses CSV/tab-separated vocabulary files into normalized entry lines that
/// feed the existing clean pre-compiled list pipeline. Accepts:
/// - Locklish's own export (header `Word;IPA;Part of Speech;Meaning;…`)
/// - Anki/Quizlet exports (`front;back` or `front,back`, quoted fields allowed)
/// - Plain "word,meaning" lists with or without a header row
enum CSVImportService {

    // MARK: - Public Entry Point

    /// Returns normalized `word /ipa/ (pos): meaning Ex: example (translation)`
    /// lines ready for the pre-compiled parser, plus how many data rows were read.
    static func parseToEntryLines(_ raw: String) -> (lines: [String], rowCount: Int) {
        let rows = parseRows(raw)
        guard !rows.isEmpty else { return ([], 0) }

        let (mapping, dataRows) = mappingAndData(for: rows)
        var lines: [String] = []

        for row in dataRows {
            let cells = padded(row, to: mapping.count)
            let word = cell(cells, mapping.word)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !word.isEmpty else { continue }

            var line = word
            if let ipa = cell(cells, mapping.ipa), !ipa.isEmpty {
                let clean = ipa.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
                if !clean.isEmpty { line += " /\(clean)/" }
            }
            if let pos = cell(cells, mapping.pos), !pos.isEmpty {
                line += " (\(pos))"
            }
            if let meaning = cell(cells, mapping.meaning), !meaning.isEmpty {
                line += ": \(meaning)"
            }
            if let example = cell(cells, mapping.example), !example.isEmpty {
                line += " Ex: \(example)"
                if let translation = cell(cells, mapping.exampleTranslation), !translation.isEmpty {
                    line += " (\(translation))"
                }
            }
            lines.append(line)
        }

        return (lines, dataRows.count)
    }

    // MARK: - Row Parsing (RFC-4180-style with auto delimiter)

    private static func parseRows(_ raw: String) -> [[String]] {
        var text = raw
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() } // Excel UTF-8 BOM
        text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")

        let delimiter = detectDelimiter(in: text)
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false
        var fieldJustClosedQuote = false

        var iterator = text.makeIterator()
        var pending: Character? = nil

        func nextChar() -> Character? {
            if let c = pending { pending = nil; return c }
            return iterator.next()
        }

        while let ch = nextChar() {
            if inQuotes {
                if ch == "\"" {
                    if let peek = iterator.next() {
                        if peek == "\"" { field.append("\"") }
                        else { inQuotes = false; fieldJustClosedQuote = true; pending = peek }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                if ch == "\"" && field.isEmpty {
                    inQuotes = true
                } else if ch == delimiter {
                    current.append(field)
                    field = ""
                } else if ch == "\n" {
                    current.append(field)
                    field = ""
                    if !(current.count == 1 && current[0].isEmpty) { rows.append(current) }
                    current = []
                } else {
                    field.append(ch)
                }
            }
            if !inQuotes { _ = fieldJustClosedQuote; fieldJustClosedQuote = false }
        }

        current.append(field)
        if !(current.count == 1 && current[0].isEmpty) { rows.append(current) }

        return rows
    }

    /// Picks the delimiter by frequency on the first non-empty line; `;` wins
    /// ties (Vietnamese Excel locale + Anki default), then tab, then comma.
    private static func detectDelimiter(in text: String) -> Character {
        let firstLine = text.components(separatedBy: .newlines).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        let semis = firstLine.filter { $0 == ";" }.count
        let tabs = firstLine.filter { $0 == "\t" }.count
        let commas = firstLine.filter { $0 == "," }.count

        if semis >= tabs && semis >= commas && semis > 0 { return ";" }
        if tabs > 0 && tabs >= commas { return "\t" }
        if commas > 0 { return "," }
        return ";"
    }

    // MARK: - Header Mapping

    private struct ColumnMapping {
        var word: Int = 0
        var meaning: Int? = nil
        var ipa: Int? = nil
        var pos: Int? = nil
        var example: Int? = nil
        var exampleTranslation: Int? = nil
        var count: Int = 1
    }

    private static func mappingAndData(for rows: [[String]]) -> (ColumnMapping, [[String]]) {
        guard let first = rows.first else { return (ColumnMapping(), rows) }
        let lowered = first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        func find(_ candidates: [String]) -> Int? {
            lowered.firstIndex { cell in candidates.contains { cell.contains($0) } }
        }

        let headerIdx = find(["word", "front", "term", "english", "từ"])
        let meaningIdx = find(["meaning", "definition", "back", "nghĩa", "nghia", "vietnamese"])
        let isHeader = headerIdx != nil || (meaningIdx != nil && lowered.count >= 2)

        if isHeader {
            var mapping = ColumnMapping()
            mapping.word = headerIdx ?? 0
            mapping.meaning = meaningIdx
            mapping.ipa = find(["ipa", "phonetic"])
            mapping.pos = find(["part of speech", "partofspeech", "pos", "loại từ", "loai tu"])
            if mapping.pos != nil && lowered[mapping.pos!] == "pos" { /* fine */ }
            mapping.example = find(["example", "ví dụ", "vi du", "sentence"])
            mapping.exampleTranslation = find(["translation", "dịch", "dich"])
            mapping.count = lowered.count
            return (mapping, Array(rows.dropFirst()))
        }

        // No header: word first, meaning second when present
        var mapping = ColumnMapping()
        mapping.count = max(first.count, 1)
        if first.count >= 2 { mapping.meaning = 1 }
        if first.count >= 3 { mapping.example = 2 }
        return (mapping, rows)
    }

    private static func padded(_ row: [String], to count: Int) -> [String] {
        row + Array(repeating: "", count: max(0, count - row.count))
    }

    private static func cell(_ cells: [String], _ index: Int?) -> String? {
        guard let index, cells.indices.contains(index) else { return nil }
        return cells[index]
    }
}
