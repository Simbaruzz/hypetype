FileEncoding, UTF-8



;===================================================================== КАРТА СИМВОЛОВ ==============================================================
; Соответствие сканкодов отображаемым символам
global scanCodeToName := { "SC002": "1", "SC003": "2", "SC004": "3", "SC005": "4"
                        , "SC006": "5", "SC007": "6", "SC008": "7", "SC009": "8"
                        , "SC00A": "9", "SC00B": "0", "SC00C": "-", "SC00D": "="
                        , "SC010": "Q", "SC011": "W", "SC012": "E", "SC013": "R"
                        , "SC014": "T", "SC015": "Y", "SC016": "U", "SC017": "I"
                        , "SC018": "O", "SC019": "P", "SC01A": "[", "SC01B": "]"
                        , "SC01E": "A", "SC01F": "S", "SC020": "D", "SC021": "F"
                        , "SC022": "G", "SC023": "H", "SC024": "J", "SC025": "K"
                        , "SC026": "L", "SC027": ";", "SC028": "'", "SC02B": "\"
                        , "SC02C": "Z", "SC02D": "X", "SC02E": "C", "SC02F": "V"
                        , "SC030": "B", "SC031": "N", "SC032": "M", "SC033": ","
                        , "SC034": ".", "SC035": "/", "SC039": "␣", "SC029": "``"}

; Первый ряд (цифры и символы)
global Btn_SC002, Btn_SC003, Btn_SC004, Btn_SC005, Btn_SC006
global Btn_SC007, Btn_SC008, Btn_SC009, Btn_SC00A, Btn_SC00B
global Btn_SC00C, Btn_SC00D  ; Добавлены минус и равно

; Второй ряд (QWERTYUIOP[])
global Btn_SC010, Btn_SC011, Btn_SC012, Btn_SC013, Btn_SC014
global Btn_SC015, Btn_SC016, Btn_SC017, Btn_SC018, Btn_SC019
global Btn_SC01A, Btn_SC01B  ; Добавлены скобки

; Третий ряд (ASDFGHJKL;'\)
global Btn_SC01E, Btn_SC01F, Btn_SC020, Btn_SC021, Btn_SC022
global Btn_SC023, Btn_SC024, Btn_SC025, Btn_SC026, Btn_SC027
global Btn_SC028, Btn_SC02B  ; Добавлены кавычка и обратный слэш

; Четвёртый ряд (ZXCVBNM,./ и пробел)
global Btn_SC02C, Btn_SC02D, Btn_SC02E, Btn_SC02F, Btn_SC030
global Btn_SC031, Btn_SC032, Btn_SC033, Btn_SC034, Btn_SC035
global Btn_SC039, Btn_SC029  ; Добавлен пробел


; Массивы для клавиш каждого ряда (теперь содержат сканкоды)
row1 := ["SC002", "SC003", "SC004", "SC005", "SC006", "SC007", "SC008", "SC009", "SC00A", "SC00B", "SC00C", "SC00D"]
row2 := ["SC010", "SC011", "SC012", "SC013", "SC014", "SC015", "SC016", "SC017", "SC018", "SC019", "SC01A", "SC01B"]
row3 := ["SC01E", "SC01F", "SC020", "SC021", "SC022", "SC023", "SC024", "SC025", "SC026", "SC027", "SC028", "SC02B"]
row4 := ["SC02C", "SC02D", "SC02E", "SC02F", "SC030", "SC031", "SC032", "SC033", "SC034", "SC035", "SC039", "SC029"]

; Инициализация глобальных переменных
global configFile := A_ScriptDir . "\config.ini"
global keyMappings := {}
global buttons := {}
global currentKey := ""

; Создаём основное окно GUI
Gui, Main:New, +AlwaysOnTop +Border
Gui, Main:Color, FFFFFF


LoadSymbols() {
    global keyMappings, configFile, buttons, scanCodeToName
    FileEncoding, UTF-8

    if !FileExist(configFile) {
        ; Определяем раскладку по умолчанию (теперь с сканкодами)
defaultMapping := { "SC002": ["¹", "¡"]
                 , "SC003": ["²", "¹⁄₂"]
                 , "SC004": ["³", "¹⁄₃"]
                 , "SC005": ["$", "¹⁄₄"]
                 , "SC006": ["‰", " "]
                 , "SC007": ["↑", "̂"]      ; Combining Circumflex Accent
                 , "SC008": ["` ", "¿"]
                 , "SC009": ["∞", " "]
                 , "SC00A": ["←", "‹"]
                 , "SC00B": ["→", "›"]
                 , "SC00C": ["—", "–"]      ; минус
                 , "SC00D": ["≠", "±"]      ; равно
                 , "SC010": ["` ", "̆"]      ; Combining Breve
                 , "SC011": ["✓", "⌃"]
                 , "SC012": ["€", "⌥"]
                 , "SC013": ["®", ""]       Combining Circle Above
                 , "SC014": ["™", "̊"]
                 , "SC015": ["ѣ", "Ѣ"]
                 , "SC016": ["ѵ", "Ѵ"]
                 , "SC017": ["і", "І"]
                 , "SC018": ["ѳ", "Ѳ"]
                 , "SC019": ["′", "″"]
                 , "SC01A": ["[", "{"]     ; левая скобка
                 , "SC01B": ["]", "}"]     ; правая скобка
                 , "SC01E": ["≈", "⌘"]
                 , "SC01F": ["§", "⇧"]
                 , "SC020": ["°", "⌀"]
                 , "SC021": ["£", " "]
                 , "SC022": ["` ", "⊞"]
                 , "SC023": ["₽", "̋"]      ; Combining Double Acute Accent
                 , "SC024": ["„", " "]
                 , "SC025": ["“", "‘"]
                 , "SC026": ["”", "’"]
                 , "SC027": ["‘", "̈"]      ; Combining Diaeresis
                 , "SC028": ["’", " "]      ; апостроф
                 , "SC02B": ["|", "\"]      ; обратный слэш
                 , "SC02C": ["` ", "̧"]      ; Combining Cedilla
                 , "SC02D": ["×", "·"]
                 , "SC02E": ["©", "¢"]
                 , "SC02F": ["↓", "̌"]      ; Combining Caron
                 , "SC030": ["ß", "ẞ"]
                 , "SC031": ["` ", "̃"]      ; Combining Tilde
                 , "SC032": ["−", "•"]
                 , "SC033": ["«", "„"]
                 , "SC034": ["»", "“"]      ; dot
                 , "SC035": ["` ", "́"]      ; Combining Acute Accent
                 , "SC039": ["` ", "` "]      ; пробел
                 , "SC029": [" ", "``"] } 

        ; Записываем BOM с переводом строки
        FileAppend, % Chr(0xEF) . Chr(0xBB) . Chr(0xBF) . "`n", %configFile%, UTF-8

        ; Записываем заголовок секции
        FileAppend, [KeyMappings]`n, %configFile%, UTF-8

        ; Записываем дефолтные значения
        for scanCode, symbols in defaultMapping {
            writeString := symbols[1] . "," . symbols[2]
            FileAppend, %scanCode%=%writeString%`n, %configFile%, UTF-8
        }
       ; перезагружаем скрипт
        Run, %A_ScriptFullPath%
}

    ; Очищаем и заново заполняем keyMappings
    keyMappings := {}

    ; Читаем файл целиком
    FileRead, content, %configFile%

    ; Парсим содержимое
    inKeyMappings := false
    Loop, Parse, content, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "[KeyMappings]") {
            inKeyMappings := true
            continue
        }

        if (inKeyMappings && line != "") {
            pos := InStr(line, "=")
            if (pos) {
                scanCode := Trim(SubStr(line, 1, pos-1))
                value := Trim(SubStr(line, pos+1))

                symbolArray := StrSplit(value, ",")
                symbol1 := symbolArray[1]
                symbol2 := symbolArray.MaxIndex() >= 2 ? symbolArray[2] : ""

                keyMappings[scanCode] := [symbol1, symbol2]
            }
        }
    }

    ; Обновляем кнопки
    for scanCode, symbols in keyMappings {
        if (buttons.HasKey(scanCode)) {
            displayName := scanCodeToName[scanCode]
            newText := displayName . "`n" . symbols[2] . "`n" . symbols[1]
            GuiControl, Main:, % buttons[scanCode], %newText%
        }
    }
}


;================================================================ СОЗДАЕМ КНОПКИ =========================================================

; Объявляем глобальные переменные для размеров кнопок

        DPI := A_ScreenDPI  ; DPI основного монитора
	Scale := DPI / 96   ; DPI Scaling Factor (96 DPI = 100%)

	LogicalScreenWidth := A_ScreenWidth / Scale
	LogicalScreenHeight := A_ScreenHeight / Scale 

	global wbtn := LogicalScreenWidth * 0.03
	global hbtn := wbtn * 1.65

	global wfld := LogicalScreenWidth * 0.2
	global hfld := wfld * 0.25

	global spacing := LogicalScreenWidth * 0.002
	global margin := 5*spacing
	
	global FontNameX := "Cambria"
	global FontSizeY := Floor(LogicalScreenHeight * 0.014)

; Функция создания кнопки
CreateKeyButton(scanCode, x, y) {
    global keyMappings, buttons, wbtn, hbtn, scanCodeToName, FontNameX, spacing, margin, FontSizeY
    varName := "Btn_" . scanCode
    displayName := scanCodeToName[scanCode]
    symbol1 := keyMappings[scanCode][1]
    symbol2 := keyMappings[scanCode][2]
    buttonText := displayName . "`n" . symbol2 . "`n" . symbol1
    Gui, Main:Font, s%FontSizeY%, %FontNameX%
    Gui, Main:Add, Button, x%x% y%y% w%wbtn% h%hbtn% v%varName% gKeyClick, %buttonText%
    buttons[scanCode] := varName
}

; Создаём кнопки для каждого ряда
y := 5*spacing
for index, key in row1 {
    x := margin + (index-1)*(wbtn+spacing)  ;
    CreateKeyButton(key, x, y)
}

y += (hbtn + spacing)  ; Убираем знаки процента 
for index, key in row2 {
    x := margin + (index-1)*(wbtn+spacing)
    CreateKeyButton(key, x, y)
}

y += (hbtn + spacing)
for index, key in row3 {
    x := margin + (index-1)*(wbtn+spacing)
    CreateKeyButton(key, x, y)
}

y += (hbtn + spacing)
for index, key in row4 {
    x := margin + (index-1)*(wbtn+spacing)
    CreateKeyButton(key, x, y)
}


textWidth := wbtn * 12 + 11 * spacing
Gui, Main:Font, % "s" . Floor(FontSizeY * 0.732), %FontNameX%
Gui, Main:Add, Text, x%margin% w%textWidth% , Символы вводятся с нажатым правым Alt, например Alt + < и Alt + > дадут «кавычки».`nЕсли символ нарисован в верхней части кнопки, значит нужно нажать ещё и Shift, например Alt + Shift + C даст ¢`n


; Загружаем символы из config.ini
LoadSymbols()
return 

; Отображаем GUI
ShowEditor() {
Gui, Main:Show, , hypetype
}


; Обработчик клика по кнопке
KeyClick:
    clickedVarName := A_GuiControl
    scanCode := ""
    for sc, v in buttons {
        if (v = clickedVarName) {
            scanCode := sc
            break
        }
    }
    if (scanCode = "") {
        MsgBox, 16, Ошибка, Не удалось определить нажатую кнопку.
        return
    }

    symbols := keyMappings[scanCode]
    if (!symbols)
        symbols := [" ", ""]  ; Используем пробел как значение по умолчанию

;============================================================================= ОКНО РЕДАКТИРОВАНИЯ =============================================================
; Создаём окно редактирования
Gui, Edit:New, +AlwaysOnTop +Owner
Gui, Edit:Color, FFFFFF

; Заголовок окна
;Gui, Edit:Font, s16, %FontNameX%
;Gui, Edit:Add, Text,, % "Редактирование символов для """ . scanCodeToName[scanCode] . """";

; Метки с меньшим шрифтом
Gui, Edit:Font, s12, %FontNameX%
Gui, Edit:Add, Text,, Символ c Alt+Shift

; Поле ввода с другим размером
Gui, Edit:Font, s32, %FontNameX%
Gui, Edit:Add, Edit, vShiftSymbol w%wfld% h%hfld%, % symbols[2]

; Возвращаемся к размеру для меток
Gui, Edit:Font, s12, %FontNameX%
Gui, Edit:Add, Text,, Символ c Alt

; Второе поле ввода
Gui, Edit:Font, s32, %FontNameX%
Gui, Edit:Add, Edit, vNoShiftSymbol w%wfld% h%hfld%, % symbols[1]

; Кнопка с другим шрифтом
Gui, Edit:Font, s14, %FontNameX%
Gui, Edit:Add, Button, gSaveSymbols w%wfld% h%hfld%, Сохранить
Gui, Edit:Show, , % "Символы для «" . scanCodeToName[scanCode] . "»"
currentKey := scanCode
return


;============================================================ СОХРАНЕНИЕ ================================================================
; Обработчик сохранения символов
SaveSymbols:
    Gui, Edit:Submit
    NoShiftSymbol := (NoShiftSymbol = "") ? " " : NoShiftSymbol
    ShiftSymbol := (ShiftSymbol = "") ? "" : ShiftSymbol

    ; Создаем временный файл
    tempFile := A_ScriptDir . "\temp.ini"
    FileDelete, %tempFile%

    ; Записываем BOM в временный файл
    FileAppend, % Chr(0xEF) . Chr(0xBB) . Chr(0xBF) . "`n", %tempFile%, UTF-8

    ; Записываем заголовок
    FileAppend, [KeyMappings]`n, %tempFile%, UTF-8

    ; Обновляем keyMappings
    keyMappings[currentKey] := [NoShiftSymbol, ShiftSymbol]

    ; Записываем все значения
    for scanCode, symbols in keyMappings {
        writeString := symbols[1] . "," . symbols[2]
        FileAppend, %scanCode%=%writeString%`n, %tempFile%, UTF-8
    }

    ; Заменяем файл
    FileDelete, %configFile%
    FileMove, %tempFile%, %configFile%

    ; Обновляем текст на кнопке
    buttonVarName := buttons[currentKey]
    displayName := scanCodeToName[currentKey]
    newText := displayName . "`n" . ShiftSymbol . "`n" . NoShiftSymbol
    GuiControl, Main:, %buttonVarName%, %newText%

    Gui, Edit:Destroy
return
