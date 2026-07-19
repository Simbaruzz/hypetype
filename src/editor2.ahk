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
    static _editGui := ""           ; попап правки (один за раз)
    static _hints := []             ; Text-контролы подсказки (переключаются ⓘ)
    static _byHwnd := Map()         ; hwnd слоя -> w3cName (для ховера)
    static _hover := ""             ; подсвеченный кейкап ("" = нет)
    static _handHwnds := Map()      ; hwnd кликабельного контрола -> true (курсор-«рука»)
    static _handCur := 0            ; хэндл IDC_HAND
    static _arrowCur := 0           ; хэндл IDC_ARROW
    static _hintsOn := false        ; подсказка (и лого) видимы
    static _logo := ""              ; Picture лого в хинт-зоне ("" = png не найден)
    static _lion := ""              ; Picture лев (показывается при ховере)
    static _logoHover := false
    static LOGO_URL := "https://simbarus.com/hypetype"
    static DONATE_URL := "https://boosty.to/simbarus/donate"   ; ссылка «даст ¢» (как в editor.ahk)
    static _winW := 0               ; клиентская ширина окна (для ресайза по ⓘ)
    static _baseH := 0              ; высота без подсказки
    static _fullH := 0              ; высота с подсказкой

    ; строки спайка (в общий strings.ahk не лезем до вердикта)
    static STR_CANCEL := "отмена"
    static STR_SAVE := "сохранить"  ; строчными, как на маке (Txt.EditSave — с заглавной)
    static STR_PASTE := "вставьте нужные символы из буфера обмена Ctrl+V"
    static _shade := ""             ; вуаль-затемнение под попапом

    ; --- палитра (тона по скриншотам мака, _preview/) ---
    static COL_BG   := "121212"     ; фон окна
    static COL_KEY  := "262626"     ; кликабельная клавиша (чуть светлее декора — как на маке)
    static COL_DECOR := "1A1A1A"    ; декор-клавиша (некликабельная, темнее)
    static COL_KEY_HOVER := "343434" ; тело клавиши под мышью
    static COL_HYPE := "F2F2F2"     ; подсвеченная хайп-клавиша (правый Alt)
    static COL_MAIN := "FFFFFF"     ; основной символ (с Alt)
    static COL_SHIFT := "B873FF"    ; Shift-символ (фиолетовый акцент; серый вариант — на скрине gray-shift)
    static COL_BASE := "757575"     ; буква клавиши и декор-глифы
    static COL_HINT := "8C8C8C"     ; текст подсказки внизу
    static FONT := "Segoe UI"       ; системный; глифы добирает фонт-линкинг GDI
    static FONT_GLYPH := "Segoe UI Symbol"  ; слои символов кейкапов: есть ␣ и другие
                                    ; глифы, которых нет в Segoe UI (UI-SPIKE §3.3)

    ; невидимые пробельные символы -> прямоугольник примерно их ширины
    ; (механика мака: узкий/волосяной пробел видно прямо на клавише);
    ; обычный пробел (␣) и nbsp (⍽) остаются глифами из Config.RenderCp
    static SPACE_BLOCK := Map(
        0x200A, Chr(0x258F),                                          ; hair space
        0x2006, Chr(0x258E),                                          ; six-per-em
        0x2009, Chr(0x258D), 0x202F, Chr(0x258D), 0x205F, Chr(0x258D), ; thin, narrow nbsp, medium math
        0x2005, Chr(0x258C), 0x2008, Chr(0x258C),                     ; four-per-em, punctuation
        0x2004, Chr(0x258B),                                          ; three-per-em
        0x2000, Chr(0x258A), 0x2002, Chr(0x258A), 0x2007, Chr(0x258A), ; en quad/space, figure
        0x2001, Chr(0x2588), 0x2003, Chr(0x2588), 0x3000, Chr(0x2588)) ; em quad/space, ideographic

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
        g.OnEvent("Close", (*) => ExitApp())    ; крестик закрывает приложение из любого состояния
        g.OnEvent("Escape", (*) => (TypoWin._openFlag && TypoWin.Close()))  ; Esc в настройках -> клавиатура
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
        x := this.AddDecor(g, x, y, wshift, "SHIFT", "BL", this.COL_SHIFT)
        for name in this.ROW4
            x := this.AddKeycap(g, x, y, U, name)
        this.AddDecor(g, x, y, contentW + this.MARGIN - x, "SHIFT", "BR", this.COL_SHIFT)

        ; --- ряд 5: ⓘ ctrl win alt SPACE alt(хайп) win ctrl стрелки ---
        x := this.MARGIN, y += KH + GAP
        arrowsW := 3 * U + 2 * GAP
        spaceW := contentW - 7 * U - arrowsW - 10 * GAP
        ; ⓘ кликабельна: светлее, с ховером, прижата вниз-влево (как на маке)
        x := this.AddDecor(g, x, y, U, Chr(0x24D8), "BL", "", ObjBindMethod(this, "ToggleHints"), this.COL_KEY, "__info")
        for label in ["ctrl", "win", "alt"]                       ; левые — вниз и влево
            x := this.AddDecor(g, x, y, U, label, "BL")
        x := this.AddKeycap(g, x, y, spaceW, "Space")
        x := this.AddHypeKey(g, x, y, U)
        for label in ["win", "ctrl"]                              ; правые — вниз и вправо
            x := this.AddDecor(g, x, y, U, label, "BR")
        this.AddArrows(g, x, y)

        ; --- подсказка под клавиатурой (по ⓘ окно расширяется и она появляется) ---
        y += KH + this.MARGIN
        g.SetFont("s9", this.FONT)
        hintH := 0
        for line in Txt.EditorHintLines {
            ch := 0
            if RegExMatch(line, "^(.*?)<a[^>]*>(.*?)</a>(.*)$", &m) {
                ; строка со ссылкой: обычный текст + фиолетовая «даст ¢» -> бусти
                ctrl := g.AddText(Format("x{} y{} Hidden c{}", this.MARGIN, y + hintH, this.COL_HINT), m[1])
                this._hints.Push(ctrl)
                ctrl.GetPos(&tx, , &tw, &ch)
                g.SetFont("s9 underline", this.FONT)
                link := g.AddText(Format("x{} y{} Hidden c{}", tx + tw + 4, y + hintH, this.COL_SHIFT), m[2])
                g.SetFont("s9 norm", this.FONT)
                link.OnEvent("Click", (*) => Run(this.DONATE_URL))
                this.MakeHand([link])
                this._hints.Push(link)
            } else {
                ctrl := g.AddText(Format("x{} y{} w{} Hidden c{}", this.MARGIN, y + hintH, contentW - 64, this.COL_HINT), line)
                this._hints.Push(ctrl)
                ctrl.GetPos(, , , &ch)
            }
            hintH += ch + 4
        }

        ; лого справа от подсказки: logo.png, при ховере lion.png, клик -> сайт.
        ; PNG кладутся в assets\ (SVG натив не умеет); нет файлов — нет лого.
        logoPath := A_ScriptDir "\..\assets\logo.png"
        lionPath := A_ScriptDir "\..\assets\lion.png"
        if FileExist(logoPath) {
            lw := 48
            lx := this.MARGIN + contentW - lw
            ly := y + Max(0, (hintH - lw) // 2)
            this._logo := g.AddPicture(Format("x{} y{} w{} h{} Hidden", lx, ly, lw, lw), logoPath)
            this._lion := g.AddPicture(Format("x{} y{} w{} h{} Hidden", lx, ly, lw, lw),
                FileExist(lionPath) ? lionPath : logoPath)
            for ctrl in [this._logo, this._lion]
                ctrl.OnEvent("Click", (*) => Run(this.LOGO_URL))
            this.MakeHand([this._logo, this._lion])
        }

        ; окно компактное; по ⓘ подрастает на высоту подсказки
        this._winW := contentW + 2 * this.MARGIN
        this._baseH := 5 * KH + 4 * GAP + 2 * this.MARGIN
        this._fullH := this._baseH + this.MARGIN + hintH
        OnMessage(0x200, ObjBindMethod(this, "OnMouseMove"))      ; WM_MOUSEMOVE -> ховер
        ; курсор-«рука» над кликабельным: Static сам курсор не задаёт, поэтому
        ; перехватываем WM_SETCURSOR и ставим IDC_HAND вместо стрелки
        this._handCur := DllCall("LoadCursor", "ptr", 0, "ptr", 32649, "ptr")   ; IDC_HAND
        this._arrowCur := DllCall("LoadCursor", "ptr", 0, "ptr", 32512, "ptr")  ; IDC_ARROW
        OnMessage(0x20, ObjBindMethod(this, "OnSetCursor"))       ; WM_SETCURSOR
        g.Show(Format("w{} h{} Hide", this._winW, this._baseH))
    }

    ; ⓘ: показать/спрятать подсказку (и лого); окно растёт/сжимается
    static ToggleHints(*) {
        this._hintsOn := !this._hintsOn
        this._gui.Show(Format("w{} h{}", this._winW, this._hintsOn ? this._fullH : this._baseH))
        this.SyncHints()
    }

    ; привести контролы подсказки/лого к состоянию _hintsOn
    ; (используется и при возврате из режима настроек типографа)
    static SyncHints() {
        for ctrl in this._hints
            ctrl.Visible := this._hintsOn
        if IsObject(this._logo) {
            this._logoHover := false
            this._logo.Visible := this._hintsOn
            this._lion.Visible := false
        }
    }

    ; -------------------------------------------------------------------------
    ;  Конструкторы клавиш. Каждая возвращает x следующей клавиши.
    ; -------------------------------------------------------------------------

    ; тело клавиши — Text с тёмным фоном (кнопки не умеют цвет, UI-SPIKE §3.2).
    ; Скругления убраны решением владельца («виндовый стилёк» устраивает).
    static AddBody(g, x, y, w, h := -1, bg := "") {
        h := (h = -1) ? this.KH : h
        bg := (bg = "") ? this.COL_KEY : bg
        return g.AddText(Format("x{} y{} w{} h{} Background{}", x, y, w, h, bg))
    }

    ; mappable-кейкап: тело + 3 слоя подписей — Alt+Shift (верх, акцент),
    ; буква (низ-лево, приглушена), Alt-символ (низ-право, белый).
    ; Клик по любому слою открывает попап правки (вопрос эксперимента №3).
    static AddKeycap(g, x, y, w, name) {
        body := this.AddBody(g, x, y, w)
        k := Config.GetKey(name)
        g.SetFont("s8", this.FONT_GLYPH)
        shiftCtrl := g.AddText(Format("x{} y{} w{} h14 Right Background{} c{}",
            x + 6, y + 5, w - 12, this.COL_KEY, this.COL_SHIFT), this.KeyRepr(k.altShift))
        baseW := (name = "Space") ? 60 : 18
        g.SetFont("s9", this.FONT)
        baseCtrl := g.AddText(Format("x{} y{} w{} h16 Background{} c{}",
            x + 6, y + this.KH - 21, baseW, this.COL_KEY, this.COL_BASE), this.DISPLAY[name])
        g.SetFont("s12", this.FONT_GLYPH)
        ; h23: у ␣ перекладина на базовой линии — при h20 её срезало (виднелись «..»)
        altCtrl := g.AddText(Format("x{} y{} w{} h23 Right Background{} c{}",
            x + 6 + baseW, y + this.KH - 28, w - baseW - 12, this.COL_KEY, this.COL_MAIN), this.KeyRepr(k.alt))
        layers := [body, shiftCtrl, baseCtrl, altCtrl]
        this._caps[name] := {alt: altCtrl, shift: shiftCtrl, layers: layers}
        cb := ObjBindMethod(this, "OnKeyClick", name)
        for ctrl in layers {
            ctrl.OnEvent("Click", cb)
            this._byHwnd[ctrl.Hwnd] := name
        }
        this.MakeHand(layers)
        return x + w + this.GAP
    }

    ; -------------------------------------------------------------------------
    ;  Ховер (UI-SPIKE §3.2, опционально): подсветка кейкапа под мышью.
    ;  Если замерцает/подтормозит — выбросить, не упираться.
    ; -------------------------------------------------------------------------
    ; WM_SETCURSOR: контрол под мышью определяем сами (wParam может быть
    ; top-level окном). Кликабельный -> «рука»; прочие Static -> явная стрелка
    ; (иначе рука «залипает»); Edit и др. не трогаем — у них свой курсор.
    static OnSetCursor(wParam, lParam, msg, hwnd) {
        MouseGetPos , , , &ctl, 2                   ; hwnd контрола под курсором
        if this._handHwnds.Has(ctl) {
            DllCall("SetCursor", "ptr", this._handCur)
            return 1                                ; обработано — системную стрелку не ставить
        }
        try cls := WinGetClass("ahk_id " ctl)
        catch
            return
        if (cls = "Static") {
            DllCall("SetCursor", "ptr", this._arrowCur)
            return 1
        }
    }

    static MakeHand(ctrls) {
        for c in ctrls
            this._handHwnds[c.Hwnd] := true
    }

    static OnMouseMove(wParam, lParam, msg, hwnd) {
        ; лого <-> лев при ховере
        if (this._hintsOn && IsObject(this._logo)) {
            overLogo := (hwnd = this._logo.Hwnd || hwnd = this._lion.Hwnd)
            if (overLogo != this._logoHover) {
                this._logoHover := overLogo
                this._logo.Visible := !overLogo
                this._lion.Visible := overLogo
            }
        }
        name := this._byHwnd.Has(hwnd) ? this._byHwnd[hwnd] : ""
        if (name = this._hover)
            return
        if (this._hover != "")
            this.PaintKey(this._hover, this.COL_KEY)
        this._hover := name
        if (name != "")
            this.PaintKey(name, this.COL_KEY_HOVER)
    }

    static PaintKey(name, col) {
        for ctrl in this._caps[name].layers {
            ctrl.Opt("Background" col)
            ctrl.Redraw()
        }
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
            out .= this.SPACE_BLOCK.Has(cp) ? this.SPACE_BLOCK[cp] : Config.RenderCp(cp)
            shown++
        }
        if (i <= len)
            out .= "…"
        return out
    }

    ; декор-клавиша: тело + один приглушённый глиф; align: BL/BR/B (низ) / C (центр);
    ; clickFn и bg — для «почти декора» вроде ⓘ (кликабельный -> светлее);
    ; hoverKey — включить ховер-подсветку (регистрирует слои как псевдо-кейкап)
    static AddDecor(g, x, y, w, glyph, align := "C", color := "", clickFn := "", bg := "", hoverKey := "") {
        color := (color = "") ? this.COL_BASE : color
        bg := (bg = "") ? this.COL_DECOR : bg
        body := this.AddBody(g, x, y, w, -1, bg)
        g.SetFont("s9", this.FONT)
        switch align {
            case "BL": opt := Format("x{} y{} w{}", x + 8, y + this.KH - 20, w - 16)
            case "BR": opt := Format("x{} y{} w{} Right", x + 8, y + this.KH - 20, w - 16)
            case "B":  opt := Format("x{} y{} w{} Center", x + 2, y + this.KH - 20, w - 4)
            default:   opt := Format("x{} y{} w{} Center", x + 2, y + this.KH // 2 - 7, w - 4)
        }
        label := g.AddText(opt " Background" bg " c" color, glyph)
        if (clickFn != "") {
            body.OnEvent("Click", clickFn)
            label.OnEvent("Click", clickFn)
            this.MakeHand([body, label])
        }
        if (hoverKey != "") {
            this._caps[hoverKey] := {layers: [body, label]}
            this._byHwnd[body.Hwnd] := hoverKey
            this._byHwnd[label.Hwnd] := hoverKey
        }
        return x + w + this.GAP
    }

    ; широкая клавиша ТИПОГРАФ на месте Backspace; кликабельна (светлая);
    ; подпись и ⌫ по правому краю — как SHIFT/Enter (фидбек владельца)
    static AddTypoKey(g, x, y, w) {
        body := this.AddBody(g, x, y, w)
        g.SetFont("s8", this.FONT)
        cap := g.AddText(Format("x{} y{} w{} Right Background{} c{}", x + 8, y + 8, w - 16, this.COL_KEY, this.COL_MAIN),
            "ТИПОГРАФ")
        g.SetFont("s10", this.FONT)
        glyph := g.AddText(Format("x{} y{} w{} Right Background{} c{}", x + 8, y + this.KH - 24, w - 16, this.COL_KEY, this.COL_BASE),
            Chr(0x232B))                                          ; ⌫
        cb := ObjBindMethod(this, "ShowTypoStub")
        for ctrl in [body, cap, glyph]
            ctrl.OnEvent("Click", cb)
        this.MakeHand([body, cap, glyph])
        return x + w + this.GAP
    }

    ; клик по ТИПОГРАФ — окно настроек типографа (typograph2.ahk, Стадия 2)
    static ShowTypoStub(*) {
        TypoWin.Open(this._gui)
    }

    ; подсвеченная хайп-клавиша (правый Alt) — светлое тело, тёмная подпись вниз-вправо
    static AddHypeKey(g, x, y, w) {
        this.AddBody(g, x, y, w, -1, this.COL_HYPE)
        g.SetFont("s9", this.FONT)
        g.AddText(Format("x{} y{} w{} Right Background{} c1A1A1A", x + 8, y + this.KH - 20, w - 16, this.COL_HYPE),
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
            this.AddBody(g, pair[1], pair[2], this.U, hh, this.COL_DECOR)
            g.AddText(Format("x{} y{} w{} Center Background{} c{}", pair[1] + 2, pair[2] + hh // 2 - 6, this.U - 4, this.COL_DECOR, this.COL_BASE),
                pair[3])
        }
        return x + 3 * this.U + 2 * this.GAP + this.GAP
    }

    ; -------------------------------------------------------------------------
    ;  Попап правки клавиши (UI-SPIKE §3.5): тёмное окно, модальность через
    ;  Disable владельца. Сохранение — валидация как в editor.ahk -> Config.SetKey.
    ; -------------------------------------------------------------------------

    static OnKeyClick(name, *) {
        this.CloseEdit()
        k := Config.GetKey(name)
        letter := this.DISPLAY[name]
        ; -SysMenu: без крестика и иконки (фидбек: крестик неряшлив, на маке его нет)
        eg := Gui("+Owner" this._gui.Hwnd " -SysMenu",
            Txt.EditTitlePrefix letter Txt.EditTitleSuffix)
        this._editGui := eg
        eg.BackColor := this.COL_BG
        this.ApplyDarkTitle(eg)
        this.ApplyRoundWindow(eg)

        ; левая колонка: подсказка про буфер (композиция мака)
        eg.SetFont("s9", this.FONT)
        eg.AddText("x24 y20 w160 c" this.COL_HINT, this.STR_PASTE)

        ; правая колонка: подписи сочетаний + тёмные поля (вопрос эксперимента №4 — да)
        eg.AddText("x216 y20 w320 c" this.COL_HINT, "Alt + Shift + " letter)
        eg.SetFont("s20", this.FONT)
        shiftEdit := eg.AddEdit(Format("x216 y40 w320 Background{} c{}", this.COL_KEY, this.COL_MAIN), k.altShift)
        eg.SetFont("s9", this.FONT)
        eg.AddText("x216 y104 w320 c" this.COL_HINT, "Alt + " letter)
        eg.SetFont("s20", this.FONT)
        altEdit := eg.AddEdit(Format("x216 y124 w320 Background{} c{}", this.COL_KEY, this.COL_MAIN), k.alt)

        ; большая приглушённая буква: низ — по нижнему краю нижнего поля
        eg.SetFont((StrLen(letter) > 1 ? "s22" : "s56"), this.FONT)
        letterCtrl := eg.AddText("x24 y104 w160 c4A4A4A", letter)
        altEdit.GetPos(, &fy, , &fh)
        letterCtrl.GetPos(, , , &lh)
        letterCtrl.Move(, fy + fh - lh)

        ; кнопки в стиле мака: тёмная «отмена» слева, синяя «сохранить» справа
        eg.SetFont("s10", this.FONT)
        this.AddFlatButton(eg, 24, 204, 110, 34, this.STR_CANCEL, "2E2E2E", this.COL_MAIN,
            (*) => this.CloseEdit())
        this.AddFlatButton(eg, 426, 204, 110, 34, this.STR_SAVE, "0A7CFF", "FFFFFF",
            (*) => this.OnSave(name, altEdit, shiftEdit))
        ; Enter = сохранить: нулевая Default-кнопка (невидимый нативный дефолт)
        defBtn := eg.AddButton("x0 y0 w0 h0 Default", "")
        defBtn.OnEvent("Click", (*) => this.OnSave(name, altEdit, shiftEdit))
        eg.OnEvent("Close", (*) => this.CloseEdit())
        eg.OnEvent("Escape", (*) => this.CloseEdit())

        this.ShowShade()                        ; лёгкое затемнение клавиатуры (как на маке)
        this._gui.Opt("+Disabled")              ; модальность: владелец выключен
        eg.Show("w560 h258")
    }

    ; плоская кнопка из Text-контролов (нативные не красятся): тело + подпись
    static AddFlatButton(g, x, y, w, h, text, bg, fg, clickFn) {
        body := g.AddText(Format("x{} y{} w{} h{} Background{}", x, y, w, h, bg))
        label := g.AddText(Format("x{} y{} w{} Center Background{} c{}", x, y + (h - 18) // 2, w, bg, fg), text)
        body.OnEvent("Click", clickFn)
        label.OnEvent("Click", clickFn)
        this.MakeHand([body, label])
    }

    ; полупрозрачная чёрная вуаль поверх окна редактора на время попапа.
    ; E0x20 (WS_EX_TRANSPARENT) — клики проходят сквозь вуаль к disabled-окну
    ; (стандартный «дынь» + мигание попапа), иначе клик поднимал вуаль над
    ; попапом и всё выглядело зависшим.
    static ShowShade() {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " this._gui.Hwnd)   ; физические координаты
        sh := Gui("-Caption -DPIScale +Owner" this._gui.Hwnd " +E0x08000020")  ; NOACTIVATE | TRANSPARENT
        sh.BackColor := "000000"
        sh.Show(Format("NA x{} y{} w{} h{}", wx, wy, ww, wh))
        WinSetTransparent(100, sh)
        this._shade := sh
    }

    static CloseEdit() {
        if !this._editGui
            return
        this._gui.Opt("-Disabled")              ; вернуть владельца ДО Destroy (иначе фокус уйдёт)
        try this._editGui.Destroy()
        this._editGui := ""
        if IsObject(this._shade) {
            try this._shade.Destroy()
            this._shade := ""
        }
    }

    static OnSave(name, altEdit, shiftEdit) {
        alt := RegExReplace(altEdit.Value, "[\r\n]", "")      ; валидация как в editor.ahk
        shift := RegExReplace(shiftEdit.Value, "[\r\n]", "")
        if (this.CpCount(alt) > 32 || this.CpCount(shift) > 32) {
            MsgBox(Txt.TooLongBody, Txt.TooLongTitle, "Icon!")
            return
        }
        Config.SetKey(name, alt, shift)
        this._caps[name].alt.Text := this.KeyRepr(alt)
        this._caps[name].shift.Text := this.KeyRepr(shift)
        this.CloseEdit()
    }

    ; кодпоинты, суррогатная пара = 1 (как editor.ahk)
    static CpCount(s) {
        n := 0, i := 1, len := StrLen(s)
        while (i <= len) {
            cp := Ord(SubStr(s, i, 2))
            i += (cp > 0xFFFF) ? 2 : 1
            n++
        }
        return n
    }

    ; скруглить само окно (Win11): DWMWA_WINDOW_CORNER_PREFERENCE=33 -> DWMWCP_ROUND=2
    static ApplyRoundWindow(g) {
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 33, "int*", 2, "int", 4, "int")
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
