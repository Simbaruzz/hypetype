#Requires AutoHotkey v2.0

; =============================================================================
;  editor2.ahk — спайк нового редактора-клавиатуры (UI-SPIKE.md).
;  Тёмная тема, кейкапы из Text-контролов (кнопки не умеют цвет/двухэтажность),
;  данные — только через API Config (GetKey/SetKey/Keys). Старый editor.ahk
;  не трогаем; интеграции в hypetype.ahk нет до вердикта владельца.
; =============================================================================

class Editor2 {
    static _gui := ""
    static _caps := Map()           ; w3cName -> {alt: Text, shift: Text} для обновления подписей

    ; --- палитра (тона по скриншотам мака, _preview/) ---
    static COL_BG   := "121212"     ; фон окна
    static COL_KEY  := "1E1E1E"     ; тело клавиши
    static COL_HYPE := "F2F2F2"     ; подсвеченная хайп-клавиша (правый Alt)
    static COL_MAIN := "FFFFFF"     ; основной символ (с Alt)
    static COL_SHIFT := "B873FF"    ; Shift-символ (фиолетовый акцент)
    static COL_BASE := "757575"     ; буква клавиши и декор-глифы
    static COL_HINT := "8C8C8C"     ; текст подсказки внизу
    static FONT := "Segoe UI"       ; системный; глифы добирает фонт-линкинг GDI

    ; --- сетка: логические px при 100% DPI; встроенный DPIScale v2 множит сам ---
    static U := 56                  ; ширина клавиши 1u
    static KH := 52                 ; высота клавиши
    static GAP := 6                 ; зазор между клавишами
    static MARGIN := 16             ; поля окна

    ; -------------------------------------------------------------------------
    static Show() {
        if !this._gui
            this.Build()
        this._gui.Show()
    }

    ; мнемоники рядов: mappable-клавиши в порядке физической клавиатуры
    static ROW1 := ["Backquote", "Digit1", "Digit2", "Digit3", "Digit4", "Digit5",
                    "Digit6", "Digit7", "Digit8", "Digit9", "Digit0", "Minus", "Equal"]
    static ROW2 := ["KeyQ", "KeyW", "KeyE", "KeyR", "KeyT", "KeyY", "KeyU", "KeyI",
                    "KeyO", "KeyP", "BracketLeft", "BracketRight", "Backslash"]
    static ROW3 := ["KeyA", "KeyS", "KeyD", "KeyF", "KeyG", "KeyH", "KeyJ", "KeyK",
                    "KeyL", "Semicolon", "Quote"]
    static ROW4 := ["KeyZ", "KeyX", "KeyC", "KeyV", "KeyB", "KeyN", "KeyM",
                    "Comma", "Period", "Slash"]

    ; подписи-буквы кейкапов
    static DISPLAY := Map(
        "Backquote","`` ", "Digit1","1", "Digit2","2", "Digit3","3", "Digit4","4",
        "Digit5","5", "Digit6","6", "Digit7","7", "Digit8","8", "Digit9","9",
        "Digit0","0", "Minus","-", "Equal","=",
        "KeyQ","Q", "KeyW","W", "KeyE","E", "KeyR","R", "KeyT","T", "KeyY","Y",
        "KeyU","U", "KeyI","I", "KeyO","O", "KeyP","P", "BracketLeft","[", "BracketRight","]",
        "Backslash","\", "KeyA","A", "KeyS","S", "KeyD","D", "KeyF","F", "KeyG","G",
        "KeyH","H", "KeyJ","J", "KeyK","K", "KeyL","L", "Semicolon",";", "Quote","'",
        "KeyZ","Z", "KeyX","X", "KeyC","C", "KeyV","V", "KeyB","B", "KeyN","N",
        "KeyM","M", "Comma",",", "Period",".", "Slash","/", "Space","SPACE"
    )

    static Build() {
        g := Gui("-Resize", Txt.MainTitle)
        g.BackColor := this.COL_BG
        g.MarginX := this.MARGIN, g.MarginY := this.MARGIN
        g.OnEvent("Close", (*) => ExitApp())    ; спайк: закрыл окно — вышел
        this._gui := g
        this.ApplyDarkTitle(g)

        U := this.U, KH := this.KH, GAP := this.GAP
        ; ширина контента = ряд №1: 13×1u + ТИПОГРАФ (1.5u), 13 зазоров
        contentW := 13 * U + Round(1.5 * U) + 13 * GAP

        ; --- ряд 1: ` 1…0 - =  + ТИПОГРАФ ---
        x := this.MARGIN, y := this.MARGIN
        for name in this.ROW1
            x := this.AddKeycap(g, x, y, U, name)
        this.AddTypoKey(g, x, y, contentW + this.MARGIN - x)

        ; --- ряд 2: Tab + Q…P [ ] \ ---
        x := this.MARGIN, y += KH + GAP
        x := this.AddDecor(g, x, y, Round(1.5 * U), Chr(0x21E5), "BL")   ; ⇥
        for name in this.ROW2
            x := this.AddKeycap(g, x, y, U, name)

        ; --- ряд 3: Caps + A…' + Enter (узкий «маковский») ---
        x := this.MARGIN, y += KH + GAP
        x := this.AddDecor(g, x, y, Round(1.75 * U), Chr(0x21EA), "BL")  ; ⇪
        for name in this.ROW3
            x := this.AddKeycap(g, x, y, U, name)
        this.AddDecor(g, x, y, contentW + this.MARGIN - x, Chr(0x21B5), "BR")  ; ↵

        ; --- ряд 4: Shift + Z…/ + Shift ---
        x := this.MARGIN, y += KH + GAP
        wshift := (contentW - 10 * U - 11 * GAP) // 2
        x := this.AddDecor(g, x, y, wshift, "SHIFT", "L", this.COL_SHIFT)
        for name in this.ROW4
            x := this.AddKeycap(g, x, y, U, name)
        this.AddDecor(g, x, y, contentW + this.MARGIN - x, "SHIFT", "R", this.COL_SHIFT)

        ; --- ряд 5: ⓘ ctrl win alt SPACE alt(хайп) win ctrl стрелки ---
        x := this.MARGIN, y += KH + GAP
        arrowsW := 3 * U + 2 * GAP
        spaceW := contentW - 7 * U - arrowsW - 10 * GAP
        x := this.AddDecor(g, x, y, U, Chr(0x24D8), "C")                 ; ⓘ
        for label in ["ctrl", "win", "alt"]
            x := this.AddDecor(g, x, y, U, label, "C")
        x := this.AddKeycap(g, x, y, spaceW, "Space")
        x := this.AddHypeKey(g, x, y, U)
        for label in ["win", "ctrl"]
            x := this.AddDecor(g, x, y, U, label, "C")
        this.AddArrows(g, x, y)

        contentH := 5 * KH + 4 * GAP
        g.Show(Format("w{} h{} Hide", contentW + 2 * this.MARGIN, contentH + 2 * this.MARGIN))
    }

    ; -------------------------------------------------------------------------
    ;  Конструкторы клавиш. Каждая возвращает x следующей клавиши.
    ; -------------------------------------------------------------------------

    ; тело клавиши — Text с тёмным фоном (кнопки не умеют цвет, UI-SPIKE §3.2)
    static AddBody(g, x, y, w, h := -1, bg := "") {
        h := (h = -1) ? this.KH : h
        bg := (bg = "") ? this.COL_KEY : bg
        return g.AddText(Format("x{} y{} w{} h{} Background{}", x, y, w, h, bg))
    }

    ; mappable-кейкап: тело + 3 слоя подписей — Alt+Shift (верх, акцент),
    ; буква (низ-лево, приглушена), Alt-символ (низ-право, белый)
    static AddKeycap(g, x, y, w, name) {
        this.AddBody(g, x, y, w)
        k := Config.GetKey(name)
        g.SetFont("s8", this.FONT)
        shiftCtrl := g.AddText(Format("x{} y{} w{} h14 Right Background{} c{}",
            x + 6, y + 5, w - 12, this.COL_KEY, this.COL_SHIFT), this.KeyRepr(k.altShift))
        baseW := (name = "Space") ? 60 : 18
        g.SetFont("s9", this.FONT)
        g.AddText(Format("x{} y{} w{} h16 Background{} c{}",
            x + 6, y + this.KH - 21, baseW, this.COL_KEY, this.COL_BASE), this.DISPLAY[name])
        g.SetFont("s12", this.FONT)
        altCtrl := g.AddText(Format("x{} y{} w{} h20 Right Background{} c{}",
            x + 6 + baseW, y + this.KH - 26, w - baseW - 12, this.COL_KEY, this.COL_MAIN), this.KeyRepr(k.alt))
        this._caps[name] := {alt: altCtrl, shift: shiftCtrl}
        return x + w + this.GAP
    }

    ; отображение значения на кейкапе (UI-SPIKE §3.4): до 3 кодпоинтов + «…»,
    ; подстановки невидимых символов — Config.RenderCp (переиспользуем, не дублируем)
    static KeyRepr(value) {
        if (value = "")
            return ""
        out := "", shown := 0
        i := 1, len := StrLen(value)
        while (i <= len && shown < 3) {
            cp := Ord(SubStr(value, i, 2))
            i += (cp > 0xFFFF) ? 2 : 1
            out .= Config.RenderCp(cp)
            shown++
        }
        if (i <= len)
            out .= "…"
        return out
    }

    ; декор-клавиша: тело + один приглушённый глиф; align: BL/BR/L/R/C
    static AddDecor(g, x, y, w, glyph, align := "C", color := "") {
        color := (color = "") ? this.COL_BASE : color
        this.AddBody(g, x, y, w)
        g.SetFont("s9", this.FONT)
        switch align {
            case "BL": opt := Format("x{} y{} w{}", x + 8, y + this.KH - 20, w - 16)
            case "BR": opt := Format("x{} y{} w{} Right", x + 8, y + this.KH - 20, w - 16)
            case "L":  opt := Format("x{} y{} w{}", x + 10, y + this.KH // 2 - 7, w - 20)
            case "R":  opt := Format("x{} y{} w{} Right", x + 10, y + this.KH // 2 - 7, w - 20)
            default:   opt := Format("x{} y{} w{} Center", x + 2, y + this.KH // 2 - 7, w - 4)
        }
        g.AddText(opt " Background1E1E1E c" color, glyph)
        return x + w + this.GAP
    }

    ; широкая клавиша ТИПОГРАФ на месте Backspace
    static AddTypoKey(g, x, y, w) {
        this.AddBody(g, x, y, w)
        g.SetFont("s8", this.FONT)
        g.AddText(Format("x{} y{} w{} Center Background1E1E1E c{}", x + 2, y + 8, w - 4, this.COL_MAIN),
            "ТИПОГРАФ")
        g.SetFont("s10", this.FONT)
        g.AddText(Format("x{} y{} w{} Center Background1E1E1E c{}", x + 2, y + this.KH - 24, w - 4, this.COL_BASE),
            Chr(0x232B))                                          ; ⌫
        return x + w + this.GAP
    }

    ; подсвеченная хайп-клавиша (правый Alt) — светлое тело, тёмная подпись
    static AddHypeKey(g, x, y, w) {
        this.AddBody(g, x, y, w, -1, this.COL_HYPE)
        g.SetFont("s9", this.FONT)
        g.AddText(Format("x{} y{} w{} Center Background{} c1A1A1A", x + 2, y + this.KH // 2 - 7, w - 4, this.COL_HYPE),
            "alt")
        return x + w + this.GAP
    }

    ; кластер стрелок: ← [↑/↓] → , полувысотные клавиши (декор)
    static AddArrows(g, x, y) {
        hh := (this.KH - this.GAP) // 2
        yb := y + this.KH - hh                                    ; низ ряда
        g.SetFont("s7", this.FONT)
        for pair in [[x, yb, Chr(0x25C4)], [x + this.U + this.GAP, y, Chr(0x25B2)],
                     [x + this.U + this.GAP, yb, Chr(0x25BC)], [x + 2 * (this.U + this.GAP), yb, Chr(0x25BA)]] {
            this.AddBody(g, pair[1], pair[2], this.U, hh)
            g.AddText(Format("x{} y{} w{} Center Background1E1E1E c{}", pair[1] + 2, pair[2] + hh // 2 - 6, this.U - 4, this.COL_BASE),
                pair[3])
        }
        return x + 3 * this.U + 2 * this.GAP + this.GAP
    }

    ; тёмный заголовок: DWMWA_USE_IMMERSIVE_DARK_MODE = 20, фолбэк 19 (UI-SPIKE §3.3)
    static ApplyDarkTitle(g) {
        for attr in [20, 19] {
            hr := DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd,
                "int", attr, "int*", 1, "int", 4, "int")
            if (hr = 0)
                break
        }
    }
}
