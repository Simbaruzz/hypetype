#NoEnv
SetWorkingDir %A_ScriptDir%
#SingleInstance Force
#Persistent ; Удержание скрипта в памяти
SendMode Input
SetTitleMatchMode, 2 ; Установка режима поиска окон


;=============================================================================== МЕНЮ И ТРЕЙ ===================================================================================

;Настроить иконку в трее
if (!A_IsCompiled) {
    try {
        Menu, Tray, Icon, % A_ScriptDir . "\..\assets\icon.ico"
    }
}


; ====== Меню в трее и подсказка ======

Menu, Tray, NoStandard
Menu, Tray, Add, Выход, ExitScript
Menu, Tray, Add, ; Разделитель
Menu, Tray, Add, Запуск при старте, ToggleAutoStart
Menu, Tray, Add, Виртуализация, ToggleInstall
Menu, Tray, Add, ; Разделитель
Menu, Tray, Add, Редактировать, ShowEditor ; Добавляем пункт меню с текстом

; Установить подсказку
Menu, Tray, Tip, hypetype beta 0.0.4

; Обновляем статус меню
CheckAutostart()
CheckInstalled()
UpdateMenuReg()



;================================================================= ПЕРЕХВАТ КЛАВИШ и CONGIF.INI =========================================================================


; -------------------------------------------
; Глобальные переменные
; -------------------------------------------
global configFile := A_ScriptDir "\config.ini"
global ModifierKey := "vkA9" ; Правый Alt
global keyMappings := {}

; Эти две переменные отвечают за «модальный» ввод диакритики:
global g_isDiacriticMode := false
global g_waitingDiacritic := ""

; -------------------------------------------
; Чтение config.ini
; Формат строк: SCxxx=Symbol1,Symbol2
; -------------------------------------------
FileEncoding, UTF-8
Loop, Read, % configFile
{
    if (A_Index <= 2)
        continue

    line := A_LoopReadLine
    if (line != "")
    {
        parts := StrSplit(line, "=")
        scanCode := parts[1]
        symbols := StrSplit(parts[2], ",")
        keyMappings[scanCode] := [ symbols[1], symbols[2] ]
    }
}

; -------------------------------------------
; Проверяем: символ ∈ диапазоне U+0300..U+036F?
; -------------------------------------------
IsCombiningDiacritic(symbol) {
    if (StrLen(symbol) != 1)
        return false
    code := Ord(symbol)
    return (code >= 0x0300 && code <= 0x036F)
}

; -------------------------------------------
; Normalization через Normaliz.dll, Form C
; -------------------------------------------
NormalizeString(str) {
    static hDll := 0, pNormalizeString := 0

    if !hDll {
        hDll := DllCall("LoadLibrary", "Str", "Normaliz.dll", "Ptr")
        if !hDll {
            MsgBox, 16, Error, Не могу загрузить Normaliz.dll — версия Windows устарела!
            return str
        }
        pNormalizeString := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "NormalizeString", "Ptr")
        if !pNormalizeString {
            MsgBox, 16, Error, Не могу получить адрес функции NormalizeString!
            return str
        }
    }

    bufSize := DllCall(pNormalizeString
    , "int", 1 ; Form C
    , "WStr", str
    , "int", StrLen(str)
    , "ptr", 0
    , "int", 0
    , "int")
    if (bufSize <= 0)
        return str

    VarSetCapacity(buf, bufSize*2, 0)
    ret := DllCall(pNormalizeString
    , "int", 1
    , "WStr", str
    , "int", StrLen(str)
    , "ptr", &buf
    , "int", bufSize
    , "int")
    if (ret <= 0)
        return str

    return StrGet(&buf, "UTF-16")
}

; -------------------------------------------
; Основная функция: работа с диакритикой + верхний символ с Shift + нижний только с Alt
; -------------------------------------------
NumberKey(scanCode) {
    global keyMappings
    global g_isDiacriticMode, g_waitingDiacritic

    symbols := keyMappings[scanCode]
    if (!symbols)
        return

    SetKeyDelay, -1

    ; Определяем, какой символ будем использовать
    symbol := (GetKeyState("Shift", "P")) ? symbols[2] : symbols[1]
    if (symbol = "")
        return

    ; Проверяем, не диакритика ли это
    if (IsCombiningDiacritic(symbol)) {
        ; Если диакритика — запоминаем диакритический символ и включаем режим
        g_waitingDiacritic := symbol
        g_isDiacriticMode := true

        ToolTip, %symbol% Введите букву
        SetTimer, RemoveToolTip, -1500

        ; Запускаем одноразовый Input для захвата «следующего» символа
        WaitForNextChar()
        return
    }

    ; Если это НЕ диакритика:
    if (g_isDiacriticMode) {
        ; У нас «висит» диакритика — склеим
        combined := symbol . g_waitingDiacritic
        normalized := NormalizeString(combined)
        SendInput % normalized

        g_waitingDiacritic := ""
        g_isDiacriticMode := false
    } else {
        ; Обычное поведение
        SendRaw % symbol
    }
}

; -------------------------------------------
; Ждём следующий «обычный» символ без модификаторов
; -------------------------------------------
WaitForNextChar() {
    global g_isDiacriticMode, g_waitingDiacritic

    if (!g_isDiacriticMode)
        return

    BlockInput, On
    Input, SingleKey, L1 I T5, {Enter}{Escape}{LAlt}{RAlt}{Ctrl}{Shift}{AppsKey}{CapsLock}
    BlockInput, Off

    if (ErrorLevel = "Timeout") {
        g_isDiacriticMode := false
        g_waitingDiacritic := ""
        ToolTip, Время ввода буквы вышло
        SetTimer, RemoveToolTip, -1200, %x%, %y%
        return
    } else if InStr(ErrorLevel, "EndKey:") {
        g_isDiacriticMode := false
        g_waitingDiacritic := ""
        ToolTip, Диакритика отменена
        SetTimer, RemoveToolTip, -1200
        return
    }

    combined := SingleKey . g_waitingDiacritic
    normalized := NormalizeString(combined)
    SendInput % normalized

    g_waitingDiacritic := ""
    g_isDiacriticMode := false
}

RemoveToolTip() {
    ToolTip
}

; -------------------------------------------
; Регистрируем хоткеи
; -------------------------------------------
for scanCode in keyMappings
{
    hotkeyCombination := ModifierKey . " & " . scanCode
    fn := Func("NumberKey").Bind(scanCode)
    Hotkey, %hotkeyCombination%, %fn%
}

; Подлкючаем редактор и карту клавиш
#Include editor.ahk

;====================================================================== АВТОЗАПУПСК ПРИ СТАРТЕ СИСТЕМЫ ========================================================================


;--------------------------------------------
;==== Флаг для переключения автозапуска ====
;-------------------------------------------
ToggleAutostart:
    ; Получаем путь к текущему исполнимому файлу
    exePath := A_ScriptFullPath

    ; Проверяем, есть ли программа в автозапуске
    RegRead, autostartValue, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, hypetype
    if (autostartValue = exePath) {
        ; Если программа есть в автозапуске, удаляем из реестра
        RegDelete, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, hypetype

    } else {
        ; Если программы нет в автозапуске, добавляем в реестр
        RegWrite, REG_SZ, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, hypetype, %exePath%

    }
    CheckAutostart()

return

; ==== Функция для проверки состояния автозапуска при старте ====
CheckAutostart() {
    exePath := A_ScriptFullPath
    RegRead, autostartValue, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Run, hypetype
    if (autostartValue = exePath) {
        ; Если программа в автозапуске, ставим галочку
        Menu, Tray, Check, Запуск при старте
    } else {
        ; Если программы нет в автозапуске, снимаем галочку
        Menu, Tray, UnCheck, Запуск при старте
    }
}
return


;======================================================================== ВИРТУАЛИЗАЦИЯ ==================================================================

global Installed := false  ; Статус установки
CheckInstalled()  ; Проверяем состояние
UpdateMenuReg()  ; Обновляем меню

Return

; Проверка текущего состояния Scancode Map
CheckInstalled() {
    global Installed
    RegRead, Scancode, HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout, Scancode Map
    if (ErrorLevel) {  ; Если ключ не существует
        Installed := false
    } else {
        Installed := true
    }
}

;-----------------------------------------------------------
;========== Включение/отключение виртуализации =============
;-----------------------------------------------------------
ToggleInstall() {
    if (!A_IsAdmin) {
        MsgBox, 48, Требуются права администратора!, Закройте и запустите программу от имени администратора для работы с «Виртуализацией».
        return
    }

    if (!Installed) {
        RegWrite, REG_BINARY, HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout, Scancode Map, 00000000000000000200000068e038e000000000
        MsgBox, 64, Всё Чикаго!, «Вирутализация» включена! Перезагрузите компьютер ^_^ и печатайте символы в стиле hypetype
    } else {
        RegDelete, HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout, Scancode Map
        MsgBox, 64, Всё по плану — но слегка грустненько, «Виртуализация» отключена T_T Перезагрузите компьютер для полного возврата к стандартному Alt
    }
    CheckInstalled()
    UpdateMenuReg()
}

; Обновление состояния меню
UpdateMenuReg() {
    global Installed
    if (Installed) {
        Menu, Tray, Check, Виртуализация
    } else {
        Menu, Tray, UnCheck, Виртуализация
    }
}
    CheckInstalled()
    UpdateMenuReg()
return

; ==================== Флаг для закрытия программы ====================
ExitScript:
    ExitApp
return


;================================================================= Горячие клавиши ========================================================================

;Нажать Alt+Enter для Развертывания видео и Свойств в проводнике
vkA9 & Enter::
    Send {LAlt Down}{Enter Down}{Enter Up}{LAlt Up}
return

;====================


; -----------------------------------------------------
; Если хотим, чтобы Escape отменял "ожидание диакритики"
; -----------------------------------------------------
#If g_isDiacriticMode
Escape::
    g_isDiacriticMode := false
    g_waitingDiacritic := ""
    ToolTip, Диакритика отменена
    SetTimer, RemoveToolTip, -1200
return
#If
