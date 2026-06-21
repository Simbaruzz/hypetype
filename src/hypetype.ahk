#Requires AutoHotkey v2.0
#SingleInstance Force

#Include strings.ahk
#Include config.ahk
#Include registry.ahk
#Include typograph.ahk
#Include yodict.ahk
#Include input.ahk
#Include editor.ahk

Persistent

; Единственная константа версии приложения (PLAN.md §1).
global APP_VERSION := "0.1.0"
global APP_URL := "https://github.com/Simbaruzz/hypetype"
global VIRT_ARG := "/virt"   ; маркер: перезапущенный под админом экземпляр выполняет переключение

; =============================================================================
;  Инициализация — явная, линейная, в одном месте (PLAN.md §6).
; =============================================================================
Config.Load()
if (Config.PendingNotice != "")
    MsgBox(Config.PendingNotice, "hypetype", "Iconi")

KeyInput.Init()
BuildTray()

; перезапущены под админом ради переключения виртуализации (см. RelaunchAsAdmin)
for arg in A_Args {
    if (arg = VIRT_ARG) {
        ToggleVirtualization()
        break
    }
}
return

; =============================================================================
;  Трей-меню
; =============================================================================
BuildTray() {
    tray := A_TrayMenu
    tray.Delete()                                        ; убрать стандартные пункты
    tray.Add(Txt.MenuExit, (*) => ExitApp())
    tray.Add(Txt.MenuAbout, OpenAbout)
    tray.Add()
    tray.Add(Txt.MenuAutostart, ToggleAutostart)
    tray.Add(Txt.MenuVirtualize, ToggleVirtualization)
    tray.Add(Txt.MenuYo, ToggleYo)
    tray.Add()
    tray.Add(Txt.MenuEditor, ShowEditor)
    A_IconTip := "hypetype " APP_VERSION
    RefreshTrayChecks()
}

RefreshTrayChecks() {
    tray := A_TrayMenu
    if Autostart.IsEnabled()
        tray.Check(Txt.MenuAutostart)
    else
        tray.Uncheck(Txt.MenuAutostart)
    if (ScancodeMap.Status() = "ours")
        tray.Check(Txt.MenuVirtualize)
    else
        tray.Uncheck(Txt.MenuVirtualize)
    if (Config.GetTypographSetting("Yo", "0") = "1")
        tray.Check(Txt.MenuYo)
    else
        tray.Uncheck(Txt.MenuYo)
}

ToggleAutostart(*) {
    Autostart.Toggle()
    RefreshTrayChecks()
}

ToggleYo(*) {
    Config.ToggleTypograph("Yo")        ; 0 <-> 1 в [Typograph], сохраняется в конфиг
    RefreshTrayChecks()
}

ToggleVirtualization(*) {
    if !A_IsAdmin {
        RelaunchAsAdmin()        ; нет прав — перезапустимся через UAC и выполним переключение там
        return
    }
    res := (ScancodeMap.Status() = "ours") ? ScancodeMap.Disable() : ScancodeMap.Enable()
    ShowVirtualizationResult(res)
    RefreshTrayChecks()
}

; Перезапуск через UAC с маркером VIRT_ARG. Успех -> уступаем место elevated-экземпляру;
; отказ UAC -> остаёмся как есть и сообщаем. Петли нет: перезапуск только при !A_IsAdmin.
RelaunchAsAdmin() {
    try {
        if A_IsCompiled
            Run('*RunAs "' A_ScriptFullPath '" ' VIRT_ARG)
        else
            Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '" ' VIRT_ARG)
        ExitApp()
    } catch {
        MsgBox(Txt.NoAdminBody, Txt.NoAdminTitle, "Icon!")
    }
}

ShowVirtualizationResult(res) {
    switch res.status {
        case "noadmin":
            MsgBox(Txt.NoAdminBody, Txt.NoAdminTitle, "Icon!")
        case "foreign-ralt":
            MsgBox(Txt.ForeignBody, Txt.ForeignTitle, "Icon!")
        case "badblob":
            MsgBox(Txt.BadBlobBody, Txt.BadBlobTitle, "Icon!")
        case "enabled":
            MsgBox(Txt.EnabledBody, Txt.EnabledTitle, "Iconi")
        case "disabled":
            MsgBox(Txt.DisabledBody, Txt.DisabledTitle, "Iconi")
        case "already":
            MsgBox(Txt.AlreadyOnBody, Txt.AlreadyOnTitle, "Iconi")
        case "already-off", "notpresent":
            MsgBox(Txt.AlreadyOffBody, Txt.AlreadyOffTitle, "Iconi")
    }
}

ShowEditor(*) {
    Editor.Show()
}

OpenAbout(*) {
    Run(APP_URL)
}
