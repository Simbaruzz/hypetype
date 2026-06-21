#Requires AutoHotkey v2.0

; =============================================================================
;  config.ahk — единственный код, читающий/пишущий config.ini.
;  Реализует FORMAT.md (кросс-платформенный формат раскладки v2).
;  Не знает про GUI и хоткеи. Сообщения наверх — через флаги, не MsgBox.
; =============================================================================

class Config {
    ; --- публичное состояние ---
    static Path := ""            ; фактический путь к config.ini
    static IsPortable := false   ; true = рядом с exe, false = AppData
    static PendingNotice := ""   ; одноразовое сообщение для точки входа ("" = нет)

    ; --- внутреннее ---
    static _data := ""           ; разобранная модель (см. NewData)

    ; --- таблица клавиш (FORMAT.md §5), порядок = порядок таблицы ---
    static W3C_TO_SC := Map(
        "Digit1","SC002", "Digit2","SC003", "Digit3","SC004", "Digit4","SC005",
        "Digit5","SC006", "Digit6","SC007", "Digit7","SC008", "Digit8","SC009",
        "Digit9","SC00A", "Digit0","SC00B", "Minus","SC00C", "Equal","SC00D",
        "KeyQ","SC010", "KeyW","SC011", "KeyE","SC012", "KeyR","SC013",
        "KeyT","SC014", "KeyY","SC015", "KeyU","SC016", "KeyI","SC017",
        "KeyO","SC018", "KeyP","SC019", "BracketLeft","SC01A", "BracketRight","SC01B",
        "KeyA","SC01E", "KeyS","SC01F", "KeyD","SC020", "KeyF","SC021",
        "KeyG","SC022", "KeyH","SC023", "KeyJ","SC024", "KeyK","SC025",
        "KeyL","SC026", "Semicolon","SC027", "Quote","SC028", "Backslash","SC02B",
        "KeyZ","SC02C", "KeyX","SC02D", "KeyC","SC02E", "KeyV","SC02F",
        "KeyB","SC030", "KeyN","SC031", "KeyM","SC032", "Comma","SC033",
        "Period","SC034", "Slash","SC035", "Space","SC039", "Backquote","SC029"
    )

    ; обратная таблица — строится в __New (Map в v2 не хранит порядок вставки)
    static SC_TO_W3C := ""

    ; порядок имён для сериализации — строго по таблице FORMAT.md §5 (§7.3)
    static W3C_ORDER := [
        "Digit1", "Digit2", "Digit3", "Digit4", "Digit5", "Digit6", "Digit7", "Digit8",
        "Digit9", "Digit0", "Minus", "Equal", "KeyQ", "KeyW", "KeyE", "KeyR",
        "KeyT", "KeyY", "KeyU", "KeyI", "KeyO", "KeyP", "BracketLeft", "BracketRight",
        "KeyA", "KeyS", "KeyD", "KeyF", "KeyG", "KeyH", "KeyJ", "KeyK",
        "KeyL", "Semicolon", "Quote", "Backslash", "KeyZ", "KeyX", "KeyC", "KeyV",
        "KeyB", "KeyN", "KeyM", "Comma", "Period", "Slash", "Space", "Backquote"
    ]

    ; --- дефолтная раскладка (PLAN.md §2.2), уже в hex-виде [altHex, altShiftHex] ---
    static DEFAULT_LAYOUT := Map(
        "Digit1", ["00B9", "00A1"], "Digit2", ["00B2", "00BD"], "Digit3", ["00B3", "2153"],
        "Digit4", ["0024", "00BC"], "Digit5", ["2030", "0020"], "Digit6", ["2191", "0302"],
        "Digit7", ["2197", "00BF"], "Digit8", ["221E", "2194"], "Digit9", ["2190", "2039"],
        "Digit0", ["2192", "203A"], "Minus", ["2014", "2013"], "Equal", ["2260", "00B1"],
        "KeyQ", ["0020", "0306"], "KeyW", ["2713", "2303"], "KeyE", ["20AC", "2325"],
        "KeyR", ["00AE", "030A"], "KeyT", ["2122", ""], "KeyY", ["0463", "0462"],
        "KeyU", ["0475", "0474"], "KeyI", ["0456", "0406"], "KeyO", ["0473", "0472"],
        "KeyP", ["2032", "2033"], "BracketLeft", ["005B", "007B"], "BracketRight", ["005D", "007D"],
        "KeyA", ["2248", "2318"], "KeyS", ["00A7", "21E7"], "KeyD", ["00B0", "2300"],
        "KeyF", ["00A3", "0020"], "KeyG", ["0020", "229E"], "KeyH", ["20BD", "030B"],
        "KeyJ", ["201E", "0020"], "KeyK", ["201C", "2018"], "KeyL", ["201D", "2019"],
        "Semicolon", ["2018", "0308"], "Quote", ["2019", "0020"], "Backslash", ["007C", "005C"],
        "KeyZ", ["0020", "0327"], "KeyX", ["00D7", "00B7"], "KeyC", ["00A9", "00A2"],
        "KeyV", ["2193", "030C"], "KeyB", ["00DF", "1E9E"], "KeyN", ["2116", "0303"],
        "KeyM", ["2212", "2022"], "Comma", ["00AB", "201E"], "Period", ["00BB", "201C"],
        "Slash", ["2026", "0301"], "Space", ["00A0", "0020"], "Backquote", ["", "0060"]
    )

    static __New() {
        this.SC_TO_W3C := Map()
        for w3c, sc in this.W3C_TO_SC
            this.SC_TO_W3C[sc] := w3c
    }

    ; =========================================================================
    ;  Чистые функции hex <-> строка (PLAN.md §2.4) — юнит-тестируемы.
    ; =========================================================================

    ; "0020+00B7+0020" -> " · ".  Невалидный hex -> исключение.
    static HexToString(hexValue) {
        if (hexValue = "")
            return ""
        result := ""
        for part in StrSplit(hexValue, "+") {
            part := Trim(part)
            if !RegExMatch(part, "^[0-9A-Fa-f]{1,6}$")
                throw ValueError("Невалидный кодпоинт: '" part "' в '" hexValue "'")
            cp := Integer("0x" part)
            if (cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF))
                throw ValueError("Кодпоинт вне диапазона/суррогат: " part)
            result .= Chr(cp)
        }
        return result
    }

    ; " · " -> "0020+00B7+0020".  Итерация по кодпоинтам (эмодзи = суррогатная пара).
    static StringToHex(str) {
        if (str = "")
            return ""
        out := ""
        i := 1
        len := StrLen(str)
        while (i <= len) {
            cp := Ord(SubStr(str, i, 2))         ; Ord склеит суррогатную пару
            out .= (out = "" ? "" : "+") . Format("{:04X}", cp)
            i += (cp > 0xFFFF) ? 2 : 1
        }
        return out
    }

    ; =========================================================================
    ;  Парсер (FORMAT.md §2.1, §4) и сериализатор (§6, §7) — без I/O.
    ; =========================================================================

    static NewData() {
        return Map(
            "version", 0,
            "layout", Map(),          ; w3cName -> {alt, altShift} (декодированные строки)
            "layoutUnknown", [],      ; сырые строки неизвестных ключей [Layout]
            "windows", Map(),         ; key -> value
            "typograph", Map(),       ; key -> value (секция [Typograph], общая с mac)
            "foreign", []             ; {header, lines[]} неизвестных секций (вкл. [macOS])
        )
    }

    static ParseText(text) {
        text := this.StripBom(text)
        data := this.NewData()
        section := ""
        inForeign := false
        foreignCur := ""
        Loop Parse text, "`n", "`r" {
            rawLine := A_LoopField
            t := Trim(rawLine)
            if RegExMatch(t, "^\[(.*)\]$", &m) {
                section := m[1]
                if (section = "hypetype" || section = "Layout" || section = "Windows" || section = "Typograph") {
                    inForeign := false
                } else {
                    inForeign := true
                    foreignCur := {header: "[" section "]", lines: []}
                    data["foreign"].Push(foreignCur)
                }
                continue
            }
            if (inForeign) {
                foreignCur.lines.Push(rawLine)     ; round-trip: байт-в-байт
                continue
            }
            line := Trim(this.StripComment(rawLine))
            if (line = "")
                continue
            pos := InStr(line, "=")
            if (!pos)
                continue
            key := Trim(SubStr(line, 1, pos - 1))
            val := Trim(SubStr(line, pos + 1))
            if (section = "hypetype") {
                if (key = "version")
                    data["version"] := IsInteger(val) ? Integer(val) : 0
            } else if (section = "Windows") {
                data["windows"][key] := val
            } else if (section = "Typograph") {
                data["typograph"][key] := val
            } else if (section = "Layout") {
                this.ParseLayoutLine(data, key, val, rawLine)
            }
        }
        return data
    }

    static ParseLayoutLine(data, key, val, rawLine) {
        if !this.W3C_TO_SC.Has(key) {
            data["layoutUnknown"].Push(rawLine)    ; неизвестный ключ -> round-trip (§7.2)
            return
        }
        if (this.CountChar(val, "|") != 1) {
            OutputDebug("hypetype: пропущена битая строка [Layout] (нужен ровно один '|'): " key "=" val "`n")
            return
        }
        parts := StrSplit(val, "|")
        try {
            alt := this.HexToString(this.LimitCps(Trim(parts[1])))
            shift := this.HexToString(this.LimitCps(Trim(parts[2])))
        } catch as e {
            OutputDebug("hypetype: пропущена битая строка [Layout] " key ": " e.Message "`n")
            return
        }
        if (alt = "" && shift = "")
            return                                 ; KeyX=| эквивалентно отсутствию (§4.5)
        data["layout"][key] := {alt: alt, altShift: shift}
    }

    static BuildText(data) {
        nl := "`r`n"
        out := "[hypetype]" nl "version=2" nl nl "[Layout]" nl
        for name in this.W3C_ORDER {
            if !data["layout"].Has(name)
                continue
            e := data["layout"][name]
            left := name "=" this.StringToHex(e.alt) "|" this.StringToHex(e.altShift)
            out .= this.PadRight(left, 24) " " this.RenderComment(e.alt, e.altShift) nl
        }
        for raw in data["layoutUnknown"]
            out .= raw nl
        out .= nl "[Windows]" nl
        if !data["windows"].Has("DiacriticTimeoutMs")
            data["windows"]["DiacriticTimeoutMs"] := "3000"
        for k, v in data["windows"]
            out .= k "=" v nl
        if (data["typograph"].Count > 0) {        ; пишем только если пользователь задал настройки
            out .= nl "[Typograph]" nl
            for k, v in data["typograph"]
                out .= k "=" v nl
        }
        for sec in data["foreign"] {
            out .= nl sec.header nl
            for l in sec.lines
                out .= l nl
        }
        return out
    }

    ; --- автокомментарий (FORMAT.md §6) ---
    static RenderComment(alt, altShift) {
        return "; " this.RenderValue(alt) " | " this.RenderValue(altShift)
    }
    static RenderValue(s) {
        if (s = "")
            return "—"
        out := ""
        i := 1, len := StrLen(s)
        while (i <= len) {
            cp := Ord(SubStr(s, i, 2))
            i += (cp > 0xFFFF) ? 2 : 1
            out .= this.RenderCp(cp)
        }
        return out
    }
    static RenderCp(cp) {
        if (cp >= 0x0300 && cp <= 0x036F)
            return Chr(0x25CC) Chr(cp)             ; ◌ + комбинирующая
        if (cp = 0x20)
            return Chr(0x2423)                     ; ␣
        if (cp = 0xA0)
            return Chr(0x237D)                     ; ⍽ (nbsp)
        if (cp = 0x200B)
            return "ZWSP"
        if (cp < 0x20 || cp = 0x7F || (cp >= 0x80 && cp <= 0x9F))
            return "·U+" Format("{:04X}", cp) "·"  ; прочие управляющие/невидимые
        return Chr(cp)
    }

    ; =========================================================================
    ;  Миграция legacy (FORMAT.md §8.1)
    ; =========================================================================

    static IsLegacy(text) {
        return this.ParseText(text)["version"] < 2
    }

    static MigrateLegacy(text) {
        text := this.StripBom(text)
        data := this.NewData()
        data["version"] := 2
        Loop Parse text, "`n", "`r" {
            t := Trim(A_LoopField)
            if (t = "" || RegExMatch(t, "^\[.*\]$"))
                continue
            pos := InStr(t, "=")
            if (!pos)
                continue
            sc := Trim(SubStr(t, 1, pos - 1))
            if !this.SC_TO_W3C.Has(sc)
                continue
            rest := SubStr(t, pos + 1)             ; значения не триммим (пробел значим)
            cpos := InStr(rest, ",")               ; делим по ПЕРВОЙ запятой (§8.1)
            if (cpos) {
                a := SubStr(rest, 1, cpos - 1)
                b := SubStr(rest, cpos + 1)
            } else {
                a := rest, b := ""
            }
            if (a = "" && b = "")
                continue
            data["layout"][this.SC_TO_W3C[sc]] := {alt: a, altShift: b}
        }
        data["windows"]["DiacriticTimeoutMs"] := "3000"
        return data
    }

    ; =========================================================================
    ;  Публичный API
    ; =========================================================================

    static Load() {
        this.DeterminePath()
        if FileExist(this.Path) {
            text := FileRead(this.Path, "UTF-8")
            if this.IsLegacy(text) {
                this.BackupLegacy()
                this._data := this.MigrateLegacy(text)
                this.Save()
            } else {
                this._data := this.ParseText(text)
            }
        } else {
            this._data := this.DefaultData()
            this.Save()
        }
    }

    static Save() {
        text := this.BuildText(this._data)
        tmp := this.Path ".tmp"
        f := ""
        try {
            f := FileOpen(tmp, "w", "UTF-8-RAW")   ; UTF-8 без BOM
            if !IsObject(f)
                throw OSError("Не удалось открыть для записи: " tmp)
            f.Write(text)
            f.Close()
            f := ""
            FileMove(tmp, this.Path, true)         ; атомарная замена
        } finally {
            if IsObject(f)
                f.Close()
            if FileExist(tmp)
                FileDelete(tmp)
        }
    }

    static GetKey(w3cName) {
        if this._data["layout"].Has(w3cName)
            return this._data["layout"][w3cName]
        return {alt: "", altShift: ""}
    }

    static SetKey(w3cName, alt, altShift) {
        if (alt = "" && altShift = "") {
            if this._data["layout"].Has(w3cName)
                this._data["layout"].Delete(w3cName)
        } else {
            this._data["layout"][w3cName] := {alt: alt, altShift: altShift}
        }
        this.Save()
    }

    static Keys() {
        return this.W3C_ORDER
    }

    static GetSetting(name, default) {
        if this._data["windows"].Has(name)
            return this._data["windows"][name]
        return default
    }

    ; настройки секции [Typograph] (общая секция, TYPOGRAPH.md §7)
    static GetTypographSetting(name, default) {
        if this._data["typograph"].Has(name)
            return this._data["typograph"][name]
        return default
    }

    ; Перечитать [Typograph] из файла (правки конфига применяются без перезапуска, §9.3.8).
    static RefreshTypograph() {
        if !FileExist(this.Path)
            return
        try
            this._data["typograph"] := this.ParseText(FileRead(this.Path, "UTF-8"))["typograph"]
    }

    ; Переключить булеву настройку [Typograph] 0<->1 и сохранить. Возвращает новое значение.
    static ToggleTypograph(name, default := "0") {
        this.RefreshTypograph()                                    ; синхронизироваться с файлом
        next := (this.GetTypographSetting(name, default) = "1") ? "0" : "1"
        this._data["typograph"][name] := next
        this.Save()
        return next
    }

    ; =========================================================================
    ;  Путь (FORMAT/PLAN §2.1) и дефолт
    ; =========================================================================

    static DefaultData() {
        d := this.NewData()
        d["version"] := 2
        for name, pair in this.DEFAULT_LAYOUT {
            alt := this.HexToString(pair[1])
            shift := this.HexToString(pair[2])
            if (alt = "" && shift = "")
                continue
            d["layout"][name] := {alt: alt, altShift: shift}
        }
        d["windows"]["DiacriticTimeoutMs"] := "3000"
        ; секция [Typograph] пишется сразу при первом запуске — чтобы ёфикатор (Yo)
        ; и группы было видно и легко включить (TYPOGRAPH.md §7)
        for k in ["Quotes", "Dashes", "Punct", "SpaceClean", "Nbsp", "Numbers", "Symbols"]
            d["typograph"][k] := "1"
        d["typograph"]["Yo"] := "0"
        d["typograph"]["PercentSpace"] := "none"
        d["typograph"]["CurrencyPosition"] := "after"
        return d
    }

    static DeterminePath() {
        this.PendingNotice := ""
        localPath := A_ScriptDir "\config.ini"
        if FileExist(localPath) {                   ; портабельный режим — приоритет
            this.Path := localPath, this.IsPortable := true
            return
        }
        if this.CanWriteDir(A_ScriptDir) {
            this.Path := localPath, this.IsPortable := true
            return
        }
        appdir := A_AppData "\hypetype"
        appcfg := appdir "\config.ini"
        if !FileExist(appcfg)                      ; первый переход на AppData
            this.PendingNotice := "Папка программы защищена от записи, настройки сохранены в:`n" appcfg
        if !DirExist(appdir)
            DirCreate(appdir)
        this.Path := appcfg, this.IsPortable := false
    }

    static CanWriteDir(dir) {
        test := dir "\.hypetype_write_test.tmp"
        try {
            f := FileOpen(test, "w")
            if !IsObject(f)
                return false
            f.Close()
            FileDelete(test)
            return true
        } catch {
            return false
        }
    }

    static BackupLegacy() {
        SplitPath(this.Path, , &dir)
        FileCopy(this.Path, dir "\config.old.ini", true)
    }

    ; =========================================================================
    ;  Мелкие помощники
    ; =========================================================================

    static StripBom(text) {
        return (SubStr(text, 1, 1) = Chr(0xFEFF)) ? SubStr(text, 2) : text
    }
    static StripComment(line) {
        pos := InStr(line, ";")
        return pos ? SubStr(line, 1, pos - 1) : line
    }
    static CountChar(s, ch) {
        return StrLen(s) - StrLen(StrReplace(s, ch))
    }
    static LimitCps(hex) {
        if (hex = "")
            return ""
        parts := StrSplit(hex, "+")
        if (parts.Length <= 32)
            return hex
        OutputDebug("hypetype: значение обрезано до 32 кодпоинтов`n")
        out := ""
        Loop 32
            out .= (out = "" ? "" : "+") parts[A_Index]
        return out
    }
    static PadRight(s, n) {
        while (StrLen(s) < n)
            s .= " "
        return s
    }
}
