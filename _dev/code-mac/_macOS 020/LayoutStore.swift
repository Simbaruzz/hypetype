//
//  LayoutStore.swift
//  hypetype
//
//  Файловый слой: чтение/запись config.ini, миграция legacy config.json (§8.2 FORMAT.md).
//  Использует LayoutFormat для (де)сериализации. Заменяет персистентную часть MappingManager.
//

import Foundation
import AppKit
import OSLog

private let log = Logger(subsystem: "hypetype", category: "LayoutStore")

final class LayoutStore {
    static let shared = LayoutStore()

    private let iniName = "config.ini"
    private let legacyName = "config.json"

    private lazy var folderURL: URL = resolveFolder()
    private var iniURL: URL { folderURL.appendingPathComponent(iniName) }
    private var legacyURL: URL { folderURL.appendingPathComponent(legacyName) }

    // MARK: - Папка хранения (Application Support/hypetype, с fallback в temp)

    private func resolveFolder() -> URL {
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let folder = appSupport.appendingPathComponent("hypetype")
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            if fm.fileExists(atPath: folder.path) { return folder }
        }
        let temp = fm.temporaryDirectory.appendingPathComponent("hypetype")
        try? fm.createDirectory(at: temp, withIntermediateDirectories: true)
        log.warning("Using temporary folder as fallback: \(temp.path)")
        return temp
    }

    // MARK: - Загрузка

    /// Рантайм-словарь раскладки (macKeyCode-keyed) для редактора.
    func loadMappings() -> [Int: (normal: String, shift: String)] {
        loadLayout().toMacMappings()
    }

    /// Полная модель: config.ini → миграция config.json → дефолт.
    /// EventTapManager использует её, чтобы взять и раскладку, и таймаут диакритики ([macOS]).
    func loadLayout() -> Layout {
        let fm = FileManager.default

        if fm.fileExists(atPath: iniURL.path) {
            do {
                let text = try String(contentsOf: iniURL, encoding: .utf8)
                return LayoutFormat.parse(text)
            } catch {
                log.error("Failed to read config.ini: \(error) — falling back to defaults")
                return .standard
            }
        }

        if fm.fileExists(atPath: legacyURL.path) {
            if let migrated = migrateLegacy() { return migrated }
        }

        let standard = Layout.standard
        write(standard)
        return standard
    }

    // MARK: - Сохранение

    func saveMappings(_ mappings: [Int: (normal: String, shift: String)]) {
        // Перечитываем текущий файл, чтобы сохранить чужие секции/ключи (round-trip §7).
        var layout: Layout
        if let text = try? String(contentsOf: iniURL, encoding: .utf8) {
            layout = LayoutFormat.parse(text)
        } else {
            layout = .standard
        }
        layout.applyMacMappings(mappings)
        write(layout)
    }

    // MARK: - Настройки типографа ([Typograph])

    /// Настройки типографа из config.ini (или дефолты, если секции/файла нет).
    /// Читаются на каждом вызове — как раскладка (TYPOGRAPH.md §9.3 п.8).
    func loadTypographSettings() -> TypographSettings {
        loadLayout().typograph
    }

    /// Сохраняет настройки типографа, сохраняя раскладку/чужие секции (round-trip §7).
    func saveTypographSettings(_ settings: TypographSettings) {
        var layout: Layout
        if let text = try? String(contentsOf: iniURL, encoding: .utf8) {
            layout = LayoutFormat.parse(text)
        } else {
            layout = .standard
        }
        layout.typograph = settings
        write(layout)
    }

    private func write(_ layout: Layout) {
        let text = LayoutFormat.serialize(layout)   // \n — нативно для macOS (§2)
        do {
            try text.data(using: .utf8)!.write(to: iniURL, options: .atomic)
            log.info("Saved \(layout.entries.count) keys to config.ini")
        } catch {
            log.error("Failed to write config.ini: \(error)")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Не удалось сохранить настройки"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    // MARK: - Миграция legacy JSON (§8.2)

    /// Конвертирует старый config.json в config.ini, делает бэкап config.json.old.
    /// Возвращает мигрированную модель или nil при ошибке.
    private func migrateLegacy() -> Layout? {
        do {
            let data = try Data(contentsOf: legacyURL)
            guard let layout = Self.layoutFromLegacyJSON(data) else {
                log.error("Legacy config.json could not be parsed — skipping migration")
                return nil
            }
            write(layout)
            // Бэкап исходника рядом (§8). Перезаписываем, если бэкап уже был.
            let backup = folderURL.appendingPathComponent("\(legacyName).old")
            try? FileManager.default.removeItem(at: backup)
            try FileManager.default.moveItem(at: legacyURL, to: backup)
            log.info("Migrated legacy config.json → config.ini (backup: \(backup.lastPathComponent))")
            return layout
        } catch {
            log.error("Legacy migration failed: \(error)")
            return nil
        }
    }

    /// Чистая конвертация legacy-JSON → Layout (тестируется отдельно).
    /// Строки конвертируются по Unicode scalars, НЕ по графемам (§8.2).
    static func layoutFromLegacyJSON(_ data: Data) -> Layout? {
        struct LegacyMapping: Decodable {
            let keyCode: Int
            let normal: String
            let shift: String
        }
        guard let legacy = try? JSONDecoder().decode([LegacyMapping].self, from: data) else {
            return nil
        }

        var layout = Layout(version: 2)
        for m in legacy {
            guard let def = KeyDefinitions.byMacKeyCode[m.keyCode] else { continue }
            let value = LayoutValue(alt: Array(m.normal.unicodeScalars),
                                    altShift: Array(m.shift.unicodeScalars))
            if !value.isEmpty { layout.entries[def.w3cName] = value }
        }
        layout.platformSettings = [SettingEntry(key: "DiacriticTimeoutMs", value: "3000")]
        return layout
    }

    // MARK: - Хелперы для UI

    var configPath: String { iniURL.path }

    /// Папка с config.ini — за ней следит ConfigFileWatcher (авто-reload).
    var configFolder: URL { folderURL }

    func revealConfigFile() {
        NSWorkspace.shared.activateFileViewerSelecting([iniURL])
    }
}
