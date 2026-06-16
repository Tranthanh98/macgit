//
//  SyntaxHighlighter.swift
//  macgit
//

import Foundation
import SwiftUI

struct SyntaxHighlighter {
    enum TokenType {
        case keyword
        case string
        case comment
        case number
        case type
        case attribute
        case normal
    }

    struct TokenRule {
        let regex: NSRegularExpression
        let type: TokenType
    }

    private let rules: [TokenRule]
    private let fileExtension: String

    init(fileExtension: String) {
        self.fileExtension = fileExtension.lowercased()
        self.rules = SyntaxHighlighter.rules(for: self.fileExtension)
    }

    func attributedString(for text: String, fontSize: CGFloat = 12) -> AttributedString {
        var attributed = AttributedString(text)
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        attributed.font = Font(baseFont)
        attributed.foregroundColor = .primary

        var tokenRanges: [(NSRange, TokenType)] = []

        for rule in rules {
            let matches = rule.regex.matches(in: text, range: fullRange)
            for match in matches {
                let range = match.range
                if range.location != NSNotFound {
                    tokenRanges.append((range, rule.type))
                }
            }
        }

        tokenRanges.sort { $0.0.location < $1.0.location }

        var mergedRanges: [(NSRange, TokenType)] = []
        for (range, type) in tokenRanges {
            if let last = mergedRanges.last, NSIntersectionRange(last.0, range).length > 0 {
                if range.length > last.0.length {
                    mergedRanges[mergedRanges.count - 1] = (range, type)
                }
            } else {
                mergedRanges.append((range, type))
            }
        }

        for (range, type) in mergedRanges {
            if let swiftRange = Range(range, in: text) {
                let attrRange = convertRange(swiftRange, in: attributed)
                switch type {
                case .keyword:
                    attributed[attrRange].foregroundColor = Color(nsColor: NSColor(calibratedRed: 0.80, green: 0.35, blue: 0.60, alpha: 1.0))
                case .string:
                    attributed[attrRange].foregroundColor = Color(nsColor: NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.20, alpha: 1.0))
                case .comment:
                    attributed[attrRange].foregroundColor = Color(nsColor: NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.50, alpha: 1.0))
                case .number:
                    attributed[attrRange].foregroundColor = Color(nsColor: NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.75, alpha: 1.0))
                case .type:
                    attributed[attrRange].foregroundColor = Color(nsColor: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.70, alpha: 1.0))
                case .attribute:
                    attributed[attrRange].foregroundColor = Color(nsColor: NSColor(calibratedRed: 0.65, green: 0.40, blue: 0.20, alpha: 1.0))
                case .normal:
                    break
                }
            }
        }

        return attributed
    }

    private func convertRange(_ range: Range<String.Index>, in attributed: AttributedString) -> Range<AttributedString.Index> {
        let start = AttributedString.Index(range.lowerBound, within: attributed)!
        let end = AttributedString.Index(range.upperBound, within: attributed)!
        return start..<end
    }

    static func rules(for ext: String) -> [TokenRule] {
        let commonKeywords = [
            "func", "var", "let", "if", "else", "for", "while", "return", "import", "class", "struct", "enum",
            "protocol", "extension", "init", "switch", "case", "default", "break", "continue", "in",
            "where", "typealias", "operator", "throws", "throw", "try", "catch", "do", "guard", "defer",
            "self", "Self", "super", "static", "final", "override", "open", "public", "internal", "private",
            "fileprivate", "weak", "inout", "await", "async", "actor", "some", "any", "macro",
            "const", "let", "var", "if", "else", "for", "while", "do", "switch", "case", "default",
            "break", "continue", "return", "goto", "typedef", "struct", "enum", "union", "extern",
            "static", "auto", "register", "volatile", "const", "sizeof", "inline", "restrict",
            "function", "class", "interface", "extends", "implements", "new", "this", "typeof",
            "instanceof", "in", "of", "async", "await", "yield", "default", "export", "from",
            "import", "package", "namespace", "module", "public", "protected", "private", "static",
            "abstract", "final", "synchronized", "throws", "throw", "try", "catch", "finally",
            "def", "class", "if", "elif", "else", "for", "while", "return", "import", "from",
            "as", "with", "try", "except", "finally", "raise", "assert", "lambda", "yield",
            "nonlocal", "global", "pass", "del", "and", "or", "not", "in", "is", "True", "False",
            "None", "async", "await", "match", "case", "print", "println", "let", "mut", "fn",
            "impl", "trait", "pub", "use", "mod", "crate", "self", "super", "unsafe", "extern",
            "where", "const", "static", "move", "loop", "if", "else", "for", "while", "match",
            "break", "continue", "return", "if", "else", "switch", "case", "default", "break",
            "continue", "return", "for", "while", "do", "goto", "function", "var", "let", "const",
            "typeof", "instanceof", "new", "this", "delete", "in", "of", "void", "with"
        ]
        let keywordPattern = commonKeywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let patterns: [(String, TokenType)]

        switch ext {
        case "swift":
            patterns = [
                ("//.*", .comment),
                ("/\\*.*?\\*/", .comment),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("'([^'\\\\\\\\]|\\\\\\\\.)*'", .string),
                ("#\\[.*\\]", .attribute),
                ("\\b(?:\(keywordPattern))\\b", .keyword),
                ("\\b[A-Z][A-Za-z0-9_]*\\b", .type),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
            ]
        case "js", "ts", "jsx", "tsx", "json":
            patterns = [
                ("//.*", .comment),
                ("/\\*.*?\\*/", .comment),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("'([^'\\\\\\\\]|\\\\\\\\.)*'", .string),
                ("`([^`\\\\\\\\]|\\\\\\\\.)*`", .string),
                ("\\b(?:\(keywordPattern))\\b", .keyword),
                ("\\b[A-Z][A-Za-z0-9_]*\\b", .type),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
            ]
        case "py":
            patterns = [
                ("#.*", .comment),
                ("\"\"\"[\\s\\S]*?\"\"\"", .string),
                ("'''[\\s\\S]*?'''", .string),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("'([^'\\\\\\\\]|\\\\\\\\.)*'", .string),
                ("\\b(?:\(keywordPattern))\\b", .keyword),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
            ]
        case "c", "cpp", "h", "hpp", "m", "mm":
            patterns = [
                ("//.*", .comment),
                ("/\\*.*?\\*/", .comment),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("'([^'\\\\\\\\]|\\\\\\\\.)*'", .string),
                ("\\b(?:\(keywordPattern))\\b", .keyword),
                ("\\b[A-Z][A-Za-z0-9_]*\\b", .type),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
                ("#\\w+", .attribute),
            ]
        case "go":
            patterns = [
                ("//.*", .comment),
                ("/\\*.*?\\*/", .comment),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("`([^`\\\\\\\\]|\\\\\\\\.)*`", .string),
                ("\\b(?:\(keywordPattern))\\b", .keyword),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
            ]
        case "rs":
            patterns = [
                ("//.*", .comment),
                ("/\\*.*?\\*/", .comment),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("'([^'\\\\\\\\]|\\\\\\\\.)*'", .string),
                ("\\b(?:\(keywordPattern))\\b", .keyword),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
                ("#\\w+", .attribute),
            ]
        case "java", "kt":
            patterns = [
                ("//.*", .comment),
                ("/\\*.*?\\*/", .comment),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("'([^'\\\\\\\\]|\\\\\\\\.)*'", .string),
                ("\\b(?:\(keywordPattern))\\b", .keyword),
                ("\\b[A-Z][A-Za-z0-9_]*\\b", .type),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
                ("@\\w+", .attribute),
            ]
        case "sh", "bash", "zsh":
            patterns = [
                ("#.*", .comment),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("'([^'\\\\\\\\]|\\\\\\\\.)*'", .string),
                ("\\b(?:\(keywordPattern))\\b", .keyword),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
            ]
        case "yaml", "yml":
            patterns = [
                ("#.*", .comment),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("'([^'\\\\\\\\]|\\\\\\\\.)*'", .string),
                ("\\b(?:\(keywordPattern))\\b", .keyword),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
            ]
        case "sql":
            patterns = [
                ("--.*", .comment),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("'([^'\\\\\\\\]|\\\\\\\\.)*'", .string),
                ("\\b(?:SELECT|INSERT|UPDATE|DELETE|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|OUTER|ON|GROUP|BY|ORDER|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|CREATE|TABLE|INDEX|DROP|ALTER|ADD|COLUMN|VALUES|SET|AND|OR|NOT|NULL|IS|IN|BETWEEN|LIKE|EXISTS|CASE|WHEN|THEN|ELSE|END|AS|WITH|RECURSIVE|RETURNING|INTO|USING|NATURAL|CROSS|FULL|OUTER|JOIN|INNER|LEFT|RIGHT|ON|USING|GROUP|ORDER|LIMIT|OFFSET|FETCH|FOR|UPDATE|OF|NOWAIT|SKIP|LOCKED|SHARE|KEY|PRIMARY|FOREIGN|REFERENCES|CONSTRAINT|CHECK|DEFAULT|UNIQUE|INDEX|VIEW|TRIGGER|PROCEDURE|FUNCTION|DATABASE|SCHEMA|TRANSACTION|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|GRANT|REVOKE|PRIVILEGES|TO|IDENTIFIED|BY|PASSWORD|ACCOUNT|LOCK|UNLOCK|IF|EXISTS|CASCADE|RESTRICT|CASCADE|RESTRICT|IF|EXISTS|CASCADE|RESTRICT)\\b", .keyword),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
            ]
        default:
            patterns = [
                ("//.*", .comment),
                ("/\\*.*?\\*/", .comment),
                ("#.*", .comment),
                ("\"([^\"\\\\\\\\]|\\\\\\\\.)*\"", .string),
                ("'([^'\\\\\\\\]|\\\\\\\\.)*'", .string),
                ("\\b(?:\(keywordPattern))\\b", .keyword),
                ("\\b\\d+(\\.\\d+)?\\b", .number),
            ]
        }

        return patterns.compactMap { pattern, type in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
            return TokenRule(regex: regex, type: type)
        }
    }
}
