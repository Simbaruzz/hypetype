#Requires AutoHotkey v2.0
#SingleInstance Force

#Include strings.ahk
#Include config.ahk
#Include registry.ahk
#Include input.ahk
#Include editor.ahk

Persistent

; Единственная константа версии приложения (PLAN.md §1).
global APP_VERSION := "0.1.0"

; =============================================================================
;  Инициализация — явная, линейная, в одном месте (PLAN.md §6).
; =============================================================================
Config.Load()
SplitPath(Config.Path, , &cfgDir)
ScancodeMap.BackupDir := cfgDir          ; .reg-бэкап ляжет рядом с config.ini
if (Config.PendingNotice != "")
    MsgBox(Config.PendingNotice, "hypetype", "Iconi")

KeyInput.Init()
BuildTray()
return

; =============================================================================
;  Трей-меню
; =============================================================================
BuildTray() {
    tray := A_TrayMenu
    tray.Delete()                                        ; убрать стандартные пункты
    tray.Add(Txt.MenuExit, (*) => ExitApp())
    tray.Add()
    tray.Add(Txt.MenuAutostart, ToggleAutostart)
    tray.Add(Txt.MenuVirtualize, ToggleVirtualization)
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
}

ToggleAutostart(*) {
    Autostart.Toggle()
    RefreshTrayChecks()
}

ToggleVirtualization(*) {
    res := (ScancodeMap.Status() = "ours") ? ScancodeMap.Disable() : ScancodeMap.Enable()
    ShowVirtualizationResult(res)
    RefreshTrayChecks()
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
            MsgBox(Txt.EnabledBody Txt.BackupLine res.backup, Txt.EnabledTitle, "Iconi")
        case "disabled":
            MsgBox(Txt.DisabledBody Txt.BackupLine res.backup, Txt.DisabledTitle, "Iconi")
        case "already":
            MsgBox(Txt.AlreadyOnBody, Txt.AlreadyOnTitle, "Iconi")
        case "already-off", "notpresent":
            MsgBox(Txt.AlreadyOffBody, Txt.AlreadyOffTitle, "Iconi")
    }
}

ShowEditor(*) {
    Editor.Show()
}
