#Requires AutoHotkey v2.0
#Include ..\src\strings.ahk
#Include ..\src\config.ahk
#Include ..\src\registry.ahk
#Include ..\src\input.ahk
#Include ..\src\editor.ahk
#Include ..\src\typograph.ahk
#Include ..\src\yodict.ahk

; =============================================================================
;  Автотесты чистых функций config.ahk (PLAN.md §8.1).
;  Запуск: AutoHotkey64.exe run_tests.ahk
;  Итог: лог в tests\_last_run.log, код выхода 1 при любом провале.
; =============================================================================

global TestLog := ""
global Failures := 0
global Total := 0

Assert(cond, name) {
    global TestLog, Failures, Total
    Total++
    if (cond)
        TestLog .= "  ok   " name "`n"
    else {
        TestLog .= "FAIL   " name "`n"
        Failures++
    }
}
AssertEq(got, want, name) {
    global TestLog, Failures, Total
    Total++
    if (got == want)
        TestLog .= "  ok   " name "`n"
    else {
        TestLog .= "FAIL   " name " | got=[" got "] want=[" want "]`n"
        Failures++
    }
}
Throws(fn) {
    try {
        fn()
    } catch {
        return true
    }
    return false
}

; ---------------------------------------------------------------------------
;  1. hex <-> строка: round-trip
; ---------------------------------------------------------------------------
RoundTrip(label, s) {
    hex := Config.StringToHex(s)
    back := Config.HexToString(hex)
    AssertEq(back, s, "round-trip: " label)
}

RoundTrip("ASCII", "Hello, world!")
RoundTrip("кириллица", "Привет, мир")
RoundTrip("спецсимволы ,=|;", ",=|;")
RoundTrip("комбинирующая диакритика", Chr(0x030B))
RoundTrip("эмодзи 1F60E", Chr(0x1F60E))
RoundTrip("пустая строка", "")

cp32 := ""
Loop 32
    cp32 .= "A"
RoundTrip("32 кодпоинта", cp32)

; точные значения
AssertEq(Config.StringToHex(Chr(0x1F60E)), "1F60E", "StringToHex эмодзи -> 1F60E")
AssertEq(Config.HexToString("0020+00B7+0020"), Chr(0x20) Chr(0xB7) Chr(0x20), "HexToString дивайдер ' · '")
AssertEq(Config.StringToHex(""), "", "StringToHex('') -> ''")
AssertEq(Config.HexToString(""), "", "HexToString('') -> ''")
AssertEq(Config.HexToString("20"), Chr(0x20), "HexToString принимает короткий hex '20'")

; невалидный hex -> отказ
Assert(Throws(() => Config.HexToString("GG")), "HexToString: не-hex -> исключение")
Assert(Throws(() => Config.HexToString("D800")), "HexToString: суррогат -> исключение")
Assert(Throws(() => Config.HexToString("110000")), "HexToString: вне диапазона -> исключение")

; ---------------------------------------------------------------------------
;  2. Парсер на эталоне FORMAT.md §9
; ---------------------------------------------------------------------------
ref := ""
    . "[hypetype]`n"
    . "version=2`n"
    . "`n"
    . "[Layout]`n"
    . "Digit1=00B9|00A1`n"
    . "Minus=2014|2013`n"
    . "KeyH=20BD|030B`n"
    . "Comma=00AB|201E`n"
    . "Backslash=007C|005C`n"
    . "Space=0020+00B7+0020|00A0`n"
    . "KeyT=1F60E|`n"
    . "`n"
    . "[Windows]`n"
    . "DiacriticTimeoutMs=3000`n"
    . "`n"
    . "[macOS]`n"
    . "DiacriticTimeoutMs=3000`n"

d := Config.ParseText(ref)
AssertEq(d["version"], 2, "парсер: version=2")
AssertEq(d["layout"]["KeyH"].alt, Chr(0x20BD), "парсер: KeyH alt = ₽")
AssertEq(d["layout"]["KeyH"].altShift, Chr(0x030B), "парсер: KeyH altShift = combining")
AssertEq(d["layout"]["Space"].alt, Chr(0x20) Chr(0xB7) Chr(0x20), "парсер: Space alt = ' · '")
AssertEq(d["layout"]["Space"].altShift, Chr(0xA0), "парсер: Space altShift = nbsp")
AssertEq(d["layout"]["KeyT"].alt, Chr(0x1F60E), "парсер: KeyT alt = эмодзи")
AssertEq(d["layout"]["KeyT"].altShift, "", "парсер: KeyT altShift пуст")
AssertEq(d["layout"]["Backslash"].alt, Chr(0x7C), "парсер: Backslash alt = |")
AssertEq(d["layout"]["Backslash"].altShift, Chr(0x5C), "парсер: Backslash altShift = \")
AssertEq(d["windows"]["DiacriticTimeoutMs"], "3000", "парсер: [Windows] DiacriticTimeoutMs")
Assert(d["foreign"].Length >= 1, "парсер: [macOS] ушёл в foreign")

; парсер срезает комментарий после значения (';' вставлен через Chr, чтобы не путать лексер исходника)
dc := Config.ParseText("[hypetype]`nversion=2`n[Layout]`nKeyD=00B0|2300   " Chr(0x3B) " коммент`n")
AssertEq(dc["layout"]["KeyD"].alt, Chr(0x00B0), "парсер: комментарий после значения срезается")

; BOM не мешает
dBom := Config.ParseText(Chr(0xFEFF) ref)
AssertEq(dBom["version"], 2, "парсер: файл с BOM читается")

; ---------------------------------------------------------------------------
;  3. Битые строки не валят парсинг
; ---------------------------------------------------------------------------
broken := ""
    . "[hypetype]`n"
    . "version=2`n"
    . "[Layout]`n"
    . "KeyA=00A7|21E7`n"          ; ок
    . "KeyB=ZZZZ|0041`n"          ; битый hex -> пропуск
    . "KeyC=0041|0042|0043`n"     ; два '|' -> пропуск
    . "KeyD=00B0|2300`n"          ; ок
db := Config.ParseText(broken)
Assert(db["layout"].Has("KeyA"), "битые: хорошая строка KeyA сохранена")
Assert(db["layout"].Has("KeyD"), "битые: хорошая строка KeyD сохранена")
Assert(!db["layout"].Has("KeyB"), "битые: KeyB (плохой hex) пропущена")
Assert(!db["layout"].Has("KeyC"), "битые: KeyC (два '|') пропущена")

; ---------------------------------------------------------------------------
;  4. Round-trip load->save->load: [macOS] и неизвестные ключи сохраняются
; ---------------------------------------------------------------------------
rt := ""
    . "[hypetype]`n"
    . "version=2`n"
    . "[Layout]`n"
    . "KeyH=20BD|030B`n"
    . "IntlBackslash=00A7|00B1`n"   ; неизвестный ключ -> round-trip
    . "[Windows]`n"
    . "DiacriticTimeoutMs=2500`n"
    . "[macOS]`n"
    . "DiacriticTimeoutMs=4000`n"
    . "SomeMacKey=1`n"

d1 := Config.ParseText(rt)
out := Config.BuildText(d1)
d2 := Config.ParseText(out)

AssertEq(d2["layout"]["KeyH"].alt, Chr(0x20BD), "round-trip: KeyH уцелел")
AssertEq(d2["windows"]["DiacriticTimeoutMs"], "2500", "round-trip: настройка Windows уцелела")

unknownFound := false
for raw in d2["layoutUnknown"]
    if InStr(raw, "IntlBackslash")
        unknownFound := true
Assert(unknownFound, "round-trip: неизвестный ключ IntlBackslash сохранён")

macFound := false
for sec in d2["foreign"] {
    if (sec.header = "[macOS]") {
        joined := ""
        for l in sec.lines
            joined .= l "`n"
        if (InStr(joined, "DiacriticTimeoutMs=4000") && InStr(joined, "SomeMacKey=1"))
            macFound := true
    }
}
Assert(macFound, "round-trip: секция [macOS] сохранена целиком")

; вывод без BOM, переводы строк CRLF
Assert(SubStr(out, 1, 1) != Chr(0xFEFF), "вывод: без BOM")
Assert(InStr(out, "`r`n") > 0, "вывод: CRLF")

; ---------------------------------------------------------------------------
;  5. Миграция legacy (FORMAT.md §8.1)
; ---------------------------------------------------------------------------
legacy := Chr(0xFEFF) "`n"
    . "[KeyMappings]`n"
    . "SC002=¹,¡`n"
    . "SC023=₽," Chr(0x030B) "`n"   ; ₽ , combining double acute
    . "SC02B=|,\`n"                  ; пользовательский '|' слева
    . "SC014=™,`n"                   ; правый пуст
    . "SC029=," Chr(0x60) "`n"       ; левый пуст, правый backtick

Assert(Config.IsLegacy(legacy), "миграция: legacy распознан")
m := Config.MigrateLegacy(legacy)
AssertEq(m["version"], 2, "миграция: version=2")
AssertEq(m["layout"]["Digit1"].alt, Chr(0x00B9), "миграция: SC002 -> Digit1 alt ¹")
AssertEq(m["layout"]["Digit1"].altShift, Chr(0x00A1), "миграция: SC002 altShift ¡")
AssertEq(m["layout"]["KeyH"].alt, Chr(0x20BD), "миграция: SC023 -> KeyH alt ₽")
AssertEq(m["layout"]["KeyH"].altShift, Chr(0x030B), "миграция: SC023 altShift combining")
AssertEq(m["layout"]["Backslash"].alt, Chr(0x7C), "миграция: SC02B -> Backslash alt = |")
AssertEq(m["layout"]["Backslash"].altShift, Chr(0x5C), "миграция: SC02B altShift = \")
AssertEq(m["layout"]["KeyT"].alt, Chr(0x2122), "миграция: SC014 -> KeyT alt ™")
AssertEq(m["layout"]["KeyT"].altShift, "", "миграция: SC014 altShift пуст")
AssertEq(m["layout"]["Backquote"].alt, "", "миграция: SC029 -> Backquote alt пуст")
AssertEq(m["layout"]["Backquote"].altShift, Chr(0x60), "миграция: SC029 altShift = backtick")

; миграция -> сериализация -> парсинг: данные доезжают в новом формате
mout := Config.BuildText(m)
mp := Config.ParseText(mout)
AssertEq(mp["layout"]["KeyH"].alt, Chr(0x20BD), "миграция->save->load: KeyH уцелел")
AssertEq(mp["layout"]["Backslash"].alt, Chr(0x7C), "миграция->save->load: Backslash '|' уцелел")

; ---------------------------------------------------------------------------
;  6. Дефолтная раскладка
; ---------------------------------------------------------------------------
dd := Config.DefaultData()
AssertEq(dd["version"], 2, "дефолт: version=2")
AssertEq(dd["layout"]["KeyH"].alt, Chr(0x20BD), "дефолт: KeyH alt = ₽")
AssertEq(dd["layout"]["Comma"].alt, Chr(0x00AB), "дефолт: Comma alt = «")
AssertEq(dd["layout"]["Digit8"].altShift, Chr(0x2194), "дефолт: Digit8 Alt+Shift = ↔")
AssertEq(dd["layout"]["Space"].alt, Chr(0x00A0), "дефолт: Space Alt = неразрывный пробел")
Assert(!dd["layout"].Has("Backquote") || dd["layout"]["Backquote"].alt = "", "дефолт: Backquote alt пуст")
ddOut := Config.BuildText(dd)
Assert(InStr(ddOut, "[Layout]") && InStr(ddOut, "[Windows]"), "дефолт: сериализуется с секциями")
AssertEq(dd["typograph"]["Yo"], "0", "дефолт: [Typograph] Yo=0 при первом запуске")
Assert(dd["typograph"].Has("Quotes"), "дефолт: [Typograph] содержит группы")
Assert(InStr(ddOut, "[Typograph]"), "дефолт: [Typograph] записан в файл")

; порядок [Layout] = таблица §5, а не алфавит (FORMAT.md §7.3)
pDigit1 := InStr(ddOut, "`nDigit1=")
pDigit2 := InStr(ddOut, "`nDigit2=")
pBackslash := InStr(ddOut, "`nBackslash=")
Assert(pDigit1 > 0 && pDigit1 < pDigit2, "порядок: Digit1 раньше Digit2")
Assert(pDigit1 < pBackslash, "порядок: Digit1 раньше Backslash (порядок §5, не алфавит)")

; ---------------------------------------------------------------------------
;  7. Scancode Map: чистые функции блоба (PLAN.md §3.1, §8.1)
; ---------------------------------------------------------------------------
REF_OURS := "00000000000000000200000068E038E000000000"

AssertEq(BuildScancodeMap([{new: 0xE068, orig: 0xE038}]), REF_OURS, "blob: build нашей записи = эталон")

oe := ParseScancodeMap(REF_OURS)
AssertEq(oe.Length, 1, "blob: эталон -> 1 запись")
AssertEq(oe[1].new, 0xE068, "blob: new = E068")
AssertEq(oe[1].orig, 0xE038, "blob: orig = E038")
AssertEq(BuildScancodeMap(oe), REF_OURS, "blob: round-trip parse->build")

; нулевой блоб (0 записей)
AssertEq(ParseScancodeMap("00000000000000000100000000000000").Length, 0, "blob: нулевой -> []")
AssertEq(BuildScancodeMap([]), "00000000000000000100000000000000", "blob: build([]) -> нулевой блоб")

; чужая запись (CapsLock 3A -> LCtrl 1D) + добавление нашей
foreignBlob := BuildScancodeMap([{new: 0x001D, orig: 0x003A}])
fe := ParseScancodeMap(foreignBlob)
AssertEq(fe.Length, 1, "blob: чужая запись распарсилась")
AssertEq(ScancodeMap.ClassifyEntries(fe), "other", "blob: только чужая -> other")
fe.Push({new: 0xE068, orig: 0xE038})
me := ParseScancodeMap(BuildScancodeMap(fe))
AssertEq(me.Length, 2, "blob: добавили нашу -> 2 записи")
AssertEq(ScancodeMap.ClassifyEntries(me), "ours", "blob: смешанный с нашей -> ours")

; удаление только нашей из смешанного
kept := []
for e in me
    if !(e.orig = 0xE038 && e.new = 0xE068)
        kept.Push(e)
AssertEq(kept.Length, 1, "blob: удалили нашу -> осталась чужая")
AssertEq(kept[1].orig, 0x003A, "blob: уцелела именно чужая (CapsLock)")

; обрезанный/невалидный -> отказ
Assert(Throws(() => ParseScancodeMap("0000")), "blob: обрезанный -> исключение")
Assert(Throws(() => ParseScancodeMap(SubStr(REF_OURS, 1, 38))), "blob: длина != count -> исключение")
Assert(Throws(() => ParseScancodeMap("GG" SubStr(REF_OURS, 3))), "blob: не-hex -> исключение")

; классификация статусов
AssertEq(ScancodeMap.ClassifyEntries([{new: 0xE068, orig: 0xE038}]), "ours", "classify: ours")
AssertEq(ScancodeMap.ClassifyEntries([{new: 0x0000, orig: 0xE038}]), "foreign-ralt", "classify: правый Alt занят другим -> foreign-ralt")
AssertEq(ScancodeMap.ClassifyEntries([{new: 0x001D, orig: 0x003A}]), "other", "classify: other")
AssertEq(ScancodeMap.ClassifyEntries([]), "other", "classify: пусто -> other")

; ---------------------------------------------------------------------------
;  8. input.ahk: детектор диакритики и нормализация NFC (PLAN.md §4)
; ---------------------------------------------------------------------------
Assert(KeyInput.IsSingleCombining(Chr(0x0301)), "диакритика: одиночный combining acute -> true")
Assert(KeyInput.IsSingleCombining(Chr(0x030C)), "диакритика: одиночный combining caron -> true")
Assert(!KeyInput.IsSingleCombining("a"), "диакритика: обычная буква -> false")
Assert(!KeyInput.IsSingleCombining(""), "диакритика: пусто -> false")
Assert(!KeyInput.IsSingleCombining(Chr(0x0301) Chr(0x0302)), "диакритика: две метки -> false (выводится напрямую)")
Assert(!KeyInput.IsSingleCombining(Chr(0x0041)), "диакритика: 'A' (вне диапазона) -> false")

AssertEq(KeyInput.NormalizeNFC("e" Chr(0x0301)), Chr(0x00E9), "NFC: e + ◌́ -> é")
AssertEq(KeyInput.NormalizeNFC("g" Chr(0x030C)), Chr(0x01E7), "NFC: g + ◌̌ -> ǧ (пример из плана)")
AssertEq(KeyInput.NormalizeNFC("abc"), "abc", "NFC: ASCII без изменений")

; ---------------------------------------------------------------------------
;  9. editor.ahk: чистые помощники (PLAN.md §5)
; ---------------------------------------------------------------------------
AssertEq(Editor.CpCount("abc"), 3, "editor: CpCount ASCII")
AssertEq(Editor.CpCount(Chr(0x1F60E)), 1, "editor: CpCount эмодзи = 1 кодпоинт (не 2 code units)")
AssertEq(Editor.CpCount(Chr(0x1F60E) Chr(0x1F60E) "a"), 3, "editor: CpCount два эмодзи + ASCII")
AssertEq(Editor.CpCount(""), 0, "editor: CpCount пусто = 0")

cp33 := ""
Loop 33
    cp33 .= Chr(0x1F60E)
Assert(Editor.CpCount(cp33) > 32, "editor: 33 эмодзи считаются как >32 кодпоинтов")

AssertEq(Editor.Sanitize("a`r`nb"), "ab", "editor: Sanitize убирает CR/LF")
AssertEq(Editor.Sanitize("a,b|c=d;e"), "a,b|c=d;e", "editor: Sanitize не трогает ,|=;")

AssertEq(Editor.ButtonRepr(""), "", "editor: ButtonRepr пусто -> ''")
AssertEq(Editor.ButtonRepr(Chr(0x0301)), Chr(0x25CC) Chr(0x0301), "editor: ButtonRepr диакритика на ◌")
Assert(InStr(Editor.ButtonRepr("12345"), "…"), "editor: ButtonRepr длинной строки усечён с …")

; ---------------------------------------------------------------------------
;  10. typograph.ahk: группы G3/G4/G7 (TYPOGRAPH.md §5, §9). Каждый кейс —
;      с двойным прогоном на идемпотентность (§3).
; ---------------------------------------------------------------------------
SettingsWith(overrides) {
    s := Typograph.DefaultSettings()
    for k, v in overrides
        s[k] := v
    return s
}
TypoCase(input, expected, name, settings := "") {
    got := Typograph.Run(input, settings)
    AssertEq(got, expected, "typo: " name)
    AssertEq(Typograph.Run(got, settings), got, "typo idem: " name)
}
TypoNeg(input, name, settings := "") {
    AssertEq(Typograph.Run(input, settings), input, "typo neg: " name)
}

NB := Chr(0x00A0)
LED := Chr(0x2025)   ; ‥

; G3 — пунктуация
TypoCase("Текст...", "Текст…", "G3 троеточие")
TypoCase("Что???", "Что?", "G3 ??? -> ?")
TypoCase("Да!!!", "Да!", "G3 !!! -> !")
TypoCase("Правда!?", "Правда?!", "G3 !? -> ?!")
TypoCase("Серьёзно...?", "Серьёзно?" LED, "G3 ...? -> ?‥")
TypoCase("Ну...!", "Ну!" LED, "G3 ...! -> !‥")
TypoCase("Что?...", "Что?" LED, "G3 ?... -> ?‥")

; G7 — символы
TypoCase("(c)", "©", "G7 (c) -> ©")
TypoCase("(R)", "®", "G7 (R) -> ®")
TypoCase("(tm)", "™", "G7 (tm) -> ™")
TypoCase("+-", "±", "G7 +- -> ±")
TypoCase("№ 5", "№" NB "5", "G7 № 5 -> №НБ5")
TypoCase("№5", "№" NB "5", "G7 №5 -> №НБ5")

; G4 — пробелы
TypoCase("менее,меньше", "менее, меньше", "G4 пробел после запятой")
TypoCase("« привет »", "«привет»", "G4 пробелы внутри ёлочек")
TypoCase("текст , точка", "текст, точка", "G4 пробел перед запятой убран")
TypoCase("23 %", "23%", "G4 процент слитно (дефолт)")
TypoCase("abcd  efgh   ijkl", "abcd efgh ijkl", "G4 двойные пробелы схлопнуты")

; G1 — кавычки (автомат §4)
DQ := Chr(0x22)      ; "
SQ := Chr(0x27)      ; '
APO := Chr(0x2019)   ; ’
TypoCase(DQ "привет" DQ, "«привет»", "G1 простые кавычки")
TypoCase("«сказал " DQ "да" DQ "»", "«сказал „да“»", "G1 вложенные кавычки")
TypoCase(DQ "Монитор 21" DQ DQ, "«Монитор 21" DQ "»", "G1 дюйм внутри ёлочек")
TypoCase(DQ "-" DQ, "«-»", "G1 кавычки вокруг дефиса")
TypoCase("it" SQ "s", "it" APO "s", "G1 апостроф its")
TypoCase("d" SQ "Artagnan", "d" APO "Artagnan", "G1 апостроф dArtagnan")
TypoCase("«деньги.»", "«деньги».", "G1 точка за закрывающую кавычку")
TypoNeg("5" SQ "10" DQ, "G1 негатив: штрихи 5-10")
TypoNeg("диагональ 27" DQ, "G1 негатив: дюйм 27 после цифры")
TypoNeg("«сказал „да“»", "G1 негатив: уже вложенные ёлочки")
TypoCase("МТС " Chr(0x201C) "АртВиток" Chr(0x201D), "МТС «АртВиток»", "G1 лапки macOS “ ” -> ёлочки, пробел сохранён")

; G2 — тире
EN := Chr(0x2013)    ; –
TypoCase("- Это я", "—" NB "Это" NB "я", "G2 тире прямой речи (начало строки)")
TypoCase("гений и злодейство - две вещи", "гений и" NB "злодейство" NB "— две вещи", "G2 тире внутри текста")
TypoCase("Текст. - Это", "Текст. —" NB "Это", "G2 тире после точки")
TypoCase("2002-2009", "2002" EN "2009", "G2 диапазон чисел")
TypoCase("январь-март", "январь" EN "март", "G2 диапазон месяцев")
TypoCase("XI-XII", "XI" EN "XII", "G2 римский диапазон")
TypoNeg("по-русски", "G2 негатив: висячий дефис по-русски")
TypoNeg("12-05-2024", "G2 негатив: дата")
TypoNeg("2002" EN "2009", "G2 негатив: уже среднее тире")

; G5 — неразрывные пробелы
TypoCase("5 лет", "5" NB "лет", "G5 число + слово")
TypoCase("в Москве", "в" NB "Москве", "G5 короткий предлог")
TypoCase("сделал бы", "сделал" NB "бы", "G5 частица бы")
TypoCase("А.А. Иванов", "А.А." NB "Иванов", "G5 инициалы перед фамилией")
TypoCase("Петров К.П.", "Петров" NB "К.П.", "G5 фамилия перед инициалами")
TypoCase("г. Москва", "г." NB "Москва", "G5 сокращение г.")
TypoCase("ООО Ромашка", "ООО" NB "Ромашка", "G5 орг-форма")
TypoCase("работа и т.д.", "работа" NB "и" NB "т." NB "д.", "G5 и т.д.")
TypoCase("это был я.", "это был" NB "я.", "G5 последнее короткое слово")
TypoNeg("красивая ваза", "G5 негатив: нет коротких слов")
TypoCase("5 лет", "5 лет", "тумблер: Nbsp off", SettingsWith(Map("Nbsp", false)))

; G6 — числа и валюта
TypoCase("$ 109", "109" NB "$", "G6 знак до числа -> после с НБ")
TypoCase("109$", "109" NB "$", "G6 знак слитно -> через НБ")
TypoCase("20usd", "20" NB "$", "G6 код usd -> $")
TypoCase("2345123 $", "2" NB "345" NB "123" NB "$", "G6 группировка разрядов")
TypoCase("143.56 $", "143,56" NB "$", "G6 десятичная точка -> запятая")
TypoCase("100 руб.", "100" NB "₽", "G6 руб -> знак рубля")
TypoCase("45 руб. 5 коп.", "45,05" NB "₽", "G6 копейки в сумму")
TypoCase("5 тыс.", "5" NB "тыс.", "G6 тыс с точкой + НБ")
TypoCase("10 млн.", "10" NB "млн", "G6 млн без точки + НБ")
TypoCase("109$", "$" NB "109", "G6 позиция before", SettingsWith(Map("CurrencyPosition", "before")))
TypoNeg("2.5.1", "G6 негатив: версия не валюта")
TypoNeg("2026", "G6 негатив: год без валюты не группируется")

; Тумблеры
TypoCase("2002-2009", "2002-2009", "тумблер: Dashes off", SettingsWith(Map("Dashes", false)))
TypoCase("109$", "109$", "тумблер: Numbers off", SettingsWith(Map("Numbers", false)))
TypoCase("Текст...", "Текст...", "тумблер: Punct off", SettingsWith(Map("Punct", false)))
TypoCase("«сказал " Chr(0x22) "да" Chr(0x22) "»", "«сказал " Chr(0x22) "да" Chr(0x22) "»", "тумблер: Quotes off", SettingsWith(Map("Quotes", false)))
TypoCase("(c)", "(c)", "тумблер: Symbols off", SettingsWith(Map("Symbols", false)))
TypoCase("менее,меньше", "менее,меньше", "тумблер: SpaceClean off", SettingsWith(Map("SpaceClean", false)))
TypoCase("23 %", "23" Chr(0x202F) "%", "тумблер: PercentSpace=narrow", SettingsWith(Map("PercentSpace", "narrow")))

; Негативы (текст не должен меняться)
TypoNeg("143,56", "негатив: десятичная дробь")
TypoNeg("12:30", "негатив: время")
TypoNeg("1:0", "негатив: счёт")
TypoNeg("2.5.1", "негатив: версия")
TypoNeg("Что?" LED, "негатив: уже SBOL-стиль ?‥")
TypoNeg("кто-то", "негатив: дефис кто-то")

; G8 — ёфикатор (опционально, по демо-словарю)
yoSet := SettingsWith(Map("Yo", true))
TypoCase("елка", "ёлка", "G8 елка -> ёлка", yoSet)
TypoCase("Елка стоит", "Ёлка стоит", "G8 регистр Елка -> Ёлка", yoSet)
TypoCase("ЕЛКА", "ЁЛКА", "G8 caps ЕЛКА -> ЁЛКА", yoSet)
TypoCase("самолет летит", "самолёт летит", "G8 самолет -> самолёт (летит не в словаре)", yoSet)
TypoCase("еще солнечно", "ещё солнечно", "G8 еще -> ещё", yoSet)
TypoCase("ёлка", "ёлка", "G8 уже с ё идемпотентно", yoSet)
TypoNeg("красная роза", "G8 слова без ё не трогаются", yoSet)
TypoNeg("елка", "G8 по умолчанию выкл")
TypoCase("Артем", "Артём", "G8 имя Артем -> Артём", yoSet)
TypoCase("Семен встретил Федора", "Семён встретил Фёдора", "G8 имена в тексте", yoSet)
TypoNeg("эта тема важна", "G8 омограф тема (имя Тёма исключено) не трогается", yoSet)
TypoCase("полет", "полёт", "G8 полёт (добавлено вне отсечки)", yoSet)
TypoCase("объем", "объём", "G8 объём (добавлено вне отсечки)", yoSet)
TypoCase("поезд идет", "поезд идёт", "G8 идёт (добавлено вне отсечки)", yoSet)
TypoNeg("свет звезды", "G8 омограф звезды (род.п. ед.ч.) не трогается", yoSet)

; Золотой корпус §9.2 — фраза-пытка. Эталон = вывод по правилам G2/G5
; (лишние НБ в примере ТЗ были опиской владельца). НБ обязательны перед
; каждым тире внутри текста и после предлогов «про»/«от».
AC := Chr(0x0301)    ; комбинирующее ударение (Ми́нус)
LC := Chr(0x63)      ; латинская c (cимвол — гомоглиф не детектится)
tortIn := DQ "-" DQ " - это минус, читайте статью " DQ "про минус" DQ " ! Ми" AC "нус (от лат. minus " DQ "менее ,меньше" DQ ") - математический " LC "имвол " DQ " -" DQ " . Между тем ,внутри " DQ "елочек" DQ " дюймы остаются - " DQ "Монитор 21" DQ DQ "!"
tortOut := "«-»" NB "— это минус, читайте статью «про" NB "минус»! Ми" AC "нус (от" NB "лат. minus «менее, меньше»)" NB "— математический " LC "имвол «-». Между тем, внутри «елочек» дюймы остаются" NB "— «Монитор 21" DQ "»!"
TypoCase(tortIn, tortOut, "золотой корпус: фраза-пытка")

; ---------------------------------------------------------------------------
;  Итог
; ---------------------------------------------------------------------------
summary := "`n===== ИТОГ: " (Total - Failures) "/" Total " пройдено, провалов: " Failures " =====`n"
TestLog .= summary

logFile := A_ScriptDir "\_last_run.log"
if FileExist(logFile)
    FileDelete(logFile)
FileAppend(TestLog, logFile, "UTF-8")

ExitApp(Failures ? 1 : 0)
