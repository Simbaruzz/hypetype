#Requires AutoHotkey v2.0

; =============================================================================
;  input.ahk — регистрация хоткеев, обработчик ввода, диакритический режим.
;  Данные берёт у Config (актуальные на каждом нажатии). Без BlockInput.
; =============================================================================

class KeyInput {
    static MODIFIER := "vkA9"        ; правый Alt после виртуализации (PLAN.md §4.1)

    ; таймауты буферной механики типографа (TYPOGRAPH.md §2), константами
    static COPY_TIMEOUT := 0.4       ; сек на ClipWait после Ctrl+C
    static PASTE_DELAY := 150        ; мс: дать приложению прочитать буфер до восстановления

    ; состояние диакритического режима (приватное, не глобалы)
    static _ih := ""

    ; -------------------------------------------------------------------------
    ;  Инициализация: хоткеи на все 48 клавиш + Alt+Enter. Зовётся из точки входа.
    ; -------------------------------------------------------------------------
    static Init() {
        SendMode("Input")
        SetKeyDelay(-1)
        for w3cName in Config.Keys() {
            sc := Config.W3C_TO_SC[w3cName]
            ; ObjBindMethod привязывает и this (=KeyInput), и w3cName корректно.
            ; (Class.StaticMethod как значение в v2 отдаётся БЕЗ this — простой .Bind ломается.)
            Hotkey(this.MODIFIER " & " sc, ObjBindMethod(this, "OnSymbolKey", w3cName))
        }
        ; Alt+Enter работает как обычный системный Alt+Enter (фича v1)
        Hotkey(this.MODIFIER " & Enter", (*) => Send("{LAlt down}{Enter}{LAlt up}"))
        ; Alt+Backspace — типографировать выделенный текст (TYPOGRAPH.md §2)
        Hotkey(this.MODIFIER " & SC00E", ObjBindMethod(this, "OnTypograph"))
    }

    ; -------------------------------------------------------------------------
    ;  Обработчик нажатия (PLAN.md §4.2). Значение берётся прямо сейчас —
    ;  правки в редакторе применяются мгновенно, без перезапуска.
    ; -------------------------------------------------------------------------
    static OnSymbolKey(w3cName, *) {
        k := Config.GetKey(w3cName)
        value := GetKeyState("Shift", "P") ? k.altShift : k.alt
        if (value = "")
            return
        if this.IsSingleCombining(value)
            this.RunDiacritic(value)
        else
            SendText(value)
    }

    ; Ровно один кодпоинт в диапазоне 0300–036F (FORMAT.md семантика диакритики).
    static IsSingleCombining(s) {
        if (StrLen(s) != 1)
            return false
        cp := Ord(s)
        return (cp >= 0x0300 && cp <= 0x036F)
    }

    ; -------------------------------------------------------------------------
    ;  Диакритический режим (PLAN.md §4.3): ждём следующую букву, склеиваем,
    ;  нормализуем в NFC. InputHook, без BlockInput. Escape — отмена.
    ; -------------------------------------------------------------------------
    static RunDiacritic(mark) {
        timeoutSec := Config.GetSetting("DiacriticTimeoutMs", 3000) / 1000
        this.ShowTip(Chr(0x25CC) mark "  Введите букву")     ; ◌ + знак

        ih := InputHook("L1 T" timeoutSec)
        ih.KeyOpt("{Escape}", "E")        ; Escape — end-key (отмена)
        ih.VisibleText := false           ; перехват: буква не «проваливается» в окно
        this._ih := ih
        ih.Start()
        reason := ih.Wait()
        this._ih := ""
        this.HideTip()

        switch reason {
            case "Max":
                ch := ih.Input
                if (ch != "")
                    SendText(this.NormalizeNFC(ch mark))
            case "Timeout":
                this.FlashTip("Время ввода вышло")
            case "EndKey":
                this.FlashTip("Отменено")
        }
    }

    ; -------------------------------------------------------------------------
    ;  Нормализация NFC через Normaliz.dll (PLAN.md §4.4). Ошибки -> тихий фолбэк.
    ; -------------------------------------------------------------------------
    static NormalizeNFC(str) {
        static hDll := 0, pFn := 0
        if (!hDll) {
            hDll := DllCall("LoadLibrary", "Str", "Normaliz.dll", "Ptr")
            if (!hDll) {
                OutputDebug("hypetype: не удалось загрузить Normaliz.dll`n")
                return str
            }
            pFn := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "NormalizeString", "Ptr")
            if (!pFn) {
                OutputDebug("hypetype: NormalizeString не найден`n")
                return str
            }
        }
        ; 1 = NormalizationC (NFC)
        need := DllCall(pFn, "int", 1, "WStr", str, "int", StrLen(str), "ptr", 0, "int", 0, "int")
        if (need <= 0)
            return str
        buf := Buffer(need * 2, 0)        ; размер в WCHAR × 2 байта
        ret := DllCall(pFn, "int", 1, "WStr", str, "int", StrLen(str), "ptr", buf, "int", need, "int")
        if (ret <= 0)
            return str
        return StrGet(buf, ret, "UTF-16")
    }

    ; -------------------------------------------------------------------------
    ;  Типограф по RAlt+Backspace (TYPOGRAPH.md §2). Через буфер обмена.
    ; -------------------------------------------------------------------------
    static OnTypograph(*) {
        Config.RefreshTypograph()                    ; правки [Typograph] в конфиге — без перезапуска
        saved := ClipboardAll()                      ; сохранить буфер целиком (картинки/форматы)
        A_Clipboard := ""
        Send("^c")
        if !ClipWait(this.COPY_TIMEOUT) {            ; ничего не выделено / приложение не отдало
            this.FlashTip(Txt.TypoNoSelection)
            A_Clipboard := saved
            return
        }
        original := A_Clipboard
        result := Typograph.Run(original, this.TypographSettings())
        if (result == original) {                    ; уже типографировано — не дёргать вставку
            this.FlashTip(Txt.TypoAlready)
            A_Clipboard := saved
            return
        }
        A_Clipboard := result
        Send("^v")
        Sleep(this.PASTE_DELAY)                       ; дать приложению вставить до восстановления
        A_Clipboard := saved
        this.FlashTip(Txt.TypoDone)
    }

    ; Настройки [Typograph] из конфига (читаются на каждом нажатии — как раскладка).
    static TypographSettings() {
        s := Typograph.DefaultSettings()
        for k in ["Quotes", "Dashes", "Punct", "SpaceClean", "Nbsp", "Numbers", "Symbols"]
            s[k] := (Config.GetTypographSetting(k, "1") != "0")
        s["Yo"] := (Config.GetTypographSetting("Yo", "0") = "1")   ; ёфикатор: по умолчанию выкл
        s["PercentSpace"] := Config.GetTypographSetting("PercentSpace", "none")
        s["CurrencyPosition"] := Config.GetTypographSetting("CurrencyPosition", "after")
        return s
    }

    ; --- ToolTip-помощники (одна функция-таймер на скрытие, без x/y) ---
    static ShowTip(text) {
        ToolTip(text)
    }
    static HideTip() {
        ToolTip()
    }
    static FlashTip(text) {
        ToolTip(text)
        SetTimer(() => ToolTip(), -1200)
    }
}
