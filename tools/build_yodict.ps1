# build_yodict.ps1 — генерация src/yodict.ahk (частотный сабсет безусловных ё-слов).
#
# Источники (скачиваются во временную папку, в репозиторий/exe не попадают):
#   - safe-словарь eyo-kernel (MIT): однозначные ё-словоформы, формат основа(суф|...)
#   - частотный список словоформ ru_full (OpenSubtitles, hermitdave/FrequencyWords)
#
# Алгоритм: для каждой safe-парадигмы берём макс. частоту её форм (нормализация ё->е),
# сортируем по частоте, набираем самые частотные парадигмы до бюджета по размеру.
# Итог — подмножество MIT-словаря; частотный список используется лишь как фильтр.
#
# Запуск:  powershell -ExecutionPolicy Bypass -File tools\build_yodict.ps1 [-BudgetKB 150]

param([int]$BudgetKB = 150)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tmp  = Join-Path $env:TEMP "hypetype_yo"
New-Item -ItemType Directory -Force $tmp | Out-Null
$safe = Join-Path $tmp "safe.txt"
$full = Join-Path $tmp "ru_full.txt"
$dst  = Join-Path $root "src\yodict.ahk"

if (-not (Test-Path $safe)) {
    Write-Host "Скачиваю safe-словарь eyo-kernel..."
    Invoke-WebRequest "https://cdn.jsdelivr.net/npm/eyo-kernel/dict/safe.txt" -OutFile $safe
}
if (-not (Test-Path $full)) {
    Write-Host "Скачиваю частотный список ru_full (~28 МБ)..."
    Invoke-WebRequest "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/ru/ru_full.txt" -OutFile $full
}

$ru=[char]0x0451; $ye=[char]0x0435
$lines = [System.IO.File]::ReadAllLines($safe, [System.Text.Encoding]::UTF8)
$formToIdx = New-Object 'System.Collections.Generic.Dictionary[string,int]'
$score = New-Object 'System.Int64[]' $lines.Count
for ($i=0; $i -lt $lines.Count; $i++) {
    $ln=$lines[$i]; if ($ln -eq '') { continue }
    if ($ln -match '^(.*)\((.*)\)$') { $stem=$matches[1]; $sufs=$matches[2] -split '\|' } else { $stem=$ln; $sufs=@('') }
    foreach ($s in $sufs) { $key=($stem+$s).ToLower().Replace($ru,$ye); if (-not $formToIdx.ContainsKey($key)) { $formToIdx[$key]=$i } }
}
Write-Host "форм-ключей: $($formToIdx.Count)"

$sr = [System.IO.StreamReader]::new($full, [System.Text.Encoding]::UTF8)
while ($null -ne ($line = $sr.ReadLine())) {
    $sp=$line.IndexOf(' '); if ($sp -le 0) { continue }
    $w=$line.Substring(0,$sp); $idx=0
    if ($formToIdx.TryGetValue($w,[ref]$idx)) { $c=[int64]$line.Substring($sp+1); if ($c -gt $score[$idx]) { $score[$idx]=$c } }
}
$sr.Close()

$ranked = for ($i=0; $i -lt $lines.Count; $i++) { if ($score[$i] -gt 0) { [pscustomobject]@{ line=$lines[$i]; score=$score[$i] } } }
$ranked = $ranked | Sort-Object score -Descending
$budget = $BudgetKB*1024; $bytes=0; $sel=New-Object System.Collections.Generic.List[string]
foreach ($k in $ranked) { $lb=[System.Text.Encoding]::UTF8.GetByteCount($k.line)+1; if ($bytes+$lb -gt $budget) { continue }; $sel.Add($k.line); $bytes+=$lb }
$body = $sel | Sort-Object
$n = $body.Count

$header = @(
  '#Requires AutoHotkey v2.0',
  '',
  '; ============================================================================',
  ';  yodict.ahk - частотный сабсет безусловных ё-словоформ для ёфикатора (G8).',
  ';  Источник: eyo-kernel (MIT, github.com/e2yo/eyo-kernel), отфильтрован по',
  ';  частотности. Только однозначные слова (без омографов все/всё).',
  (';  Формат: основа(суф1|суф2|...) или одиночная форма. Парсится в EnsureYo. ' + $n + ' парадигм.'),
  ';  СГЕНЕРИРОВАНО tools/build_yodict.ps1 — править вручную не нужно.',
  '; ============================================================================',
  '',
  'Typograph.YO_RAW := "',
  '('
)
[System.IO.File]::WriteAllLines($dst, ($header + $body + @(')"')), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Готово: src/yodict.ahk — $n парадигм, $([math]::Round((Get-Item $dst).Length/1KB,1)) KB"
