//
//  AppDelegate.swift
//  hypetype
//
//  Menu bar, жизненный цикл, разрешения Accessibility, автозапуск.
//

import Cocoa
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var eventTapManager: EventTapManager?
    var settingsManager = SettingsManager.shared
    var editorWindow: NSWindow?
    weak var enabledMenuItem: NSMenuItem?
    weak var launchAtLoginMenuItem: NSMenuItem?
    weak var yofikatorMenuItem: NSMenuItem?
    var permissionCheckTimer: Timer?
    var configWatcher: ConfigFileWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        startConfigWatcher()

        if !checkAccessibilityPermissions() {
            startPermissionCheckTimer()
        } else {
            if settingsManager.isEnabled {
                startEventTap()
            }
        }
    }

    /// Авто-reload при внешней подмене config.ini (например, файл принесли с Windows).
    /// Переиспользуем существующий канал: post .mappingsDidChange → EventTapManager перечитает.
    func startConfigWatcher() {
        configWatcher = ConfigFileWatcher(folder: LayoutStore.shared.configFolder) {
            NotificationCenter.default.post(name: .mappingsDidChange, object: nil)
        }
        configWatcher?.start()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let icon = NSImage(named: "MenuBarIcon") {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            } else {
                button.title = "⌥"
            }
        }

        let menu = NSMenu()

        let enabledItem = NSMenuItem(title: "Виртуализация", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.state = settingsManager.isEnabled ? .on : .off
        menu.addItem(enabledItem)
        self.enabledMenuItem = enabledItem

        let launchAtLoginItem = NSMenuItem(title: "Запуск при старте", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)
        self.launchAtLoginMenuItem = launchAtLoginItem

        let yofikatorItem = NSMenuItem(title: "Ёфикатор", action: #selector(toggleYofikator), keyEquivalent: "")
        yofikatorItem.state = settingsManager.useYofikator ? .on : .off
        menu.addItem(yofikatorItem)
        self.yofikatorMenuItem = yofikatorItem

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Редактировать...", action: #selector(openKeyboardEditor), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: "Открыть папку настроек", action: #selector(openConfigFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Про hypetype↗", action: #selector(openGitHub), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func toggleEnabled() {
        settingsManager.isEnabled.toggle()
        enabledMenuItem?.state = settingsManager.isEnabled ? .on : .off

        if settingsManager.isEnabled {
            startEventTap()
        } else {
            eventTapManager?.stop()
        }
    }

    @objc func toggleYofikator() {
        settingsManager.useYofikator.toggle()
        yofikatorMenuItem?.state = settingsManager.useYofikator ? .on : .off
    }

    @objc func quit() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        NSApplication.shared.terminate(nil)
    }

    @objc func openGitHub() {
        if let url = URL(string: "https://github.com/Simbaruzz/hypetype-mac") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openConfigFolder() {
        let configPath = LayoutStore.shared.configPath
        let folderPath = (configPath as NSString).deletingLastPathComponent
        if let url = URL(string: "file://\(folderPath)") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openKeyboardEditor() {
        if let window = editorWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: KeyboardEditorView2())
        hosting.sizingOptions = .preferredContentSize   // окно подстраивается под контент
        let window = NSWindow(contentViewController: hosting)
        window.title = "hypetype"
        window.styleMask = [.titled, .closable]
        editorWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.editorWindow = nil
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Центрируем ПОСЛЕ того, как контент задал размер окна: иначе center() ловит
        // ещё пустое окно, а затем контент растёт вправо/вниз — окно уезжает вбок.
        DispatchQueue.main.async { window.center() }
    }

    func checkAccessibilityPermissions() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    func startPermissionCheckTimer() {
        permissionCheckTimer?.invalidate()

        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            if AXIsProcessTrusted() {
                timer.invalidate()
                self.permissionCheckTimer = nil

                self.settingsManager.isEnabled = true
                self.enabledMenuItem?.state = .on
                self.startEventTap()

                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Всё чикаго!"
                    alert.informativeText = "Виртуализация включена ^_^\nСмело печатайте символы в стиле hypetype!"
                    alert.alertStyle = .informational
                    alert.runModal()
                }
            }
        }
    }

    func startEventTap() {
        guard settingsManager.isEnabled else { return }

        if eventTapManager == nil {
            eventTapManager = EventTapManager()
        }
        eventTapManager?.start()
    }

    // MARK: - Launch at Login

    @objc func toggleLaunchAtLogin() {
        let currentState = isLaunchAtLoginEnabled()

        if #available(macOS 13.0, *) {
            do {
                if currentState {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
                launchAtLoginMenuItem?.state = isLaunchAtLoginEnabled() ? .on : .off
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Ошибка автозапуска"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Требуется macOS 13+"
            alert.informativeText = "Автозапуск поддерживается только на macOS 13 Ventura и новее"
            alert.alertStyle = .informational
            alert.runModal()
        }
    }

    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
