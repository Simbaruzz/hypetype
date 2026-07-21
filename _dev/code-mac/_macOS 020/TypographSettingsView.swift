//
//  TypographSettingsView.swift
//  hypetype
//
//  Экран настроек типографа (ветка typograph-ui). Три зоны, как в Системных настройках macOS:
//  слева — навигация (Основные / О типографе), в центре — таблица правил (раздел · название ·
//  пример до · пример после · контрол), справа — «закрыть» сверху и «сохранить» снизу.
//
//  Данные живьём из config.ini (секция [Typograph]) через LayoutStore. Ёфикатор — из
//  SettingsManager (как пункт меню). Движок настройки читает на каждом нажатии хоткея.
//

import SwiftUI
import AppKit

// MARK: - Палитра (в тон новому редактору)

private let tAccent = Color(red: 0.72, green: 0.45, blue: 1.0)   // фиолетовый — тумблеры
private let tBoard = Color(white: 0.07)                          // общий фон окна
private let tCard = Color(white: 0.11)                           // карточка таблицы
private let tRowLine = Color(white: 0.18)                        // разделители строк
private let tSectionGap = Color(white: 0.22)                     // разделитель секций
private let tLabel = Color.white.opacity(0.9)
private let tExample = Color.white.opacity(0.45)                 // серые примеры «до/после»

private let tgURL = URL(string: "https://t.me/simbarus")!

// MARK: - Модель строки

/// Контрол в правой части строки.
private enum RuleControl {
    case toggle(WritableKeyPath<TypographSettings, Bool>)
    case yofikator                 // особый тумблер — пишет в SettingsManager
    case percent                   // выпадашка: без пробела / узкий / с пробелом
    case currencySide              // выпадашка: слева / справа
}

private struct RuleRow: Identifiable {
    let id = UUID()
    let title: String
    let before: String
    let after: String
    let control: RuleControl
}

private struct RuleSection: Identifiable {
    let id = UUID()
    let title: String
    let rows: [RuleRow]
}

/// НБ показываем значком ⍽ (как в редакторе клавиш).
private let NB = "\u{237D}"

private let typographSections: [RuleSection] = [
    RuleSection(title: "Ёфикатор", rows: [
        RuleRow(title: "Заменять е → ё", before: "пришел", after: "пришёл", control: .yofikator),
    ]),
    RuleSection(title: "Неразрывные пробелы", rows: [
        RuleRow(title: "Число + слово", before: "5 лет", after: "5\(NB)лет", control: .toggle(\.nbspNumberWord)),
        RuleRow(title: "Инициалы", before: "А.А. Иванов", after: "А.А.\(NB)Иванов", control: .toggle(\.nbspInitials)),
        RuleRow(title: "Частицы", before: "нужно ли", after: "нужно\(NB)ли", control: .toggle(\.nbspParticles)),
        RuleRow(title: "Предлоги / союзы", before: "в лесу", after: "в\(NB)лесу", control: .toggle(\.nbspShortWords)),
    ]),
    RuleSection(title: "Тире", rows: [
        RuleRow(title: "Дефис в тексте", before: "дизайн - огонь", after: "дизайн — огонь", control: .toggle(\.dashText)),
        RuleRow(title: "Прямая речь", before: "- Это я", after: "— Это я", control: .toggle(\.dashSpeech)),
        RuleRow(title: "Диапазоны", before: "2002-2009", after: "2002–2009", control: .toggle(\.dashRanges)),
    ]),
    RuleSection(title: "Пунктуация", rows: [
        RuleRow(title: "Многоточие", before: "точки...", after: "точки…", control: .toggle(\.punctEllipsis)),
        RuleRow(title: "Повторы", before: "что!!!", after: "что!", control: .toggle(\.punctCollapse)),
        RuleRow(title: "Порядок !?", before: "как!?", after: "как?!", control: .toggle(\.punctOrder)),
    ]),
    RuleSection(title: "Пробелы", rows: [
        RuleRow(title: "Вокруг пунктуации", before: "синий ,розовый", after: "синий, розовый", control: .toggle(\.spaceClean)),
        RuleRow(title: "Знак %", before: "23 %", after: "23%", control: .percent),
    ]),
    RuleSection(title: "Кавычки", rows: [
        RuleRow(title: "Прямые → ёлочки", before: "\"привет\"", after: "«привет»", control: .toggle(\.quotes)),
    ]),
    RuleSection(title: "Числа", rows: [
        RuleRow(title: "Валюта → знак", before: "5 руб", after: "5\(NB)₽", control: .toggle(\.currencySymbol)),
        RuleRow(title: "Сторона валюты", before: "₽ 300", after: "300\(NB)₽", control: .currencySide),
        RuleRow(title: "Разряды", before: "2345123 ₽", after: "2\(NB)345\(NB)123\(NB)₽", control: .toggle(\.currencyGrouping)),
        RuleRow(title: "Копейки в сумму", before: "45 руб. 5 коп.", after: "45,05\(NB)₽", control: .toggle(\.currencyKopecks)),
    ]),
    RuleSection(title: "Символы", rows: [
        RuleRow(title: "Спецсимволы", before: "(c) +-", after: "© ±", control: .toggle(\.symbols)),
    ]),
]

// MARK: - Корневой экран

struct TypographSettingsView: View {
    /// Возврат к клавиатуре (кнопка «закрыть» / после «сохранить»).
    var onClose: () -> Void = {}

    private enum Tab { case main, about }

    @State private var tab: Tab = .main
    @State private var settings: TypographSettings
    @State private var yofikator: Bool

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
        _settings = State(initialValue: LayoutStore.shared.loadTypographSettings())
        _yofikator = State(initialValue: SettingsManager.shared.useYofikator)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            sidebar
                .frame(width: 150).frame(maxHeight: .infinity)

            Group {
                switch tab {
                case .main:  settingsCard
                case .about: aboutCard
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            rightColumn
                .frame(width: 96).frame(maxHeight: .infinity)
        }
        .padding(20)
        .frame(width: 960, height: 600)   // ширина как у клавиатуры; высота фикс. (стабильно для окна)
        .background(tBoard)
    }

    // MARK: Левая зона — навигация + пасхалка

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            sidebarItem("Основные", .main)
            sidebarItem("О типографе", .about)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("Нужны допнастройки или нашли баг — пишите")
                (Text("@simbarus").foregroundColor(tAccent))
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.5))
            .contentShape(Rectangle())
            .onTapGesture { NSWorkspace.shared.open(tgURL) }
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
    }

    private func sidebarItem(_ title: String, _ value: Tab) -> some View {
        let selected = tab == value
        return Text(title)
            .font(.system(size: 13, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? .white : .white.opacity(0.8))
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
            .onTapGesture { tab = value }
    }

    // MARK: Центральная зона — таблица

    private var settingsCard: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(typographSections.enumerated()), id: \.element.id) { idx, section in
                    sectionView(section)
                    if idx < typographSections.count - 1 {
                        Rectangle().fill(tSectionGap).frame(height: 1)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(tCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tRowLine, lineWidth: 1))
    }

    /// Секция = объединённая левая «ячейка» (ярлык, прижат к верху) + правая колонка строк.
    /// Ярлык не входит в строки, поэтому не влияет на их высоту (модель таблицы Word).
    private func sectionView(_ section: RuleSection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(section.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)   // перенос на 2 строки
                .frame(width: 96, alignment: .leading)          // базовая линия совместится с 1-й строкой

            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { i, row in
                    rowView(row)
                    if i < section.rows.count - 1 {
                        Rectangle().fill(tRowLine.opacity(0.5)).frame(height: 1)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
    }

    private func rowView(_ row: RuleRow) -> some View {
        HStack(spacing: 10) {
            Text(row.title)
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 140, alignment: .leading)

            Text(row.before)
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 104, alignment: .leading)
            Text(row.after)
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.62))
                .frame(width: 104, alignment: .leading)

            Spacer(minLength: 0)

            control(for: row.control)
        }
        .font(.system(size: 12))
        .padding(.vertical, 8)
    }

    // MARK: Контролы

    @ViewBuilder
    private func control(for control: RuleControl) -> some View {
        switch control {
        case .toggle(let kp):
            Toggle("", isOn: Binding(get: { settings[keyPath: kp] },
                                     set: { settings[keyPath: kp] = $0 }))
                .toggleStyle(.switch).tint(tAccent).labelsHidden().controlSize(.small)
        case .yofikator:
            Toggle("", isOn: $yofikator)
                .toggleStyle(.switch).tint(tAccent).labelsHidden().controlSize(.small)
        case .percent:
            dropdown(percentLabel) {
                Button("без пробела") { settings.percentSpace = .none }
                Button("узкий")       { settings.percentSpace = .narrow }
                Button("с пробелом")  { settings.percentSpace = .regular }
            }
        case .currencySide:
            dropdown(settings.currencyPosition == .after ? "справа" : "слева") {
                Button("справа") { settings.currencyPosition = .after }
                Button("слева")  { settings.currencyPosition = .before }
            }
        }
    }

    private var percentLabel: String {
        switch settings.percentSpace {
        case .none:    return "без пробела"
        case .narrow:  return "узкий"
        case .regular: return "с пробелом"
        }
    }

    private func dropdown<Content: View>(_ label: String, @ViewBuilder _ items: () -> Content) -> some View {
        Menu {
            items()
        } label: {
            HStack(spacing: 5) {
                Text(label).font(.system(size: 12))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color(white: 0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: Правая зона — закрыть / сохранить

    private var rightColumn: some View {
        VStack {
            actionButton("закрыть", filled: false) { onClose() }
            Spacer(minLength: 0)
            actionButton("сохранить", filled: true) { save() }
        }
    }

    private func actionButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(filled ? .white : .white.opacity(0.85))
                .padding(.horizontal, 10).padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(filled ? Color.accentColor : Color(white: 0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        LayoutStore.shared.saveTypographSettings(settings)
        SettingsManager.shared.useYofikator = yofikator
        onClose()
    }

    // MARK: «О типографе»

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 22) {   // расстояние между абзацами
            Text("Типограф")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.bottom, 2)

            aboutParagraph("Чтобы использовать → выделите текст и нажмите R⌥ + ⌫ Backspace.")
            aboutParagraph("Автоматически исправит и отформатирует выделенный текст на основе правил типографики и заменяет букву «е» на «ё» в словах, где она должна употребляться.")
            aboutParagraph("Расставит неразрывные пробелы и уберёт висячие предлоги и союзы. Исправит \"простые кавычки\" на «ёлочки» и „лапки“, а знак минуса на дефис, длинное или среднее тире. Разобьёт длинные числа перед знаком валюты по разрядам и заменит в них точку на запятую.")
            aboutParagraph("Правила рассчитаны на русский текст и под задачи автора. Основано на [typograf](https://github.com/typograf/typograf)")

            Spacer(minLength: 0)
        }
        .tint(tAccent)   // цвет ссылки в тексте
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tRowLine, lineWidth: 1))
    }

    /// Один абзац «О типографе». Строковый литерал → Markdown (ссылка [text](url) кликается).
    private func aboutParagraph(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.7))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    TypographSettingsView()
        .frame(width: 960, height: 600)
}
