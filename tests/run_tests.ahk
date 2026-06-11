#Requires AutoHotkey v2.0
#Include ..\src\config.ahk

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
Assert(!dd["layout"].Has("Backquote") || dd["layout"]["Backquote"].alt = "", "дефолт: Backquote alt пуст")
ddOut := Config.BuildText(dd)
Assert(InStr(ddOut, "[Layout]") && InStr(ddOut, "[Windows]"), "дефолт: сериализуется с секциями")

; порядок [Layout] = таблица §5, а не алфавит (FORMAT.md §7.3)
pDigit1 := InStr(ddOut, "`nDigit1=")
pDigit2 := InStr(ddOut, "`nDigit2=")
pBackslash := InStr(ddOut, "`nBackslash=")
Assert(pDigit1 > 0 && pDigit1 < pDigit2, "порядок: Digit1 раньше Digit2")
Assert(pDigit1 < pBackslash, "порядок: Digit1 раньше Backslash (порядок §5, не алфавит)")

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
