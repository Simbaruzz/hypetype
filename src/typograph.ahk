#Requires AutoHotkey v2.0

; =============================================================================
;  typograph.ahk — офлайн-типограф русского текста (TYPOGRAPH.md).
;  Ядро — чистая функция Typograph.Run(text, settings) -> text. Без GUI/буфера.
;  Правила — данные/процедуры; порядок конвейера фиксирован (§6).
;  ЗАКОН: идемпотентность — Run(Run(x)) == Run(x) (§3).
; =============================================================================

class Typograph {
    ; имена с префиксом U_, чтобы не столкнуться с методом-группой Nbsp() (члены класса
    ; в AHK v2 регистронезависимы: NBSP == Nbsp)
    static U_NBSP  := Chr(0x00A0)   ; неразрывный пробел
    static U_NNBSP := Chr(0x202F)   ; узкий неразрывный (для PercentSpace=narrow)

    ; закрытый список для диапазонов месяцев/дней (G2): оба слова из списка
    static RANGE_WORDS := "январь|февраль|март|апрель|май|июнь|июль|август|сентябрь|октябрь|ноябрь|декабрь|понедельник|вторник|среда|четверг|пятница|суббота|воскресенье"

    ; короткие слова для НБ после них (G5): предлоги/союзы/частицы (длинные раньше)
    static SHORT_WORDS := "чтобы|что|без|для|над|под|при|про|во|до|же|за|из|ко|на|не|ни|но|об|от|по|со|то|а|в|и|к|о|с|у"

    ; валютные токены (G6): символ -> regex-альтернатива (без захватывающих групп)
    static CUR := Map(
        "₽", "₽|(?<![А-Яа-яЁё])руб\.?(?![А-Яа-яЁё])|(?<![А-Яа-яЁё])р\.|(?<![A-Za-z])(?:RUR|RUB)(?![A-Za-z])",
        "$", "\$|(?<![A-Za-z])USD(?![A-Za-z])",
        "€", "€|(?<![A-Za-z])EUR(?![A-Za-z])"
    )

    ; G8 (ёфикатор): ТОЛЬКО безусловные ё-словоформы (без омографов все/всё и т.п.).
    ; YO_RAW (компактный словарь основа(суф|...)) задаётся из yodict.ahk; YO строится
    ; лениво в EnsureYo. Источник словаря — eyo-kernel (MIT), частотный сабсет.
    static YO_RAW := ""
    static YO := Map()           ; е-форма (lower) -> ё-форма (lower)
    static _yoBuilt := false

    ; Настройки по умолчанию (§7): все группы включены.
    static DefaultSettings() {
        return Map(
            "Quotes", true, "Dashes", true, "Punct", true, "SpaceClean", true,
            "Nbsp", true, "Numbers", true, "Symbols", true,
            "Yo", false,                   ; ёфикатор — по умолчанию ВЫКЛ (осознанный опт-ин)
            "PercentSpace", "none",        ; none | narrow
            "CurrencyPosition", "after"    ; after | before
        )
    }

    ; -------------------------------------------------------------------------
    ;  Конвейер (§6). Порядок критичен.
    ; -------------------------------------------------------------------------
    static Run(text, settings := "") {
        if !IsObject(settings)
            settings := this.DefaultSettings()
        text := RegExReplace(text, "\r\n?", "`n")        ; нормализуем переводы строк -> \n

        if settings["SpaceClean"]
            text := this.TrimLines(text)                 ; G4: обрезка краёв строк
        if settings["Yo"]
            text := this.Yoficate(text)                  ; G8: ёфикатор (по словарю)
        if settings["Quotes"]
            text := this.Quotes(text)                    ; G1: автомат кавычек (стаб)
        if settings["Punct"]
            text := this.Punct(text)                     ; G3: многоточие/пунктуация
        if settings["Dashes"]
            text := this.Dashes(text)                    ; G2: тире (стаб)
        if settings["SpaceClean"]
            text := this.SpaceClean(text, settings)      ; G4: чистка пробелов (вкл. запятые)
        if settings["Numbers"]
            text := this.Numbers(text, settings)         ; G6: числа/валюта (стаб)
        if settings["Symbols"]
            text := this.Symbols(text)                   ; G7: символы
        if settings["Nbsp"]
            text := this.Nbsp(text)                      ; G5: неразрывные (стаб)
        if settings["SpaceClean"]
            text := this.CollapseSpaces(text)            ; G4: финальная чистка двойных пробелов
        return text
    }

    ; =========================================================================
    ;  G3. Punct — многоточие и пунктуация (§5)
    ; =========================================================================
    static Punct(text) {
        led := Chr(0x2025)                               ; ‥ двухточие (SBOL-стиль)
        ; смешанные троеточие+знак -> «знак‥» (ДО схлопывания троеточия)
        text := RegExReplace(text, "\.{3,}([?!])", "$1" led)     ; ...? -> ?‥ ; ...! -> !‥
        text := RegExReplace(text, "([?!])\.{3,}", "$1" led)     ; ?... -> ?‥ ; !... -> !‥
        text := RegExReplace(text, "\.{3,}", Chr(0x2026))        ; ... -> …
        text := RegExReplace(text, "([?!,;:])\1+", "$1")         ; ??? -> ? ; !!! -> !
        text := RegExReplace(text, "!\?", "?!")                  ; !? -> ?!
        return text
    }

    ; =========================================================================
    ;  G4. SpaceClean — чистка пробелов (§5). Три формы в конвейере (§6).
    ; =========================================================================
    static TrimLines(text) {
        return RegExReplace(text, "m)^[ \t]+|[ \t]+$", "")       ; края каждой строки
    }
    static CollapseSpaces(text) {
        return RegExReplace(text, "\x20{2,}", " ")               ; двойные+ обычные пробелы -> один
    }
    static SpaceClean(text, settings) {
        text := RegExReplace(text, "([«„(\[])\x20+", "$1")                  ; убрать пробел после открывающих
        text := RegExReplace(text, "\x20+([.…:,;?!»“)\]])", "$1")          ; и перед закрывающими/пунктуацией
        text := RegExReplace(text, "([,;:])([A-Za-zА-Яа-яЁё])", "$1 $2")   ; пробел после ,;: перед буквой
        ; процент: дефолт слитно; narrow -> узкий неразрывный
        if (settings["PercentSpace"] = "narrow")
            text := RegExReplace(text, "(\d)[\x20\xA0\x{202F}]*%", "$1" this.U_NNBSP "%")
        else
            text := RegExReplace(text, "(\d)[\x20\xA0\x{202F}]*%", "$1%")
        return text
    }

    ; =========================================================================
    ;  G7. Symbols — символы (§5)
    ; =========================================================================
    static Symbols(text) {
        text := RegExReplace(text, "i)\([cс]\)", Chr(0x00A9))    ; (c)(C)(с)(С) -> ©
        text := RegExReplace(text, "i)\([rр]\)", Chr(0x00AE))    ; (r)(R)(р)(Р) -> ®
        text := RegExReplace(text, "i)\(tm\)", Chr(0x2122))      ; (tm)(TM) -> ™
        text := RegExReplace(text, "\+\-", Chr(0x00B1))          ; +- -> ±
        text := RegExReplace(text, "№\x20*(\d)", "№" this.U_NBSP "$1")  ; № 5 -> №НБ5
        return text
    }

    ; =========================================================================
    ;  G1. Quotes — автомат кавычек (§4). Однопроходный КА по строке.
    ;  Состояние depth: 0 вне кавычек, 1 внутри «…», 2 внутри „…“; глубже — " как есть.
    ; =========================================================================
    static Quotes(text) {
        DQ := Chr(0x22), SQ := Chr(0x27)
        ; «лапки» macOS/англ. (“ ”) -> прямые: дальше автомат расставит ёлочки по контексту
        text := StrReplace(text, "“", DQ)
        text := StrReplace(text, "”", DQ)
        chars := StrSplit(text)
        n := chars.Length
        out := ""
        depth := 0
        i := 1
        while (i <= n) {
            ch := chars[i]
            prev := (i > 1) ? chars[i - 1] : ""
            next := (i < n) ? chars[i + 1] : ""
            switch ch {
                case "«":
                    depth := 1
                    out .= ch
                case "„":
                    depth := 2
                    out .= ch
                case "»":
                    depth := 0
                    out .= ch
                case "“":
                    depth := 1
                    out .= ch
                case DQ:
                    out .= this.ClassifyDQuote(prev, next, &depth)
                case SQ:
                    ; апостроф внутри латинского слова -> ’; штрихи/прочее не трогаем
                    out .= (this.IsLatin(prev) && this.IsLatin(next)) ? Chr(0x2019) : ch
                default:
                    out .= ch
            }
            i++
        }
        ; после автомата: точка/запятая за закрывающую кавычку (§4)
        out := RegExReplace(out, "([.,])([»“])", "$2$1")
        return out
    }

    static ClassifyDQuote(prev, next, &depth) {
        if (this.IsDigit(prev))                         ; дюйм-эвристика (приоритет): 21" 27"
            return Chr(0x22)
        beforeOpen := (prev = "" || this.IsSpace(prev) || prev = "(" || prev = "[" || this.IsDash(prev))
        afterClose := (next = "" || this.IsSpace(next) || this.IsCloseAfter(next))
        afterNonSpace := (next != "" && !this.IsSpace(next))
        beforeNonSpace := (prev != "" && !this.IsSpace(prev))

        if (beforeOpen && afterNonSpace)
            opening := true
        else if (beforeNonSpace && afterClose)
            opening := false
        else
            opening := (depth = 0)                      ; неоднозначно -> по состоянию

        if (opening) {
            if (depth = 0) {
                depth := 1
                return "«"
            } else if (depth = 1) {
                depth := 2
                return "„"
            }
            return Chr(0x22)                             ; глубже 2 — не трогаем
        } else {
            if (depth = 2) {
                depth := 1
                return "“"
            } else if (depth = 1) {
                depth := 0
                return "»"
            }
            return Chr(0x22)                             ; нечего закрывать
        }
    }

    static IsDigit(c) {
        return (c != "" && Ord(c) >= 0x30 && Ord(c) <= 0x39)
    }
    static IsLatin(c) {
        if (c = "")
            return false
        o := Ord(c)
        return (o >= 0x41 && o <= 0x5A) || (o >= 0x61 && o <= 0x7A)
    }
    static IsSpace(c) {
        return (c = " " || c = "`t" || c = "`n" || c = "`r")
    }
    static IsDash(c) {
        return (c = "-" || c = Chr(0x2013) || c = Chr(0x2014))
    }
    static IsCloseAfter(c) {
        return (c != "" && InStr(".…:,;?!)]»“", c) > 0)
    }

    ; =========================================================================
    ;  Заглушки групп — реализуются по очереди (§10). Пока тождество.
    ; =========================================================================
    ; =========================================================================
    ;  G5. Nbsp — неразрывные пробелы (§5). Работает по уже расставленным пробелам.
    ; =========================================================================
    static Nbsp(text) {
        nb := this.U_NBSP
        ; инициалы: А.А. Фамилия и Фамилия К.П.
        text := RegExReplace(text, "([А-ЯЁ]\.[А-ЯЁ]\.)\x20([А-ЯЁ][а-яё])", "$1" nb "$2")
        text := RegExReplace(text, "([А-ЯЁ][а-яё]+)\x20([А-ЯЁ]\.[А-ЯЁ]\.)", "$1" nb "$2")
        text := RegExReplace(text, "(?<![А-Яа-яЁё])([А-ЯЁ]\.)\x20([А-ЯЁ][а-яё]+)", "$1" nb "$2")
        ; и т.д. / и т.п. / и др. (НБ перед и внутри)
        text := RegExReplace(text, "\x20и\x20т\.\x20?д\.", nb "и" nb "т." nb "д.")
        text := RegExReplace(text, "\x20и\x20т\.\x20?п\.", nb "и" nb "т." nb "п.")
        text := RegExReplace(text, "\x20и\x20др\.", nb "и" nb "др.")
        ; сокращения с точкой: г. ул. д. кв. рис. гл. ст. п.
        text := RegExReplace(text, "i)(?<![А-Яа-яЁё])(г|ул|д|кв|рис|гл|ст|п)\.\x20", "$1." nb)
        ; орг-формы
        text := RegExReplace(text, "(?<![А-ЯA-Z])(АО|ООО|ОАО|ЗАО|ПАО)\x20", "$1" nb)
        ; № и § перед числом
        text := RegExReplace(text, "([№§])\x20*(\d)", "$1" nb "$2")
        ; короткие слова -> НБ после
        text := RegExReplace(text, "i)(?<![А-Яа-яЁёA-Za-z])(" this.SHORT_WORDS ")\x20", "$1" nb)
        ; частицы -> НБ перед (длинные раньше)
        text := RegExReplace(text, "\x20(бы|же|ли|ль|б|ж)(?![А-Яа-яЁё])", nb "$1")
        ; число + слово
        text := RegExReplace(text, "(\d)\x20(?=[А-Яа-яЁёA-Za-z])", "$1" nb)
        ; последнее короткое слово (1-3) в конце предложения/строки
        text := RegExReplace(text, "m)\x20([А-Яа-яЁёA-Za-z]{1,3})(?=[.!?…]|\x20*$)", nb "$1")
        return text
    }

    ; =========================================================================
    ;  G8. Yo — ёфикатор по словарю безусловных слов (опционально).
    ; =========================================================================
    static Yoficate(text) {
        this.EnsureYo()
        out := ""
        pos := 1
        while (p := RegExMatch(text, "[А-Яа-яЁё]+", &m, pos)) {
            out .= SubStr(text, pos, p - pos) this.YoWord(m[0])
            pos := p + StrLen(m[0])
        }
        return out SubStr(text, pos)
    }
    static YoWord(word) {
        key := StrReplace(StrLower(word), "ё", "е")     ; нормализуем к е-форме (идемпотентность)
        if !this.YO.Has(key)
            return word
        return this.ApplyCase(word, this.YO[key])
    }
    ; ленивое построение YO из YO_RAW (формат: основа(суф1|суф2|...) или одиночная форма)
    static EnsureYo() {
        if this._yoBuilt
            return
        this._yoBuilt := true
        for line in StrSplit(this.YO_RAW, "`n", "`r") {
            if (line = "")
                continue
            if RegExMatch(line, "^(.*)\((.*)\)$", &m) {
                stem := m[1]
                for suf in StrSplit(m[2], "|")
                    this.YO[StrReplace(stem suf, "ё", "е")] := stem suf
            } else {
                this.YO[StrReplace(line, "ё", "е")] := line
            }
        }
    }
    ; перенести регистр orig на repl (длины равны: отличие только е<->ё)
    static ApplyCase(orig, repl) {
        out := ""
        Loop StrLen(repl) {
            oc := SubStr(orig, A_Index, 1)
            rc := SubStr(repl, A_Index, 1)
            out .= (oc !== StrLower(oc)) ? StrUpper(rc) : rc
        }
        return out
    }

    ; =========================================================================
    ;  G6. Numbers — числа и валюта (§5). Группировка разрядов — процедурой.
    ; =========================================================================
    static Numbers(text, settings) {
        nb := this.U_NBSP
        before := (settings["CurrencyPosition"] = "before")
        text := this.MergeKopecks(text)
        text := this.NormalizeCurrency(text, before)
        ; величины: тыс. с точкой; млн/млрд/трлн без точки; НБ перед словом
        text := RegExReplace(text, "i)(\d)[\x20\xA0]*тыс\.?(?![А-Яа-яЁё])", "$1" nb "тыс.")
        text := RegExReplace(text, "i)(\d)[\x20\xA0]*(млн|млрд|трлн)\.?(?![А-Яа-яЁё])", "$1" nb "$2")
        return text
    }

    ; 45 руб. 5 коп. -> 45,05 ₽
    static MergeKopecks(text) {
        nb := this.U_NBSP
        pos := 1
        while RegExMatch(text, "i)(\d+)[\x20\xA0]*руб\.?[\x20\xA0]*(\d+)[\x20\xA0]*коп\.?", &m, pos) {
            rep := m[1] "," Format("{:02}", Integer(m[2])) nb "₽"
            text := SubStr(text, 1, m.Pos - 1) rep SubStr(text, m.Pos + m.Len)
            pos := m.Pos + StrLen(rep)
        }
        return text
    }

    ; Нормализация "<число><валюта>" и "<валюта><число>" в любом порядке.
    static NormalizeCurrency(text, before) {
        nb := this.U_NBSP
        numPat := "(\d[\d.,\xA0]*\d|\d)"
        for symbol, pat in this.CUR {
            ; число затем валюта
            pos := 1
            while RegExMatch(text, "i)" numPat "[\x20\xA0]*(?:" pat ")", &m, pos) {
                money := this.FormatMoney(m[1])
                rep := before ? (symbol nb money) : (money nb symbol)
                text := SubStr(text, 1, m.Pos - 1) rep SubStr(text, m.Pos + m.Len)
                pos := m.Pos + StrLen(rep)
            }
            ; валюта затем число
            pos := 1
            while RegExMatch(text, "i)(?:" pat ")[\x20\xA0]*" numPat, &m, pos) {
                money := this.FormatMoney(m[1])
                rep := before ? (symbol nb money) : (money nb symbol)
                text := SubStr(text, 1, m.Pos - 1) rep SubStr(text, m.Pos + m.Len)
                pos := m.Pos + StrLen(rep)
            }
        }
        return text
    }

    ; Форматирование суммы: убрать разряды, точка->запятая, сгруппировать (>=5 цифр).
    static FormatMoney(numRaw) {
        s := RegExReplace(numRaw, "[\x20\xA0]", "")        ; снять разделители разрядов
        frac := ""
        if RegExMatch(s, "^(\d+)[.,](\d+)$", &mm) {
            intPart := mm[1]
            frac := mm[2]
        } else {
            intPart := RegExReplace(s, "[^\d]", "")
        }
        if (StrLen(intPart) >= 5)
            intPart := this.GroupDigits(intPart)
        return (frac != "") ? (intPart "," frac) : intPart
    }

    ; Вставить НБ как разделитель тысяч (по 3 разряда справа).
    static GroupDigits(digits) {
        nb := this.U_NBSP
        out := ""
        cnt := 0
        i := StrLen(digits)
        while (i >= 1) {
            out := SubStr(digits, i, 1) out
            cnt++
            if (Mod(cnt, 3) = 0 && i > 1)
                out := nb out
            i--
        }
        return out
    }

    ; =========================================================================
    ;  G2. Dashes — тире (§5)
    ; =========================================================================
    static Dashes(text) {
        em := "—"               ; U+2014 длинное тире
        en := Chr(0x2013)       ; – среднее тире
        nb := this.U_NBSP

        ; начало строки/прямой речи: — + НБ ПОСЛЕ тире (поправка по SBOL)
        text := RegExReplace(text, "m)^[-–—]\x20+", em nb)
        ; начало предложения после точки: . — + НБ
        text := RegExReplace(text, "(\.)\x20+[-–—]\x20+", "$1 " em nb)
        ; внутри текста (одиночный/двойной дефис, среднее тире в пробелах): НБ + — + пробел
        text := RegExReplace(text, "\x20+(?:--|[-–—])\x20+", nb em " ")

        ; диапазоны чисел -> среднее тире, без пробелов (не трогая даты/цепочки)
        text := RegExReplace(text, "(?<![\d-])(\d+)-(\d+)(?![\d-])", "$1" en "$2")
        ; диапазоны месяцев/дней (оба слова из закрытого списка)
        rw := this.RANGE_WORDS
        text := RegExReplace(text, "i)(?<![А-Яа-яЁё-])(" rw ")-(" rw ")(?![А-Яа-яЁё-])", "$1" en "$2")
        ; римские диапазоны
        text := RegExReplace(text, "(?<![A-Za-zА-Яа-яЁё-])([IVXLCDM]+)-([IVXLCDM]+)(?![A-Za-zА-Яа-яЁё-])", "$1" en "$2")
        return text
    }
}
