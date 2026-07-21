//
//  Layout.swift
//  hypetype
//
//  Доменная модель раскладки в памяти (§7 FORMAT.md — round-trip).
//  Чистые типы данных, без I/O и UI. Конвертация String ⇄ Layout — в LayoutFormat.swift.
//

import Foundation

/// Значение одной клавиши: что вводит Hyper+клавиша (alt) и Hyper+Shift+клавиша (altShift).
/// Хранится как массивы Unicode-скаляров (§4 — последовательности кодпоинтов).
nonisolated struct LayoutValue: Equatable {
    var alt: [Unicode.Scalar]
    var altShift: [Unicode.Scalar]

    var isEmpty: Bool { alt.isEmpty && altShift.isEmpty }

    static let empty = LayoutValue(alt: [], altShift: [])
}

/// Неизвестный ключ внутри [Layout] — сохраняется как есть для round-trip (§4.6, §7.2).
nonisolated struct LayoutRawEntry: Equatable {
    let key: String
    let rawValue: String   // verbatim текст значения после '=' (без комментария)
}

/// Пара ключ=значение платформенной секции (§3.3).
nonisolated struct SettingEntry: Equatable {
    let key: String
    let value: String
}

/// Чужая секция (для macOS это [Windows] и любые будущие) — сохраняется построчно (§7.1).
nonisolated struct ForeignSection: Equatable {
    let name: String        // без скобок
    let lines: [String]     // тело секции verbatim (с комментариями), без строки-заголовка
}

/// Полная модель распарсенного config.ini.
nonisolated struct Layout: Equatable {
    /// Версия формата (§3.1). 0 = секция [hypetype]/version отсутствует (legacy).
    var version: Int = 2

    /// Известные клавиши [Layout], ключ — W3C-имя (§5).
    var entries: [String: LayoutValue] = [:]

    /// Неизвестные ключи [Layout] в исходном порядке.
    var unknownLayoutEntries: [LayoutRawEntry] = []

    /// Настройки собственной платформенной секции ([macOS]) в исходном порядке.
    var platformSettings: [SettingEntry] = []

    /// Настройки типографа (секция [Typograph]). Отсутствие секции = значения по умолчанию.
    var typograph = TypographSettings.default

    /// Чужие секции в исходном порядке.
    var foreignSections: [ForeignSection] = []

    /// Есть ли валидная версия формата v2+ (иначе — кандидат на миграцию).
    var isLegacy: Bool { version < 2 }

    /// Таймаут режима диакритики (сек) из секции [macOS] (§3.3). Дефолт 3 с (FORMAT.md §9).
    var diacriticTimeoutSeconds: TimeInterval {
        if let setting = platformSettings.first(where: { $0.key == "DiacriticTimeoutMs" }),
           let ms = Double(setting.value), ms > 0 {
            return ms / 1000.0
        }
        return 3.0
    }
}

// MARK: - Мост к рантайму (macKeyCode ⇄ W3C)

extension Layout {
    /// Дефолтная раскладка: W3C-ключи из KeyDefinitions + платформенный таймаут диакритики.
    static var standard: Layout {
        var layout = Layout(version: 2)
        for def in KeyDefinitions.all {
            let value = LayoutValue(alt: Array(def.defaultNormal.unicodeScalars),
                                    altShift: Array(def.defaultShift.unicodeScalars))
            if !value.isEmpty { layout.entries[def.w3cName] = value }
        }
        layout.platformSettings = [SettingEntry(key: "DiacriticTimeoutMs", value: "3000")]
        return layout
    }

    /// Проекция в рантайм-словарь, которым оперируют EventTapManager и редактор.
    /// macKeyCode — внутренняя колонка трансляции (PLAN §1, Этап 2 шаг 5).
    func toMacMappings() -> [Int: (normal: String, shift: String)] {
        var result: [Int: (normal: String, shift: String)] = [:]
        for def in KeyDefinitions.all {
            guard let value = entries[def.w3cName] else { continue }
            result[def.macKeyCode] = (String(String.UnicodeScalarView(value.alt)),
                                      String(String.UnicodeScalarView(value.altShift)))
        }
        return result
    }

    /// Обновляет known-ключи из рантайм-словаря, сохраняя версию, чужие секции,
    /// неизвестные ключи и платформенные настройки (round-trip §7).
    mutating func applyMacMappings(_ mappings: [Int: (normal: String, shift: String)]) {
        for def in KeyDefinitions.all {
            guard let m = mappings[def.macKeyCode] else { continue }
            let value = LayoutValue(alt: Array(m.normal.unicodeScalars),
                                    altShift: Array(m.shift.unicodeScalars))
            if value.isEmpty {
                entries[def.w3cName] = nil    // §4.5: пустая клавиша = отсутствие
            } else {
                entries[def.w3cName] = value
            }
        }
    }
}
