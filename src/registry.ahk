#Requires AutoHotkey v2.0

; =============================================================================
;  registry.ahk — единственный код, трогающий реестр.
;  ScancodeMap (виртуализация правого Alt) и Autostart.
;  Не показывает MsgBox: возвращает статусы/результаты наверх.
;  Запись в HKLM ВСЕГДА предваряется .reg-бэкапом (PLAN.md §3.1).
; =============================================================================

; -----------------------------------------------------------------------------
;  Чистые функции бинарного блоба Scancode Map (PLAN.md §3.1) — без реестра.
;
;  Формат: DWORD header(0) | DWORD flags(0) | DWORD count | entry[count-1] |
;          DWORD terminator(0).  count = число 4-байтовых записей ВКЛЮЧАЯ
;          нулевой терминатор. Запись = WORD new, WORD orig (little-endian).
; -----------------------------------------------------------------------------

; "00000000000000000200000068E038E000000000" -> [{new:0xE068, orig:0xE038}]
; Невалидный/обрезанный блоб -> исключение (наверх: «не трогаем реестр»).
ParseScancodeMap(hexString) {
    hex := StrUpper(RegExReplace(hexString, "\s", ""))
    if (hex = "" || !RegExMatch(hex, "^[0-9A-F]+$") || Mod(StrLen(hex), 2) != 0)
        throw ValueError("Невалидный Scancode Map (не hex или нечётная длина)")
    byteLen := StrLen(hex) // 2
    if (byteLen < 16)
        throw ValueError("Scancode Map обрезан: " byteLen " байт (минимум 16)")

    GetByte(o) => Integer("0x" SubStr(hex, o * 2 + 1, 2))
    GetWord(o) => GetByte(o) | (GetByte(o + 1) << 8)
    GetDword(o) => GetByte(o) | (GetByte(o + 1) << 8) | (GetByte(o + 2) << 16) | (GetByte(o + 3) << 24)

    count := GetDword(8)
    expected := 12 + count * 4
    if (count < 1 || byteLen != expected)
        throw ValueError("Scancode Map: длина " byteLen " байт не соответствует count=" count)

    entries := []
    Loop count - 1 {
        o := 12 + (A_Index - 1) * 4
        entries.Push({new: GetWord(o), orig: GetWord(o + 2)})
    }
    return entries
}

; [{new:0xE068, orig:0xE038}] -> "00000000000000000200000068E038E000000000"
BuildScancodeMap(entries) {
    DwordLE(n) => Format("{:02X}{:02X}{:02X}{:02X}", n & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF, (n >> 24) & 0xFF)
    WordLE(n) => Format("{:02X}{:02X}", n & 0xFF, (n >> 8) & 0xFF)

    hex := "00000000" "00000000" DwordLE(entries.Length + 1)   ; header, flags, count
    for e in entries
        hex .= WordLE(e.new) WordLE(e.orig)
    hex .= "00000000"                                           ; терминатор
    return hex
}

; -----------------------------------------------------------------------------
;  ScancodeMap — виртуализация правого Alt (E0 38 -> E0 68 = vkA9).
; -----------------------------------------------------------------------------
class ScancodeMap {
    static REG_KEY := "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout"
    static REG_VAL := "Scancode Map"
    static OUR_NEW := 0xE068      ; правый Alt становится vkA9
    static OUR_ORIG := 0xE038     ; физический правый Alt

    ; --- чтение (безопасно, без прав админа) ---
    static ReadRaw() {
        try
            return RegRead(this.REG_KEY, this.REG_VAL)
        catch
            return ""             ; значения нет
    }

    ; Классификация распарсенных записей — чистая логика (юнит-тестируема).
    static ClassifyEntries(entries) {
        for e in entries {
            if (e.orig = this.OUR_ORIG)
                return (e.new = this.OUR_NEW) ? "ours" : "foreign-ralt"
        }
        return "other"
    }

    ; "none" | "ours" | "foreign-ralt" | "other"  (галочка в трее = "ours")
    static Status() {
        raw := this.ReadRaw()
        if (raw = "")
            return "none"
        try
            return this.ClassifyEntries(ParseScancodeMap(raw))
        catch
            return "other"        ; нечитаемый блоб — точно не наш, ralt не трогаем
    }

    ; Результат: {ok, status}.  status: noadmin|badblob|foreign-ralt|already|enabled
    static Enable() {
        if !A_IsAdmin
            return {ok: false, status: "noadmin"}
        raw := this.ReadRaw()
        entries := []
        if (raw != "") {
            try
                entries := ParseScancodeMap(raw)
            catch
                return {ok: false, status: "badblob"}
            cls := this.ClassifyEntries(entries)
            if (cls = "ours")
                return {ok: true, status: "already"}
            if (cls = "foreign-ralt")
                return {ok: false, status: "foreign-ralt"}
        }
        entries.Push({new: this.OUR_NEW, orig: this.OUR_ORIG})
        RegWrite(BuildScancodeMap(entries), "REG_BINARY", this.REG_KEY, this.REG_VAL)
        return {ok: true, status: "enabled"}
    }

    ; Результат: {ok, status}.  status: noadmin|badblob|already-off|notpresent|disabled
    static Disable() {
        if !A_IsAdmin
            return {ok: false, status: "noadmin"}
        raw := this.ReadRaw()
        if (raw = "")
            return {ok: true, status: "already-off"}
        try
            entries := ParseScancodeMap(raw)
        catch
            return {ok: false, status: "badblob"}

        kept := []
        found := false
        for e in entries {
            if (e.orig = this.OUR_ORIG && e.new = this.OUR_NEW)
                found := true
            else
                kept.Push(e)
        }
        if !found
            return {ok: true, status: "notpresent"}   ; нашей записи нет — ничего не трогаем

        if (kept.Length = 0)
            RegDelete(this.REG_KEY, this.REG_VAL)      ; наша была единственной
        else
            RegWrite(BuildScancodeMap(kept), "REG_BINARY", this.REG_KEY, this.REG_VAL)
        return {ok: true, status: "disabled"}
    }
}

; -----------------------------------------------------------------------------
;  Autostart — HKCU\...\Run (без прав админа).
; -----------------------------------------------------------------------------
class Autostart {
    static REG_KEY := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
    static REG_VAL := "hypetype"

    static IsEnabled() {
        try
            cur := RegRead(this.REG_KEY, this.REG_VAL)
        catch
            return false
        return (StrLower(cur) = StrLower(A_ScriptFullPath))   ; включено только если путь = текущий exe
    }

    static Enable() {
        RegWrite(A_ScriptFullPath, "REG_SZ", this.REG_KEY, this.REG_VAL)   ; перезапишет устаревший путь
    }

    static Disable() {
        try
            RegDelete(this.REG_KEY, this.REG_VAL)
    }

    static Toggle() {
        if this.IsEnabled()
            this.Disable()
        else
            this.Enable()
    }
}
