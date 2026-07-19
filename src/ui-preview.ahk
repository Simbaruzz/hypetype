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

; при запуске интерпретатором иконка была бы AutoHotkey; в собранном exe
; её вшивает Ahk2Exe (/icon assets\icon.ico, см. build.yml) — тут ставим сами
TraySetIcon(A_ScriptDir "\..\assets\icon.ico")

Config.Load()
Editor2.Show()
