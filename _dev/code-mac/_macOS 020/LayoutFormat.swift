//
//  LayoutFormat.swift
//  hypetype
//
//  Чистый парсер/сериализатор формата config.ini v2 (FORMAT.md).
//  String ⇄ Layout. Никакого I/O, никакого UI — полностью тестируемо.
//

import Foundation
import OSLog

nonisolated enum LayoutFormat {
    private static let log = Logger(subsystem: "hypetype", category: "LayoutFormat")

    /// Лимит кодпоинтов на одно значение (§4.2).
    static let maxCodepoints = 32

    /// Имя собственной платформенной секции на macOS (§3.3).
    static let ownPlatformSection = "macOS"

    // MARK: - Парсинг (String → Layout)

    static func parse(_ rawText: String, ownPlatform: String = ownPlatformSection) -> Layout {
        var layout = Layout(version: 0)   // 0 = [hypetype]/version не встречен (legacy)

        // BOM в начале файла допустим при чтении (§2), отбрасываем.
        var text = rawText
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

        // Принимаем оба перевода строки (§2). enumerateLines корректно режет
        // по \n / \r / \r\n и убирает терминаторы. ВАЖНО: split(separator:"\n")
        // здесь не годится — "\r\n" в Swift это один Character, и сплит его не находит.
        var lines: [String] = []
        text.enumerateLines { line, _ in lines.append(line) }

        enum SectionKind { case hypetype, layout, ownPlatform, typograph, foreign(String) }
        var current: SectionKind? = nil
        var foreignBuffer: [String] = []
        var foreignName: String? = nil

        func flushForeign() {
            if let name = foreignName {
                layout.foreignSections.append(ForeignSection(name: name, lines: foreignBuffer))
            }
            foreignBuffer = []
            foreignName = nil
        }

        for line in lines {
            // Для определения заголовков работаем по «эффективной» строке (§2.1 п.1–2).
            let effective = stripComment(line).trimmingCharacters(in: .whitespaces)

            // Заголовок секции [Name]?
            if effective.hasPrefix("["), effective.hasSuffix("]"), effective.count >= 2 {
                let name = String(effective.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                flushForeign()
                switch name {
                case "hypetype":                    current = .hypetype
                case "Layout":                      current = .layout
                case ownPlatform:                   current = .ownPlatform
                case TypographFormat.sectionName:   current = .typograph
                default:
                    current = .foreign(name)
                    foreignName = name
                }
                continue
            }

            switch current {
            case .foreign:
                // Тело чужой секции сохраняем verbatim (§7.1), кроме пустых строк
                // (чтобы пустые строки не накапливались на повторных round-trip).
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    foreignBuffer.append(line)
                }
            case .hypetype:
                if let (key, value) = keyValue(effective), key == "version" {
                    layout.version = Int(value) ?? layout.version
                }
            case .ownPlatform:
                if let (key, value) = keyValue(effective) {
                    layout.platformSettings.append(SettingEntry(key: key, value: value))
                }
            case .typograph:
                if let (key, value) = keyValue(effective) {
                    TypographFormat.apply(to: &layout.typograph, key: key, value: value)
                }
            case .layout:
                guard let (key, value) = keyValue(effective) else { continue }
                if KeyDefinitions.byW3CName[key] != nil {
                    // Известная клавиша
                    if let parsed = parseValue(value, key: key) {
                        if !parsed.isEmpty {            // §4.5: полностью пустая = отсутствие
                            layout.entries[key] = parsed
                        }
                    }
                    // невалидное значение — строка проигнорирована в parseValue с предупреждением
                } else {
                    // §4.6: неизвестная клавиша сохраняется как есть
                    layout.unknownLayoutEntries.append(LayoutRawEntry(key: key, rawValue: value))
                }
            case .none:
                continue   // строки до первой секции игнорируются
            }
        }
        flushForeign()

        return layout
    }

    // MARK: - Сериализация (Layout → String)

    static func serialize(_ layout: Layout, lineEnding: String = "\n", ownPlatform: String = ownPlatformSection) -> String {
        var sections: [String] = []

        // [hypetype]
        sections.append("[hypetype]\(lineEnding)version=\(max(layout.version, 2))")

        // [Layout] — известные ключи в порядке таблицы §5, затем неизвестные (§7.3).
        var layoutLines: [String] = []
        var knownPairs: [(line: String, comment: String)] = []
        for def in KeyDefinitions.all {
            guard let value = layout.entries[def.w3cName], !value.isEmpty else { continue }
            let pair = "\(def.w3cName)=\(formatValue(value))"
            knownPairs.append((pair, GlyphRenderer.comment(for: value)))
        }
        // Выравнивание комментариев по столбцу (детерминированно → идемпотентно).
        let width = knownPairs.map { $0.line.count }.max() ?? 0
        for kp in knownPairs {
            let padding = String(repeating: " ", count: width - kp.line.count)
            layoutLines.append("\(kp.line)\(padding)  ; \(kp.comment)")
        }
        for raw in layout.unknownLayoutEntries {
            layoutLines.append("\(raw.key)=\(raw.rawValue)")
        }
        sections.append((["[Layout]"] + layoutLines).joined(separator: lineEnding))

        // Секция типографа [Typograph] — всегда пишем полный набор ключей (дефолты не скрываем).
        let typographLines = TypographFormat.serialize(layout.typograph)
        sections.append((["[\(TypographFormat.sectionName)]"] + typographLines).joined(separator: lineEnding))

        // Собственная платформенная секция (если есть настройки).
        if !layout.platformSettings.isEmpty {
            let lines = layout.platformSettings.map { "\($0.key)=\($0.value)" }
            sections.append((["[\(ownPlatform)]"] + lines).joined(separator: lineEnding))
        }

        // Чужие секции — verbatim, в исходном порядке (§7.1).
        for section in layout.foreignSections {
            sections.append((["[\(section.name)]"] + section.lines).joined(separator: lineEnding))
        }

        // Секции разделяются пустой строкой, файл завершается переводом строки.
        return sections.joined(separator: "\(lineEnding)\(lineEnding)") + lineEnding
    }

    // MARK: - Hex-кодек значения (§4)

    /// Парсит `<alt>|<altShift>` в LayoutValue. nil = невалидно (строка игнорируется, §4.7).
    static func parseValue(_ value: String, key: String = "") -> LayoutValue? {
        // Ровно один разделитель '|'.
        let parts = value.components(separatedBy: "|")
        guard parts.count == 2 else {
            log.warning("Invalid value (expected one '|') for key \(key, privacy: .public): \(value, privacy: .public)")
            return nil
        }
        guard let alt = parseSequence(parts[0], key: key),
              let altShift = parseSequence(parts[1], key: key) else {
            return nil
        }
        return LayoutValue(alt: alt, altShift: altShift)
    }

    /// Парсит одну сторону: `codepoint *("+" codepoint)`. Пустая строка → []. nil = невалидно.
    static func parseSequence(_ side: String, key: String = "") -> [Unicode.Scalar]? {
        if side.isEmpty { return [] }
        var result: [Unicode.Scalar] = []
        for part in side.split(separator: "+", omittingEmptySubsequences: false) {
            guard part.count >= 1, part.count <= 6, part.allSatisfy(\.isHexDigit),
                  let v = UInt32(part, radix: 16),
                  v <= 0x10FFFF, !(0xD800...0xDFFF).contains(v),
                  let scalar = Unicode.Scalar(v) else {
                log.warning("Invalid codepoint '\(part, privacy: .public)' for key \(key, privacy: .public)")
                return nil
            }
            result.append(scalar)
        }
        // §4.2: значение длиннее лимита — обрезается до 32 с предупреждением.
        if result.count > maxCodepoints {
            log.warning("Value for key \(key, privacy: .public) exceeds \(maxCodepoints) codepoints — truncating")
            result = Array(result.prefix(maxCodepoints))
        }
        return result
    }

    /// Сериализует значение в `<alt>|<altShift>`, кодпоинты — uppercase hex, минимум 4 знака.
    static func formatValue(_ value: LayoutValue) -> String {
        "\(formatSequence(value.alt))|\(formatSequence(value.altShift))"
    }

    static func formatSequence(_ scalars: [Unicode.Scalar]) -> String {
        scalars.map { String(format: "%04X", $0.value) }.joined(separator: "+")
    }

    // MARK: - Хелперы парсинга строки (§2.1)

    /// Отбрасывает всё после первого ';' (§2.1 п.1).
    private static func stripComment(_ line: String) -> String {
        if let idx = line.firstIndex(of: ";") {
            return String(line[..<idx])
        }
        return line
    }

    /// Разбивает `key=value` по первому '=' (§2.1 п.5). nil — если '=' нет.
    private static func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let idx = line.firstIndex(of: "=") else { return nil }
        let key = line[..<idx].trimmingCharacters(in: .whitespaces)
        let value = line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        return (key, value)
    }
}
