#Requires AutoHotkey v2.0

; =============================================================================
;  editor2.ahk — спайк нового редактора-клавиатуры (UI-SPIKE.md).
;  Тёмная тема, кейкапы из Text-контролов (кнопки не умеют цвет/двухэтажность),
;  данные — только через API Config (GetKey/SetKey/Keys). Старый editor.ahk
;  не трогаем; интеграции в hypetype.ahk нет до вердикта владельца.
; =============================================================================

class Editor2 {
    static _gui := ""

    ; --- палитра (тона по скриншотам мака, _preview/) ---
    static COL_BG   := "121212"     ; фон окна
    static COL_KEY  := "1E1E1E"     ; тело клавиши
    static COL_HYPE := "F2F2F2"     ; подсвеченная хайп-клавиша (правый Alt)
    static COL_MAIN := "FFFFFF"     ; основной символ (с Alt)
    static COL_SHIFT := "B873FF"    ; Shift-символ (фиолетовый акцент)
    static COL_BASE := "757575"     ; буква клавиши и декор-глифы
    static COL_HINT := "8C8C8C"     ; текст подсказки внизу

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

    static Build() {
        g := Gui("-Resize", Txt.MainTitle)
        g.BackColor := this.COL_BG
        g.MarginX := this.MARGIN, g.MarginY := this.MARGIN
        g.OnEvent("Close", (*) => ExitApp())    ; спайк: закрыл окно — вышел
        this._gui := g
        this.ApplyDarkTitle(g)

        ; ширина контента = ряд №1: `1…0-= (13×1u) + ТИПОГРАФ (1.5u), 13 зазоров
        contentW := 13 * this.U + Round(1.5 * this.U) + 13 * this.GAP
        ; высота: 5 рядов клавиш (подсказка появится в следующих шагах)
        contentH := 5 * this.KH + 4 * this.GAP

        g.Show(Format("w{} h{} Hide", contentW + 2 * this.MARGIN, contentH + 2 * this.MARGIN))
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
