#Requires AutoHotkey v2.0

; =============================================================================
;  strings.ahk — все пользовательские строки одним блоком (PLAN.md §1).
;  Вынесено в отдельный файл, чтобы и точка входа, и editor.ahk (и тесты)
;  могли подключить строки без подтягивания auto-execute точки входа.
;  Задел под локализацию: для другого языка — заменить значения здесь.
; =============================================================================

class Txt {
    static MenuExit       := "Выход"
    static MenuAbout      := "Про hypetype↗"
    static MenuAutostart  := "Запуск при старте"
    static MenuVirtualize := "Виртуализация"
    static MenuYo         := "Ёфикатор"
    static MenuEditor     := "Редактировать"

    static NoAdminTitle := "Требуются права администратора!"
    static NoAdminBody  := "Без прав администратора «Виртуализацию» не переключить. Попробуйте ещё раз и подтвердите запрос."

    static EnabledTitle := "Всё Чикаго!"
    static EnabledBody  := "«Виртуализация» включена! Перезагрузите компьютер ^_^ и печатайте символы в стиле hypetype."

    static DisabledTitle := "Всё по плану — хоть и слегка грустненько"
    static DisabledBody  := "«Виртуализация» отключена T_T Перезагрузите компьютер для полного возврата к стандартному Alt."

    static ForeignTitle := "Правый Alt уже занят"
    static ForeignBody  := "Правый Alt уже переназначен другой программой. hypetype не будет это перезаписывать."

    static BadBlobTitle := "Не удалось прочитать реестр"
    static BadBlobBody  := "Текущий Scancode Map повреждён или нечитаем — ничего не изменено."

    static AlreadyOnTitle  := "Уже включено"
    static AlreadyOnBody   := "«Виртуализация» уже активна."
    static AlreadyOffTitle := "Уже выключено"
    static AlreadyOffBody  := "«Виртуализация» и так не активна."

    static MainTitle := "hypetype"
    static EditAltShift := "Символ с Alt+Shift"
    static EditAlt := "Символ с Alt"
    static EditSave := "Сохранить"
    static EditTitlePrefix := "Символы для «"
    static EditTitleSuffix := "»"
    static TooLongTitle := "Извините, у нас тут ограничение"
    static TooLongBody := "Максимум 32 символа на значение. Сократите и сохраните ещё раз."
    ; подсказка редактора построчно (для управляемого межстрочного интервала, см. Editor.LINE_SPACING).
    ; последняя строка содержит ссылку <a> на «даст ¢».
    static EditorHintLines := [
        "Символы вводятся с нажатым правым Alt, например, Alt + < и Alt + > дадут «кавычки».",
        "Если символ нарисован в верхней части кнопки, нужно нажать ещё и Shift, например, Alt + Shift + C <a id=`"donate`">даст ¢</a>",
        "Чтобы использовать автотипограф: выделите текст и нажмите Alt + Backspace",
    ]

    static TypoNoSelection := "Выделите текст"
    static TypoDone := "Типографировано ✓"
    static TypoAlready := "Уже типографировано ✓"
}
