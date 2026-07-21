//
//  TypographFormat.swift
//  hypetype
//
//  Чистый кодек секции [Typograph] в config.ini: TypographSettings ⇄ строки key=value.
//  Никакого I/O и UI — полностью тестируемо (по образцу LayoutFormat).
//  Значения-булевы пишутся как 1/0; перечисления — своими rawValue (none/narrow/regular,
//  after/before). Отсутствующий ключ = значение по умолчанию (TypographSettings.default).
//

import Foundation

nonisolated enum TypographFormat {

    /// Имя секции в config.ini.
    static let sectionName = "Typograph"

    // MARK: - Сериализация (TypographSettings → строки)

    /// Детерминированный порядок ключей (важно для идемпотентного round-trip).
    static func serialize(_ s: TypographSettings) -> [String] {
        var lines: [String] = []
        func b(_ key: String, _ v: Bool) { lines.append("\(key)=\(v ? "1" : "0")") }

        b("Quotes", s.quotes)
        b("DashText", s.dashText)
        b("DashSpeech", s.dashSpeech)
        b("DashRanges", s.dashRanges)
        b("PunctEllipsis", s.punctEllipsis)
        b("PunctCollapse", s.punctCollapse)
        b("PunctOrder", s.punctOrder)
        b("SpaceClean", s.spaceClean)
        lines.append("PercentSpace=\(s.percentSpace.rawValue)")
        b("NbspNumberWord", s.nbspNumberWord)
        b("NbspInitials", s.nbspInitials)
        b("NbspParticles", s.nbspParticles)
        b("NbspShortWords", s.nbspShortWords)
        b("CurrencySymbol", s.currencySymbol)
        b("CurrencyGrouping", s.currencyGrouping)
        b("CurrencyKopecks", s.currencyKopecks)
        lines.append("CurrencyPosition=\(s.currencyPosition.rawValue)")
        b("Symbols", s.symbols)
        return lines
    }

    // MARK: - Парсинг (строки → TypographSettings)

    /// Собирает настройки из списка пар. Неизвестные ключи и невалидные значения
    /// игнорируются (остаётся значение по умолчанию).
    static func parse(_ pairs: [(key: String, value: String)]) -> TypographSettings {
        var s = TypographSettings.default
        for (key, value) in pairs { apply(to: &s, key: key, value: value) }
        return s
    }

    /// Применяет одну пару key=value к настройкам (используется и при потоковом разборе файла).
    static func apply(to s: inout TypographSettings, key: String, value: String) {
        let v = value.trimmingCharacters(in: .whitespaces)

        func bool() -> Bool? {
            switch v.lowercased() {
            case "1", "true", "yes", "on":  return true
            case "0", "false", "no", "off": return false
            default:                        return nil
            }
        }

        switch key {
        case "Quotes":          if let b = bool() { s.quotes = b }
        case "DashText":        if let b = bool() { s.dashText = b }
        case "DashSpeech":      if let b = bool() { s.dashSpeech = b }
        case "DashRanges":      if let b = bool() { s.dashRanges = b }
        case "PunctEllipsis":   if let b = bool() { s.punctEllipsis = b }
        case "PunctCollapse":   if let b = bool() { s.punctCollapse = b }
        case "PunctOrder":      if let b = bool() { s.punctOrder = b }
        case "SpaceClean":      if let b = bool() { s.spaceClean = b }
        case "PercentSpace":
            if let e = TypographSettings.PercentSpace(rawValue: v.lowercased()) { s.percentSpace = e }
        case "NbspNumberWord":  if let b = bool() { s.nbspNumberWord = b }
        case "NbspInitials":    if let b = bool() { s.nbspInitials = b }
        case "NbspParticles":   if let b = bool() { s.nbspParticles = b }
        case "NbspShortWords":  if let b = bool() { s.nbspShortWords = b }
        case "CurrencySymbol":  if let b = bool() { s.currencySymbol = b }
        case "CurrencyGrouping":if let b = bool() { s.currencyGrouping = b }
        case "CurrencyKopecks": if let b = bool() { s.currencyKopecks = b }
        case "CurrencyPosition":
            if let e = TypographSettings.CurrencyPosition(rawValue: v.lowercased()) { s.currencyPosition = e }
        case "Symbols":         if let b = bool() { s.symbols = b }
        default:                break   // неизвестный ключ — пропускаем
        }
    }
}
