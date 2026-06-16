#Requires AutoHotkey v2.0

; =============================================================================
;  editor.ahk — GUI редактора раскладки (PLAN.md §5).
;  Окно создаётся лениво. Файл не пишет сам — зовёт Config.SetKey().
;  Пользователь видит только живые символы; hex — никогда.
; =============================================================================

class Editor {
    static _gui := ""
    static _buttons := Map()       ; w3cName -> Button control
    static _editGui := ""          ; текущее окно правки (одно за раз)
    static _font := "Cambria"
    static DONATE_URL := "https://boosty.to/simbarus/donate"   ; ссылка в подсказке
    static LINE_SPACING := 1.3     ; межстрочный интервал подсказки (крутить на глаз)

    ; подписи кнопок (клавиатурные кэпы) и физические ряды
    static DISPLAY := Map(
        "Digit1","1", "Digit2","2", "Digit3","3", "Digit4","4", "Digit5","5",
        "Digit6","6", "Digit7","7", "Digit8","8", "Digit9","9", "Digit0","0",
        "Minus","-", "Equal","=",
        "KeyQ","Q", "KeyW","W", "KeyE","E", "KeyR","R", "KeyT","T", "KeyY","Y",
        "KeyU","U", "KeyI","I", "KeyO","O", "KeyP","P", "BracketLeft","[", "BracketRight","]",
        "KeyA","A", "KeyS","S", "KeyD","D", "KeyF","F", "KeyG","G", "KeyH","H",
        "KeyJ","J", "KeyK","K", "KeyL","L", "Semicolon",";", "Quote","'", "Backslash","\",
        "KeyZ","Z", "KeyX","X", "KeyC","C", "KeyV","V", "KeyB","B", "KeyN","N",
        "KeyM","M", "Comma",",", "Period",".", "Slash","/", "Space",Chr(0x2423), "Backquote",Chr(0x60)
    )
    static ROWS := [
        ["Digit1","Digit2","Digit3","Digit4","Digit5","Digit6","Digit7","Digit8","Digit9","Digit0","Minus","Equal"],
        ["KeyQ","KeyW","KeyE","KeyR","KeyT","KeyY","KeyU","KeyI","KeyO","KeyP","BracketLeft","BracketRight"],
        ["KeyA","KeyS","KeyD","KeyF","KeyG","KeyH","KeyJ","KeyK","KeyL","Semicolon","Quote","Backslash"],
        ["KeyZ","KeyX","KeyC","KeyV","KeyB","KeyN","KeyM","Comma","Period","Slash","Space","Backquote"]
    ]

    ; -------------------------------------------------------------------------
    static Show() {
        if !this._gui
            this.Build()
        this._gui.Show()
    }

    static Build() {
        scale := A_ScreenDPI / 96
        logW := A_ScreenWidth / scale
        logH := A_ScreenHeight / scale
        wbtn := Round(logW * 0.03)
        hbtn := Round(wbtn * 1.65)
        spacing := Round(logW * 0.002)
        margin := 5 * spacing
        fontSize := Floor(logH * 0.014)

        g := Gui("+AlwaysOnTop +Border", Txt.MainTitle)
        g.BackColor := "FFFFFF"
        g.MarginX := margin, g.MarginY := margin   ; одинаковые отступы справа/снизу при авторазмере
        g.OnEvent("Close", (*) => g.Hide())     ; «X» прячет окно, не уничтожает (переоткрытие)
        this._gui := g

        y := margin
        for row in this.ROWS {
            x := margin
            for w3cName in row {
                g.SetFont("s" fontSize, this._font)
                btn := g.AddButton("x" x " y" y " w" wbtn " h" hbtn, this.ButtonText(w3cName))
                btn.OnEvent("Click", ObjBindMethod(this, "OnKeyClick", w3cName))   ; см. память: ObjBindMethod
                this._buttons[w3cName] := btn
                x += wbtn + spacing
            }
            y += hbtn + spacing
        }

        textWidth := wbtn * 12 + 11 * spacing
        y += margin - spacing                       ; зазор между сеткой клавиш и подсказкой = поле окна
        g.SetFont("s" Floor(fontSize * 0.732), this._font)
        ; подсказка построчно: шаг = реальная высота строки + зазор (переживает переносы).
        ; строка со ссылкой <a> рисуется Link-контролом (где бы ни стояла), остальные — Text.
        gap := -1
        for line in Txt.EditorHintLines {
            if InStr(line, "<a ") {
                ctrl := g.AddLink("x" margin " y" y " w" textWidth, line)
                ctrl.OnEvent("Click", (*) => Run(this.DONATE_URL))   ; «даст ¢» -> бусти
            } else {
                ctrl := g.AddText("x" margin " y" y " w" textWidth, line)
            }
            ctrl.GetPos( , , , &ch)
            if (gap < 0)
                gap := Round(ch * (this.LINE_SPACING - 1))   ; аккуратный зазор от высоты одиночной строки
            y += ch + gap
        }
    }

    ; -------------------------------------------------------------------------
    ;  Окно правки одной клавиши
    ; -------------------------------------------------------------------------
    static CloseEdit() {
        if (this._editGui) {
            try this._editGui.Destroy()
            this._editGui := ""
        }
    }

    static OnKeyClick(w3cName, *) {
        this.CloseEdit()                            ; одно окно правки за раз — закрыть прежнее
        scale := A_ScreenDPI / 96
        logW := A_ScreenWidth / scale
        wfld := Round(logW * 0.2)
        hfld := Round(wfld * 0.25)
        k := Config.GetKey(w3cName)

        eg := Gui("+AlwaysOnTop +Owner" this._gui.Hwnd, Txt.EditTitlePrefix this.DISPLAY[w3cName] Txt.EditTitleSuffix)
        this._editGui := eg
        eg.BackColor := "FFFFFF"
        eg.OnEvent("Close", (*) => this.CloseEdit())

        eg.SetFont("s12", this._font)
        eg.AddText(, Txt.EditAltShift)
        eg.SetFont("s32", this._font)
        shiftEdit := eg.AddEdit("w" wfld " h" hfld, k.altShift)

        eg.SetFont("s12", this._font)
        eg.AddText(, Txt.EditAlt)
        eg.SetFont("s32", this._font)
        altEdit := eg.AddEdit("w" wfld " h" hfld, k.alt)

        eg.SetFont("s14", this._font)
        hsave := Round(hfld * 0.8)            ; высота кнопки пропорционально полю (DPI-friendly)
        saveBtn := eg.AddButton("w" wfld " h" hsave, Txt.EditSave)
        saveBtn.OnEvent("Click", (*) => this.OnSave(w3cName, eg, altEdit.Value, shiftEdit.Value))

        eg.Show()
    }

    static OnSave(w3cName, eg, altRaw, shiftRaw) {
        alt := this.Sanitize(altRaw)
        shift := this.Sanitize(shiftRaw)
        if (this.CpCount(alt) > 32 || this.CpCount(shift) > 32) {
            MsgBox(Txt.TooLongBody, Txt.TooLongTitle, "Icon!")
            return
        }
        Config.SetKey(w3cName, alt, shift)                 ; пустое поле = «не задано», честно
        this._buttons[w3cName].Text := this.ButtonText(w3cName)
        this.CloseEdit()
    }

    ; -------------------------------------------------------------------------
    ;  Подписи и помощники (чистые)
    ; -------------------------------------------------------------------------
    static ButtonText(w3cName) {
        k := Config.GetKey(w3cName)
        return this.DISPLAY[w3cName] "`n" this.ButtonRepr(k.altShift) "`n" this.ButtonRepr(k.alt)
    }

    ; До ~3 кодпоинтов; длиннее — первые 3 + «…» (полное видно в окне правки).
    static ButtonRepr(value) {
        if (value = "")
            return ""
        cps := this.CpList(value)
        out := ""
        Loop Min(cps.Length, 3)
            out .= this.RenderCp(cps[A_Index])
        if (cps.Length > 3)
            out .= "…"
        return out
    }

    static RenderCp(cp) {
        if (cp >= 0x0300 && cp <= 0x036F)
            return Chr(0x25CC) Chr(cp)        ; ◌ + комбинирующая (видимость)
        if (cp = 0x20)
            return Chr(0x2423)                ; ␣
        if (cp = 0xA0)
            return Chr(0x237D)                ; ⍽
        return Chr(cp)
    }

    static Sanitize(s) {
        return RegExReplace(s, "[\r\n]", "")  ; убрать переводы строк; остальное разрешено
    }

    ; перечень кодпоинтов (суррогатные пары = 1 кодпоинт)
    static CpList(s) {
        out := []
        i := 1, len := StrLen(s)
        while (i <= len) {
            cp := Ord(SubStr(s, i, 2))
            out.Push(cp)
            i += (cp > 0xFFFF) ? 2 : 1
        }
        return out
    }
    static CpCount(s) {
        return this.CpList(s).Length
    }
}
