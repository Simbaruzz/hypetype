#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================================
;  ui-preview.ahk — отдельная точка входа спайка нового UI (UI-SPIKE.md §2).
;  Запуск интерпретатором: AutoHotkey64.exe ui-preview.ahk. Без компиляции,
;  без трея и хоткеев — только окно редактора-клавиатуры.
; =============================================================================

#Include strings.ahk
#Include config.ahk
#Include editor2.ahk

Config.Load()
Editor2.Show()
