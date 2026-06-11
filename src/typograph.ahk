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

    ; Настройки по умолчанию (§7): все группы включены.
    static DefaultSettings() {
        return Map(
            "Quotes", true, "Dashes", true, "Punct", true, "SpaceClean", true,
            "Nbsp", true, "Numbers", true, "Symbols", true,
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
    ;  Заглушки групп — реализуются по очереди (§10). Пока тождество.
    ; =========================================================================
    static Quotes(text) => text          ; G1 (§4) — далее
    static Dashes(text) => text          ; G2 — далее
    static Numbers(text, settings) => text ; G6 — далее
    static Nbsp(text) => text            ; G5 — далее
}
