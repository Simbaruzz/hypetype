#NoEnv
SetWorkingDir %A_ScriptDir% 
#SingleInstance Force
#Persistent ; Удержание скрипта в памяти
SetTitleMatchMode, 2 ; Установка режима поиска окон


;=============================================================================== МЕНЮ И ТРЕЙ ===================================================================================

;Настроить иконку в трее
;iconPath := A_Temp "\icon.ico"
;FileInstall, assets\icon.ico, %iconPath%, 1
;Menu, Tray, Icon, %iconPath%

; ====== Меню в трее и подсказка ======
global CurrentMenuState := "Показать раскладку" ; Изначальное состояние меню

Menu, Tray, NoStandard
Menu, Tray, Add, Выход, ExitScript
Menu, Tray, Add, ; Разделитель
Menu, Tray, Add, Запуск при старте, ToggleAutoStart
Menu, Tray, Add, Виртуализация, ToggleInstall
Menu, Tray, Add, ; Разделитель
Menu, Tray, Add, Редактировать, ShowEditor ; Добавляем пункт меню с текстом

; Установить подсказку
Menu, Tray, Tip, hypetype 0.4

; Обновляем статус меню
CheckAutostart()
CheckInstalled()
UpdateMenuReg()



;================================================================= Перехват и карта клавиш из ini файла =========================================================================


; Устанавливаем config.ini
global configFile := A_ScriptDir "\config.ini"


; Определяем клавишу-модификатор
ModifierKey := "vkA9"  ; Правый Alt

; Создаем объект для хранения соответствий
keyMappings := {}

; Читаем файл конфигурации
FileEncoding, UTF-8
Loop, Read, %configFile%
{
    ; Пропускаем BOM и заголовок секции
    if (A_Index <= 2)
        continue

    ; Разбираем строку формата ScanCode=Symbol1,Symbol2
    line := A_LoopReadLine
    if (line != "") {
        parts := StrSplit(line, "=")
        scanCode := parts[1]
        symbols := StrSplit(parts[2], ",")
        keyMappings[scanCode] := [symbols[1], symbols[2]]
    }
}

; Функция для обработки нажатий клавиш
NumberKey(scanCode) {
    global keyMappings

    symbols := keyMappings[scanCode]
    if (!symbols)
        return

    SetKeyDelay, 1

    if (GetKeyState("Shift", "P")) {
        SendRaw % symbols[2]  ; Используем SendRaw вместо SendInput
    } else {
        SendRaw % symbols[1]
    }
}

; Регистрируем хоткеи для каждого сканкода
for scanCode in keyMappings {
    ; Формируем комбинацию хоткея
    hotkeyCombination := ModifierKey . " & " . scanCode

    ; Создаем привязанную функцию с текущим сканкодом
    fn := Func("NumberKey").Bind(scanCode)

    ; Регистрируем хоткей
    Hotkey, %hotkeyCombination%, %fn%
}


#Include editor.ahk

;====================================================================== Автозапуск ========================================================================

;==== Функция для переключения автозапуска ====
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


;======================================================================== Виртуализация ==================================================================

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

; Включение/отключение установки
ToggleInstall:
    if (!Installed) {
        ; Установка: меняем RAlt
        RegWrite, REG_BINARY, HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout, Scancode Map, 00000000000000000200000068e038e000000000
        MsgBox, 64, Готово, Вирутализация включена! Перезагрузите компьютер.
    } else {
        ; Сброс: удаляем Scancode Map
        RegDelete, HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout, Scancode Map
        MsgBox, 64, Готово, Виртуализация выключена! Перезагрузите компьютер.
    }
    CheckInstalled()  ; Обновляем статус
    UpdateMenuReg()  ; Обновляем меню
return

; Обновление состояния меню
UpdateMenuReg() {
    global Installed
    if (Installed) {
        Menu, Tray, Check, Виртуализация
    } else {
        Menu, Tray, UnCheck, Виртуализация
    }
}


ExitScript:
    ExitApp
return


;================================================================= Горячие клавиши ========================================================================

;Нажать Alt+Enter
vkA9 & Enter::
    Send {LAlt Down}{Enter Down}{Enter Up}{LAlt Up}
return

;==================== 


