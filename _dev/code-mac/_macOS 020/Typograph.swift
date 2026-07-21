//
//  Typograph.swift
//  hypetype
//
//  Чистый типограф русского текста (порт src/typograph.ahk, см. TYPOGRAPH.md).
//  Ядро — функция Typograph.run(text, settings) -> text. Без GUI, буфера, хоткеев.
//  Правила идемпотентны: run(run(x)) == run(x) (TYPOGRAPH.md §3).
//
//  Конвейер (порядок критичен, §6):
//    G4-обрезка краёв → G1 кавычки → G3 пунктуация → G2 тире →
//    G4 чистка пробелов → G6 числа/валюта → G7 символы →
//    G5 неразрывные (последними) → финальная G4-чистка.
//

import Foundation

/// Неразрывный пробел U+00A0.
let NBSP = "\u{00A0}"
/// Узкий неразрывный пробел U+202F (для PercentSpace=narrow).
let NNBSP = "\u{202F}"

nonisolated struct TypographSettings: Equatable {
    enum PercentSpace: String { case none, narrow, regular }
    enum CurrencyPosition: String { case after, before }

    // G1 — кавычки
    var quotes = true

    // G2 — тире (расщеплено на под-правила)
    var dashText = true       // дефис внутри текста → тире:  " - " → " — "
    var dashSpeech = true     // прямая речь в начале строки/предложения: "- Это я" → "— Это я"
    var dashRanges = true     // диапазоны: 2002-2009 → 2002–2009 (числа/римские/месяцы)

    // G3 — пунктуация (расщеплено)
    var punctEllipsis = true  // ... → …  (и смешанные ...? → ?‥)
    var punctCollapse = true  // !!! → !, ??? → ?, ,,, → ,
    var punctOrder = true     // !? → ?!

    // G4 — пробелы
    var spaceClean = true                       // чистка пробелов вокруг пунктуации
    var percentSpace: PercentSpace = .none      // % : none 23% | narrow 23 % | regular 23 %

    // G5 — неразрывные (расщеплено)
    var nbspNumberWord = true // число + слово: 5 лет → 5 лет (НБ)
    var nbspInitials = true   // инициалы и фамилия: А.А. Иванов → А.А. Иванов (НБ)
    var nbspParticles = true  // перед частицами б/бы/ж/же/ли/ль
    var nbspShortWords = true // короткие предлоги/союзы (≤3): в лесу → в лесу (НБ)

    // G6 — числа и валюта (расщеплено)
    var currencySymbol = true    // слово валюты → знак (5 руб → 5 ₽), десятичная точка→запятая
    var currencyGrouping = true  // группировка разрядов ≥5 цифр: 2345123 ₽ → 2 345 123 ₽
    var currencyKopecks = true   // 45 руб. 5 коп. → 45,05 ₽
    var currencyPosition: CurrencyPosition = .after

    // G7 — символы
    var symbols = true

    static let `default` = TypographSettings()
}

nonisolated enum Typograph {

    // MARK: - Точка входа

    static func run(_ text: String, _ settings: TypographSettings = .default) -> String {
        var s = text

        s = trimLineEdges(s)                                   // G4 (края)
        if settings.quotes      { s = quotesAutomaton(s) }     // G1
        s = punctuation(s, settings)                           // G3 (гейты внутри)
        s = dashes(s, settings)                                // G2 (гейты внутри)
        if settings.spaceClean  { s = spaceClean(s, settings) }// G4
        s = percentSpacing(s, settings)                        // G4 (%) — независимо от spaceClean
        s = numbers(s, settings)                               // G6 (гейты внутри)
        if settings.symbols     { s = symbols(s) }             // G7
        s = nonBreaking(s, settings)                           // G5 (гейты внутри)
        s = collapseSpaces(s)                                  // финальная G4

        return s
    }

    // MARK: - G3. Пунктуация (многоточие, схлопывание повторов)

    static func punctuation(_ text: String, _ settings: TypographSettings = .default) -> String {
        var s = text
        if settings.punctEllipsis {
            // Смешанные с многоточием → SBOL-стиль с ‥ (U+2025). До схлопывания точек.
            s = replace(s, #"\.{3,}([?!])"#, "$1\u{2025}")   // ...?  → ?‥
            s = replace(s, #"([?!])\.{3,}"#, "$1\u{2025}")   // ?...  → ?‥
            // Три и более точек → многоточие.
            s = replace(s, #"\.{3,}"#, "\u{2026}")
        }
        if settings.punctCollapse {
            // Схлопывание повторов одного и того же знака до одного.
            s = replace(s, #"!{2,}"#, "!")
            s = replace(s, #"\?{2,}"#, "?")
            s = replace(s, #"([,;:])\1+"#, "$1")
        }
        if settings.punctOrder {
            // Нормализация порядка.
            s = replace(s, #"!\?"#, "?!")
        }
        return s
    }

    // MARK: - G4. Чистка пробелов

    /// Обрезка пробелов/табов в начале и конце каждой строки (переносы сохраняются).
    static func trimLineEdges(_ text: String) -> String {
        var s = text
        s = replace(s, #"(?m)^[ \t]+"#, "")
        s = replace(s, #"(?m)[ \t]+$"#, "")
        return s
    }

    static func spaceClean(_ text: String, _ settings: TypographSettings) -> String {
        var s = text
        // Убрать пробел после открывающих.
        s = replace(s, #"([«„(\[]) +"#, "$1")
        // Убрать пробел перед закрывающими/знаками препинания.
        s = replace(s, #" +([.…:,;?!»“)\]])"#, "$1")
        // Добавить пробел после , ; : перед буквой (не цифрой — десятичные/время не трогаем).
        s = replace(s, #"([,;:])(\p{L})"#, "$1 $2")
        // Двойные+ обычные пробелы → один.
        s = collapseSpaces(s)
        return s
    }

    /// G4. Пробел у знака процента — независимый стиль (не зависит от чистки пробелов).
    /// Матчит любой микс пробелов/НБ/узких перед %, приводит к выбранному варианту (идемпотентно).
    static func percentSpacing(_ text: String, _ settings: TypographSettings = .default) -> String {
        switch settings.percentSpace {
        case .none:    return replace(text, #"(\d)[ \x{00A0}\x{202F}]*%"#, "$1%")
        case .narrow:  return replace(text, #"(\d)[ \x{00A0}\x{202F}]*%"#, "$1\u{202F}%")
        case .regular: return replace(text, #"(\d)[ \x{00A0}\x{202F}]*%"#, "$1 %")
        }
    }

    /// Схлопывание подряд идущих ОБЫЧНЫХ пробелов (НБ-конструкции не трогаем).
    static func collapseSpaces(_ text: String) -> String {
        replace(text, #" {2,}"#, " ")
    }

    // MARK: - G7. Символы

    static func symbols(_ text: String) -> String {
        var s = text
        s = replace(s, #"\([cCсС]\)"#, "\u{00A9}")          // (c) → ©
        s = replace(s, #"\([rR]\)"#, "\u{00AE}")            // (r) → ®
        s = replace(s, #"\((?i:tm)\)"#, "\u{2122}")         // (tm) → ™
        s = replace(s, #"\+-"#, "\u{00B1}")                 // +- → ±
        s = replace(s, #"№ *(\d)"#, "№\u{00A0}$1")          // № 5 → №<НБ>5
        return s
    }

    // MARK: - Заглушки (реализуются следующими шагами)

    // MARK: - G1. Автомат кавычек (§4)

    static func quotesAutomaton(_ text: String) -> String {
        // macOS «умные кавычки» подменяют прямые " на английские фигурные “…” ещё до
        // нашего типографа. Нормализуем их в прямые ", чтобы автомат классифицировал
        // по контексту (открывающая/закрывающая), а не считал “ русской внутренней.
        let normalized = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")   // “
            .replacingOccurrences(of: "\u{201D}", with: "\"")   // ”
        let chars = Array(normalized)
        var out: [Character] = []
        out.reserveCapacity(chars.count)
        var depth = 0   // 0 — вне; 1 — внутри «…»; 2 — внутри „…“

        func isSpace(_ c: Character?) -> Bool { c.map { $0.isWhitespace } ?? false }
        func isDash(_ c: Character) -> Bool { c == "—" || c == "–" || c == "-" }
        func isLatinLetter(_ c: Character?) -> Bool {
            guard let c = c, let a = c.unicodeScalars.first, c.unicodeScalars.count == 1 else { return false }
            return (a.value >= 65 && a.value <= 90) || (a.value >= 97 && a.value <= 122)
        }

        for i in chars.indices {
            let c = chars[i]
            let prev: Character? = i > 0 ? chars[i - 1] : nil
            let next: Character? = i < chars.count - 1 ? chars[i + 1] : nil

            switch c {
            // Уже стоящие кавычки двигают состояние, но не заменяются (идемпотентность).
            case "«": depth = 1; out.append(c)
            case "„": depth = 2; out.append(c)
            case "»": depth = 0; out.append(c)

            case "\"":
                // Дюйм-эвристика (приоритетная): " сразу после цифры — знак дюйма.
                if let p = prev, p.isNumber {
                    out.append(c)
                    break
                }
                let canOpen = (prev == nil || isSpace(prev) || prev == "(" || prev == "[" || (prev.map(isDash) ?? false))
                            && (next != nil && !isSpace(next))
                let canClose = (prev != nil && !isSpace(prev))
                            && (next == nil || isSpace(next) || ".,!?;:)]".contains(next!))
                let opening: Bool
                if canOpen && !canClose { opening = true }
                else if canClose && !canOpen { opening = false }
                else { opening = depth == 0 }   // неоднозначно → по состоянию

                if opening {
                    switch depth {
                    case 0: out.append("«"); depth = 1
                    case 1: out.append("„"); depth = 2
                    default: out.append(c)         // глубже 2 — оставляем "
                    }
                } else {
                    switch depth {
                    case 2: out.append("“"); depth = 1
                    case 1: out.append("»"); depth = 0
                    default: out.append(c)         // нечего закрывать — оставляем "
                    }
                }

            case "'":
                // Апостроф внутри латинского слова (it's, d'Artagnan) → ’. Штрихи после цифры — нет.
                if isLatinLetter(prev) && isLatinLetter(next) {
                    out.append("’")
                } else {
                    out.append(c)
                }

            default:
                out.append(c)
            }
        }

        // Точка/запятая, оказавшаяся перед закрывающей «ёлочкой», выносится наружу (стиль SBOL).
        return replace(String(out), #"([.,])(»)"#, "$2$1")
    }
    // MARK: - G2. Тире (§5)

    static func dashes(_ text: String, _ settings: TypographSettings = .default) -> String {
        var s = text

        if settings.dashSpeech {
            // Прямая речь в начале строки: "- Это я" → "— Это я" (НБ после тире).
            s = replace(s, #"(?m)^[-–—]+[ \t]+"#, "—\u{00A0}")
            // Прямая речь после конца предложения: ". - " → ". — " (НБ после тире).
            s = replace(s, #"([.!?…][ \t])[-–—]+[ \t]+"#, "$1—\u{00A0}")
        }
        if settings.dashText {
            // Внутри текста: " - " → "<НБ>— " (НБ перед тире, обычный пробел после).
            s = replace(s, #"(\S)[ ]+[-–—]{1,2}[ ]+"#, "$1\u{00A0}— ")
        }
        if settings.dashRanges {
            // Диапазоны чисел: 2002-2009 → 2002–2009 (среднее тире, без дат 12-05-2024).
            s = replace(s, #"(?<![\d-])(\d+)-(\d+)(?![\d-])"#, "$1\u{2013}$2")
            // Римские диапазоны: XI-XII → XI–XII.
            s = replace(s, #"(?<![\p{L}])([IVXLCM]+)-([IVXLCM]+)(?![\p{L}])"#, "$1\u{2013}$2")
            // Диапазоны месяцев/дней (закрытый список, оба слова из списка).
            let md = "январь|февраль|март|апрель|май|июнь|июль|август|сентябрь|октябрь|ноябрь|декабрь|понедельник|вторник|среда|четверг|пятница|суббота|воскресенье"
            s = replace(s, "(?<![\\p{L}])(\(md))-(\(md))(?![\\p{L}])", "$1\u{2013}$2")
        }

        return s
    }
    // MARK: - G6. Числа и валюта (§5)

    static func numbers(_ text: String, _ settings: TypographSettings = .default) -> String {
        var s = text

        if settings.currencyKopecks {
            // Копейки в сумму: "45 руб. 5 коп." → "45,05 ₽".
            s = replaceMatches(s, #"(\d+)[ \x{00A0}]*руб\.?[ \x{00A0}]+(\d+)[ \x{00A0}]*коп\.?"#) { g in
                let kop = g[2].count == 1 ? "0\(g[2])" : String(g[2].suffix(2))
                return placeCurrency(number: "\(g[1]),\(kop)", symbol: "₽", settings)
            }
        }

        if settings.currencySymbol {
            let cur = #"(?:₽|\$|€|руб\.?|р\.|RUR|RUB|USD|usd|EUR|eur)"#
            let noLetter = #"(?![А-Яа-яA-Za-z])"#
            let num = #"(\d[\d\x{00A0} .,]*\d|\d)"#   // число с возможной НБ-группировкой

            // Валюта ПЕРЕД числом: "$ 109", "руб 50".
            s = replaceMatches(s, "(\(cur))\(noLetter)[ \u{00A0}]*\(num)") { g in
                placeCurrency(number: g[2], symbol: symbol(for: g[1]), settings)
            }
            // Валюта ПОСЛЕ числа: "109$", "20usd", "2345123 $".
            s = replaceMatches(s, "\(num)[ \u{00A0}]*(\(cur))\(noLetter)") { g in
                placeCurrency(number: g[1], symbol: symbol(for: g[2]), settings)
            }
        }

        return s
    }

    /// Валютный токен (символ/слово/код) → знак валюты.
    private static func symbol(for token: String) -> String {
        let low = token.lowercased()
        if token == "₽" || low.hasPrefix("руб") || low == "р." || low == "rur" || low == "rub" { return "₽" }
        if token == "$" || low == "usd" { return "$" }
        if token == "€" || low == "eur" { return "€" }
        return token
    }

    /// Нормализует число (десятичная точка→запятая, группировка ≥5 цифр) и ставит знак валюты.
    private static func placeCurrency(number raw: String, symbol: String, _ settings: TypographSettings) -> String {
        var n = raw.replacingOccurrences(of: "\u{00A0}", with: "").replacingOccurrences(of: " ", with: "")
        n = n.replacingOccurrences(of: ".", with: ",")   // десятичная точка→запятая (валютный контекст)
        let parts = n.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        var intPart = parts[0]
        if settings.currencyGrouping && intPart.count >= 5 { intPart = groupDigits(intPart) }
        let normalized = parts.count > 1 ? "\(intPart),\(parts[1])" : intPart

        switch settings.currencyPosition {
        case .after:  return "\(normalized)\u{00A0}\(symbol)"
        case .before: return "\(symbol)\u{00A0}\(normalized)"
        }
    }

    /// Группировка разрядов по 3 справа, разделитель — НБ.
    private static func groupDigits(_ s: String) -> String {
        let chars = Array(s)
        var out = ""
        for (i, ch) in chars.enumerated() {
            if i > 0 && (chars.count - i) % 3 == 0 { out += "\u{00A0}" }
            out.append(ch)
        }
        return out
    }
    // MARK: - G5. Неразрывные пробелы (§5). Применяются последними — по уже расставленным пробелам.

    static func nonBreaking(_ text: String, _ settings: TypographSettings = .default) -> String {
        var s = text

        if settings.nbspNumberWord {
            // Между числом и следующим словом: "5 лет" → "5<НБ>лет".
            s = replace(s, #"(\d)[ ]+(\p{L})"#, "$1\u{00A0}$2")
        }

        if settings.nbspInitials {
            // Инициалы + фамилия (оба порядка): "А.А. Иванов", "Иванов А.А."
            s = replace(s, #"([А-ЯЁ]\.[ ]?[А-ЯЁ]\.)[ ]+([А-ЯЁ][а-яё]+)"#, "$1\u{00A0}$2")
            s = replace(s, #"([А-ЯЁ][а-яё]+)[ ]+([А-ЯЁ]\.[ ]?[А-ЯЁ]\.)"#, "$1\u{00A0}$2")
        }

        if settings.nbspParticles {
            // Частицы б, бы, ж, же, ли, ль — НБ перед ними.
            s = replace(s, #"(\S)[ ]+(бы?|же?|ли|ль)(?![\p{L}])"#, "$1\u{00A0}$2")
        }

        if settings.nbspShortWords {
            // Короткие предлоги/союзы/частицы (≤3 букв) — НБ после, приклеиваем к следующему слову.
            let shorts = "а|без|бы|в|во|вы|да|для|до|же|за|и|из|к|ко|ли|на|над|не|ни|но|о|об|от|по|под|при|про|с|со|та|то|ту|у|уж"
            s = replace(s, "(?i)(?<![\\p{L}])(\(shorts))[ ]+(?=[\\p{L}\\d«„(])", "$1\u{00A0}")
        }

        return s
    }

    // MARK: - Regex-хелпер

    /// Кэш скомпилированных регулярок. Набор паттернов конечный (~30 штук) — кэш
    /// дорастает до маленького фиксированного размера и не растёт дальше.
    /// Раньше каждый вызов replace/replaceMatches компилировал ICU-паттерн заново:
    /// один прогон типографа = ~25 компиляций, отсюда скачок памяти на каждый вызов.
    private static let regexCache = NSCache<NSString, NSRegularExpression>()
    private static let regexCacheLock = NSLock()

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        regexCacheLock.lock()
        defer { regexCacheLock.unlock() }
        if let cached = regexCache.object(forKey: pattern as NSString) { return cached }
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        regexCache.setObject(re, forKey: pattern as NSString)
        return re
    }

    static func replace(_ text: String, _ pattern: String, _ template: String) -> String {
        guard let re = regex(pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return re.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    /// Замена с замыканием: даёт строки всех capture-групп (g[0] — весь матч).
    /// Нужна там, где замена не выразима шаблоном (группировка разрядов, копейки).
    static func replaceMatches(_ text: String, _ pattern: String, _ transform: ([String]) -> String) -> String {
        guard let re = regex(pattern) else { return text }
        let ns = text as NSString
        var result = ""
        var last = 0
        re.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m = m else { return }
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            var groups: [String] = []
            for gi in 0..<m.numberOfRanges {
                let r = m.range(at: gi)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            result += transform(groups)
            last = m.range.location + m.range.length
        }
        result += ns.substring(with: NSRange(location: last, length: ns.length - last))
        return result
    }
}
