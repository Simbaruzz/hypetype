#Requires AutoHotkey v2.0

; =============================================================================
;  typograph2.ahk — спайк окна настроек типографа (UI-SPIKE.md, Стадия 2).
;  Порт TypographSettingsView.swift: сайдбар (Основные / О типографе), таблица
;  правил с примерами «до -> после», тумблеры/выпадашки, закрыть/сохранить.
;  Ключи [Typograph] — новые раздельные (TypographFormat.swift); данные только
;  через Config. Скролла нет: все 18 правил помещаются (решение владельца).
;  Требует editor2.ahk (палитра, AddFlatButton, механика руки-курсора).
; =============================================================================

class TypoWin {
    static _gui := ""
    static _toggles := Map()        ; key -> {body, knob, on, x, y}
    static _drops := Map()          ; key -> {ctrl, value, options}
    static _mainCtrls := []         ; контролы вкладки «Основные»
    static _aboutCtrls := []        ; контролы вкладки «О типографе»
    static _sideItems := Map()      ; tab -> {body, label}
    static _tab := "main"
    static _owner := ""

    ; --- палитра поверх Editor2 (тона из TypographSettingsView.swift) ---
    static COL_CARD := "1C1C1C"     ; карточка таблицы (white 0.11)
    static COL_LINE := "2E2E2E"     ; разделители строк
    static COL_SECT := "383838"     ; разделители секций (чуть ярче)
    static COL_OFF  := "3A3A3A"     ; трек выключенного тумблера
    static COL_DROP := "333333"     ; фон выпадашки
    static COL_SEL  := "0A7CFF"     ; выбранный пункт сайдбара (accentColor)

    static TG_URL := "https://t.me/simbarus"
    static TYPOGRAF_URL := "https://github.com/typograf/typograf"

    ; --- модель правил (TypographSettingsView.swift, NB = ⍽) ---
    ; kind: t = тумблер, percent/side = выпадашки
    static Rules() {
        NB := Chr(0x237D)
        return [
            {title: "Ёфикатор", rows: [
                {t: "Заменять е → ё", b: "пришел", a: "пришёл", kind: "t", key: "Yo"}]},
            {title: "Неразрывные пробелы", rows: [
                {t: "Число + слово", b: "5 лет", a: "5" NB "лет", kind: "t", key: "NbspNumberWord"},
                {t: "Инициалы", b: "А.А. Иванов", a: "А.А." NB "Иванов", kind: "t", key: "NbspInitials"},
                {t: "Частицы", b: "нужно ли", a: "нужно" NB "ли", kind: "t", key: "NbspParticles"},
                {t: "Предлоги / союзы", b: "в лесу", a: "в" NB "лесу", kind: "t", key: "NbspShortWords"}]},
            {title: "Тире", rows: [
                {t: "Дефис в тексте", b: "дизайн - огонь", a: "дизайн — огонь", kind: "t", key: "DashText"},
                {t: "Прямая речь", b: "- Это я", a: "— Это я", kind: "t", key: "DashSpeech"},
                {t: "Диапазоны", b: "2002-2009", a: "2002–2009", kind: "t", key: "DashRanges"}]},
            {title: "Пунктуация", rows: [
                {t: "Многоточие", b: "точки...", a: "точки…", kind: "t", key: "PunctEllipsis"},
                {t: "Повторы", b: "что!!!", a: "что!", kind: "t", key: "PunctCollapse"},
                {t: "Порядок !?", b: "как!?", a: "как?!", kind: "t", key: "PunctOrder"}]},
            {title: "Пробелы", rows: [
                {t: "Вокруг пунктуации", b: "синий ,розовый", a: "синий, розовый", kind: "t", key: "SpaceClean"},
                {t: "Знак %", b: "23 %", a: "23%", kind: "percent", key: "PercentSpace"}]},
            {title: "Кавычки", rows: [
                {t: "Прямые → ёлочки", b: "`"привет`"", a: "«привет»", kind: "t", key: "Quotes"}]},
            {title: "Числа", rows: [
                {t: "Валюта → знак", b: "5 руб", a: "5" NB "₽", kind: "t", key: "CurrencySymbol"},
                {t: "Сторона валюты", b: "₽ 300", a: "300" NB "₽", kind: "side", key: "CurrencyPosition"},
                {t: "Разряды", b: "2345123 ₽", a: "2" NB "345" NB "123" NB "₽", kind: "t", key: "CurrencyGrouping"},
                {t: "Копейки в сумму", b: "45 руб. 5 коп.", a: "45,05" NB "₽", kind: "t", key: "CurrencyKopecks"}]},
            {title: "Символы", rows: [
                {t: "Спецсимволы", b: "(c) +-", a: "© ±", kind: "t", key: "Symbols"}]},
        ]
    }

    ; варианты выпадашек: [значение, подпись]
    static PERCENT_OPTS := [["none", "без пробела"], ["narrow", "узкий"], ["regular", "с пробелом"]]
    static SIDE_OPTS := [["after", "справа"], ["before", "слева"]]

    ; дефолты (TypographSettings.default: всё включено; Yo по-виндовому выключен)
    static DefaultFor(key) {
        switch key {
            case "Yo": return "0"
            case "PercentSpace": return "none"
            case "CurrencyPosition": return "after"
            default: return "1"
        }
    }

    ; -------------------------------------------------------------------------
    ;  Одно «визуальное» окно, два состояния (как на маке): при открытии
    ;  настроек окно клавиатуры прячется, настройки встают на его место;
    ;  «закрыть»/«сохранить»/Esc возвращают клавиатуру.
    ; -------------------------------------------------------------------------
    static Open(owner) {
        this.Close()                             ; одно окно за раз, всегда свежие данные
        this._owner := owner
        this.Build()
        WinGetPos(&wx, &wy, , , "ahk_id " owner.Hwnd)     ; физические координаты
        dhw := A_DetectHiddenWindows
        DetectHiddenWindows true                          ; окно настроек ещё скрыто
        WinMove(wx, wy, , , "ahk_id " this._gui.Hwnd)     ; на место клавиатуры
        DetectHiddenWindows dhw
        owner.Hide()
        this._gui.Show()
    }

    static Close() {
        if !this._gui
            return
        try this._gui.Destroy()
        this._gui := ""
        this._toggles := Map(), this._drops := Map()
        this._mainCtrls := [], this._aboutCtrls := [], this._sideItems := Map()
        this._tab := "main"
        if IsObject(this._owner)
            this._owner.Show()                   ; вернуть клавиатуру на том же месте
    }

    static Build() {
        E := Editor2                             ; палитра и помощники спайка
        ; без +Owner: владелец прячется, а owned-окно не даёт кнопку в таскбаре
        g := Gui("-Resize", Txt.MainTitle)
        g.BackColor := E.COL_BG
        E.ApplyDarkTitle(g)
        this._gui := g

        M := 20                                  ; поле окна
        sideW := 150, rightW := 96, gapX := 16
        winW := 922                              ; как окно клавиатуры
        cardX := M + sideW + gapX
        cardW := winW - 2 * M - sideW - rightW - 2 * gapX
        cardY := M

        ; --- центральная карточка: фон + таблица правил ---
        rules := this.Rules()
        rowH := 28, padX := 14, padY := 8
        rowsH := 0
        for sect in rules
            rowsH += sect.rows.Length * rowH
        sectCount := rules.Length
        cardH := 2 * padY + rowsH + (sectCount - 1) * 1   ; строки + межсекционные линии
        card := g.AddText(Format("x{} y{} w{} h{} Background{}", cardX, cardY, cardW, cardH, this.COL_CARD))

        ; колонки строк (по мак-вёрстке): ярлык 96, название 140, до 104, после 104
        xLabel := cardX + padX
        xTitle := xLabel + 96 + 10
        xBefore := xTitle + 132 + 10
        xAfter := xBefore + 104 + 10
        xCtl := cardX + cardW - padX - 34        ; тумблеры (34px)
        xDrop := cardX + cardW - padX - 96       ; выпадашки (96px)

        y := cardY + padY
        for si, sect in rules {
            g.SetFont("s9 w500", E.FONT)
            lbl := g.AddText(Format("x{} y{} w96 Background{} cD9D9D9", xLabel, y + 6, this.COL_CARD), sect.title)
            this._mainCtrls.Push(lbl)
            for ri, row in sect.rows {
                g.SetFont("s9", E.FONT)
                this._mainCtrls.Push(g.AddText(Format("x{} y{} w132 Background{} cCCCCCC", xTitle, y + 6, this.COL_CARD), row.t))
                this._mainCtrls.Push(g.AddText(Format("x{} y{} w104 Background{} c6E6E6E", xBefore, y + 6, this.COL_CARD), row.b))
                this._mainCtrls.Push(g.AddText(Format("x{} y{} w104 Background{} c9E9E9E", xAfter, y + 6, this.COL_CARD), row.a))
                val := Config.GetTypographSetting(row.key, this.DefaultFor(row.key))
                switch row.kind {
                    case "t":       this.AddToggle(g, xCtl, y + 5, row.key, val = "1")
                    case "percent": this.AddDrop(g, xDrop, y + 4, row.key, this.PERCENT_OPTS, val)
                    case "side":    this.AddDrop(g, xDrop, y + 4, row.key, this.SIDE_OPTS, val)
                }
                y += rowH
                if (ri < sect.rows.Length) {     ; тонкая линия между строками секции
                    ln := g.AddText(Format("x{} y{} w{} h1 Background{}", xTitle, y - 1, cardX + cardW - padX - xTitle, this.COL_LINE))
                    this._mainCtrls.Push(ln)
                }
            }
            if (si < rules.Length) {             ; линия между секциями — на всю карточку
                ln := g.AddText(Format("x{} y{} w{} h1 Background{}", cardX + 1, y, cardW - 2, this.COL_SECT))
                this._mainCtrls.Push(ln)
                y += 1
            }
        }
        this._mainCtrls.Push(card)

        winH := cardY + cardH + M

        ; --- вкладка «О типографе» (создаётся скрытой, та же геометрия карточки) ---
        this.BuildAbout(g, cardX, cardY, cardW, cardH)

        ; --- сайдбар ---
        this.AddSideItem(g, M, cardY, sideW, "Основные", "main")
        this.AddSideItem(g, M, cardY + 36, sideW, "О типографе", "about")
        g.SetFont("s8", E.FONT)
        foot1 := g.AddText(Format("x{} y{} w{} c8A8A8A Background{}", M, winH - M - 34, sideW, E.COL_BG),
            "Нужны допнастройки или нашли баг — пишите")
        g.SetFont("s8 underline", E.FONT)
        foot2 := g.AddText(Format("x{} y{} c{} Background{}", M, winH - M - 6 - 1, E.COL_SHIFT, E.COL_BG), "@simbarus")
        g.SetFont("s8 norm", E.FONT)
        for c in [foot1, foot2]
            c.OnEvent("Click", (*) => Run(this.TG_URL))
        E.MakeHand([foot1, foot2])

        ; --- правая колонка: закрыть сверху, сохранить снизу ---
        xr := winW - M - rightW
        E.AddFlatButton(g, xr, cardY, rightW, 32, "закрыть", "2E2E2E", "E0E0E0", (*) => this.Close())
        E.AddFlatButton(g, xr, winH - M - 32, rightW, 32, "сохранить", this.COL_SEL, "FFFFFF", (*) => this.Save())

        g.OnEvent("Close", (*) => this.Close())
        g.OnEvent("Escape", (*) => this.Close())
        g.Show(Format("w{} h{} Hide", winW, winH))
    }

    ; пункт сайдбара; выбранный — синяя плашка
    static AddSideItem(g, x, y, w, title, tab) {
        E := Editor2
        sel := (tab = this._tab)
        body := g.AddText(Format("x{} y{} w{} h30 Background{}", x, y, w, sel ? this.COL_SEL : E.COL_BG))
        g.SetFont(sel ? "s9 w600" : "s9", E.FONT)
        label := g.AddText(Format("x{} y{} w{} Background{} c{}", x + 10, y + 7, w - 20,
            sel ? this.COL_SEL : E.COL_BG, sel ? "FFFFFF" : "CCCCCC"), title)
        cb := ObjBindMethod(this, "SelectTab", tab)
        body.OnEvent("Click", cb), label.OnEvent("Click", cb)
        E.MakeHand([body, label])
        this._sideItems[tab] := {body: body, label: label}
    }

    static SelectTab(tab, *) {
        if (tab = this._tab)
            return
        this._tab := tab
        for t, item in this._sideItems {
            sel := (t = tab)
            item.body.Opt("Background" (sel ? this.COL_SEL : Editor2.COL_BG))
            item.label.Opt("Background" (sel ? this.COL_SEL : Editor2.COL_BG) " c" (sel ? "FFFFFF" : "CCCCCC"))
            item.body.Redraw(), item.label.Redraw()
        }
        showMain := (tab = "main")
        for c in this._mainCtrls
            c.Visible := showMain
        for key, tg in this._toggles {
            tg.body.Visible := showMain
            tg.knob.Visible := showMain
        }
        for key, dd in this._drops
            dd.ctrl.Visible := showMain
        for c in this._aboutCtrls
            c.Visible := !showMain
    }

    ; -------------------------------------------------------------------------
    ;  Тумблер: трек 34x18 + белый бегунок; вкл — фиолетовый (акцент как на маке)
    ; -------------------------------------------------------------------------
    static AddToggle(g, x, y, key, on) {
        E := Editor2
        body := g.AddText(Format("x{} y{} w34 h18 Background{}", x, y, on ? E.COL_SHIFT : this.COL_OFF))
        knob := g.AddText(Format("x{} y{} w12 h12 BackgroundFFFFFF", x + (on ? 19 : 3), y + 3))
        this._toggles[key] := {body: body, knob: knob, on: on, x: x, y: y}
        cb := ObjBindMethod(this, "OnToggle", key)
        body.OnEvent("Click", cb), knob.OnEvent("Click", cb)
        E.MakeHand([body, knob])
    }

    static OnToggle(key, *) {
        tg := this._toggles[key]
        tg.on := !tg.on
        tg.body.Opt("Background" (tg.on ? Editor2.COL_SHIFT : this.COL_OFF))
        tg.body.Redraw()
        tg.knob.Move(tg.x + (tg.on ? 19 : 3))
        tg.knob.Redraw()
    }

    ; -------------------------------------------------------------------------
    ;  Выпадашка: тёмная Text-кнопка «подпись ▾» + системное попап-меню
    ; -------------------------------------------------------------------------
    static AddDrop(g, x, y, key, options, value) {
        E := Editor2
        g.SetFont("s9", E.FONT)
        ctrl := g.AddText(Format("x{} y{} w96 h20 Center Background{} cE0E0E0", x, y, this.COL_DROP),
            this.DropLabel(options, value) " " Chr(0x25BE))
        this._drops[key] := {ctrl: ctrl, value: value, options: options}
        ctrl.OnEvent("Click", ObjBindMethod(this, "OnDrop", key))
        E.MakeHand([ctrl])
    }

    static DropLabel(options, value) {
        for opt in options
            if (opt[1] = value)
                return opt[2]
        return options[1][2]
    }

    static OnDrop(key, *) {
        dd := this._drops[key]
        m := Menu()
        for opt in dd.options {
            m.Add(opt[2], this.MakeDropHandler(key, opt[1], opt[2]))
            if (opt[1] = dd.value)
                m.Check(opt[2])
        }
        m.Show()
    }

    static MakeDropHandler(key, value, label) {
        return (*) => (
            this._drops[key].value := value,
            this._drops[key].ctrl.Text := label " " Chr(0x25BE)
        )
    }

    ; -------------------------------------------------------------------------
    ;  Вкладка «О типографе» (тексты из aboutCard, адаптированы под Win-хоткей)
    ; -------------------------------------------------------------------------
    static BuildAbout(g, x, y, w, h) {
        E := Editor2
        card := g.AddText(Format("x{} y{} w{} h{} Hidden Background{}", x, y, w, h, this.COL_CARD))
        this._aboutCtrls.Push(card)
        pad := 24
        tx := x + pad, tw := w - 2 * pad
        ty := y + pad
        g.SetFont("s14 w600", E.FONT)
        t := g.AddText(Format("x{} y{} w{} Hidden Background{} cFFFFFF", tx, ty, tw, this.COL_CARD), "Типограф")
        this._aboutCtrls.Push(t)
        ty += 40
        g.SetFont("s10", E.FONT)
        for para in [
            "Чтобы использовать → выделите текст и нажмите Alt + ⌫ Backspace.",
            "Автоматически исправит и отформатирует выделенный текст на основе правил типографики и заменяет букву «е» на «ё» в словах, где она должна употребляться.",
            "Расставит неразрывные пробелы и уберёт висячие предлоги и союзы. Исправит `"простые кавычки`" на «ёлочки» и „лапки“, а знак минуса на дефис, длинное или среднее тире. Разобьёт длинные числа перед знаком валюты по разрядам и заменит в них точку на запятую.",
            "Правила рассчитаны на русский текст и под задачи автора."
        ] {
            t := g.AddText(Format("x{} y{} w{} Hidden Background{} cB3B3B3", tx, ty, tw, this.COL_CARD), para)
            this._aboutCtrls.Push(t)
            t.GetPos(, , , &ph)
            ty += ph + 16
        }
        g.SetFont("s10", E.FONT)
        pre := g.AddText(Format("x{} y{} Hidden Background{} cB3B3B3", tx, ty - 12, this.COL_CARD), "Основано на")
        this._aboutCtrls.Push(pre)
        pre.GetPos(&px, &py, &pw)
        g.SetFont("s10 underline", E.FONT)
        link := g.AddText(Format("x{} y{} Hidden Background{} c{}", px + pw + 5, py, this.COL_CARD, E.COL_SHIFT), "typograf")
        g.SetFont("s10 norm", E.FONT)
        link.OnEvent("Click", (*) => Run(this.TYPOGRAF_URL))
        E.MakeHand([link])
        this._aboutCtrls.Push(link)
    }

    ; -------------------------------------------------------------------------
    static Save() {
        settings := Map()
        for key, tg in this._toggles
            settings[key] := tg.on ? "1" : "0"
        for key, dd in this._drops
            settings[key] := dd.value
        Config.SetTypographSettings(settings)
        this.Close()
    }
}
