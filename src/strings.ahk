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
    static MenuEditor     := "Редактировать"

    static NoAdminTitle := "Требуются права администратора!"
    static NoAdminBody  := "Закройте и запустите программу от имени администратора для работы с «Виртуализацией»."

    static EnabledTitle := "Всё Чикаго!"
    static EnabledBody  := "«Виртуализация» включена! Перезагрузите компьютер ^_^ и печатайте символы в стиле hypetype."

    static DisabledTitle := "Всё по плану — но слегка грустненько"
    static DisabledBody  := "«Виртуализация» отключена T_T Перезагрузите компьютер для полного возврата к стандартному Alt."

    static ForeignTitle := "Правый Alt уже занят"
    static ForeignBody  := "Правый Alt уже переназначен другой программой. hypetype не будет это перезаписывать."

    static BadBlobTitle := "Не удалось прочитать реестр"
    static BadBlobBody  := "Текущий Scancode Map повреждён или нечитаем — ничего не изменено."

    static AlreadyOnTitle  := "Уже включено"
    static AlreadyOnBody   := "«Виртуализация» уже активна."
    static AlreadyOffTitle := "Уже выключено"
    static AlreadyOffBody  := "«Виртуализация» и так не активна."

    static BackupLine := "`n`nРезервная копия реестра (для отката двойным кликом):`n"

    static MainTitle := "hypetype"
    static EditAltShift := "Символ с Alt+Shift"
    static EditAlt := "Символ с Alt"
    static EditSave := "Сохранить"
    static EditTitlePrefix := "Символы для «"
    static EditTitleSuffix := "»"
    static TooLongTitle := "Слишком длинно"
    static TooLongBody := "Максимум 32 символа (кодпоинта) на значение. Сократи и сохрани ещё раз."
    static EditorHint := "Символы вводятся с нажатым правым Alt, например Alt + < и Alt + > дадут «кавычки».`nЕсли символ нарисован в верхней части кнопки, значит нужно нажать ещё и Shift, например Alt + Shift + C даст ¢"

    static TypoNoSelection := "Выделите текст"
    static TypoDone := "Типографировано ✓"
    static TypoAlready := "Уже типографировано ✓"
}
