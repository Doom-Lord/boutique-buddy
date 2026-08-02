//
//  CSVParser.swift
//  Boutique Buddy
//

import Foundation

struct CSVTable {
    var headers: [String]
    var rows: [[String]]

    var columnCount: Int { headers.count }
}

enum CSVParser {
    static func parse(contents: String) -> CSVTable {
        let lines = contents
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard let first = lines.first else {
            return CSVTable(headers: [], rows: [])
        }

        let headers = parseRow(first)
        let rows = lines.dropFirst().map { parseRow($0) }
        return CSVTable(headers: headers, rows: rows)
    }

    /// Simple CSV row parser supporting quoted fields.
    static func parseRow(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let char = line[index]
            if char == "\"" {
                let next = line.index(after: index)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    index = next
                } else {
                    inQuotes.toggle()
                }
            } else if char == ",", !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
            index = line.index(after: index)
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    static func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = ["dd/MM/yyyy", "yyyy-MM-dd", "d/M/yyyy", "dd-MM-yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.timeZone = TimeZone.current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    static func value(in row: [String], mapping: [String: Int], key: String) -> String {
        guard let index = mapping[key], index >= 0, index < row.count else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CSVImportSummary {
    var imported: Int = 0
    var skipped: [(row: Int, reason: String)] = []

    var hasSkips: Bool { !skipped.isEmpty }
}
