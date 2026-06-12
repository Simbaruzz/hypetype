# build_exe.ps1 — локальная сборка hypetype.exe (тестовая, для шеринга).
# Требует установленный AutoHotkey v2 + Ahk2Exe (идёт в комплекте с инсталлятором AHK).
# Выход: build_test\hypetype.exe
#
# Запуск:  powershell -ExecutionPolicy Bypass -File tools\build_exe.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$ahk2exe = Join-Path $env:ProgramFiles "AutoHotkey\Compiler\Ahk2Exe.exe"
$base    = Join-Path $env:ProgramFiles "AutoHotkey\v2\AutoHotkey64.exe"
if (-not (Test-Path $ahk2exe)) { throw "Ahk2Exe не найден: $ahk2exe" }
if (-not (Test-Path $base))    { throw "AutoHotkey64.exe (v2) не найден: $base" }

# короткое 8.3-имя для /base — обходим пробел в пути 'Program Files'
$fso = New-Object -ComObject Scripting.FileSystemObject
$baseShort = $fso.GetFile($base).ShortPath

New-Item -ItemType Directory -Force "build_test" | Out-Null
$out = "build_test\hypetype.exe"
if (Test-Path $out) { Remove-Item $out -Force }

# относительные пути (без пробелов) + короткий /base — иначе Ahk2Exe рвёт путь по пробелу
$ahkArgs = @('/in','src\hypetype.ahk','/out',$out,'/icon','assets\icon.ico','/base',$baseShort)
$p = Start-Process -FilePath $ahk2exe -ArgumentList $ahkArgs -Wait -PassThru
if (-not (Test-Path $out)) { throw "Сборка не удалась (Ahk2Exe exit $($p.ExitCode))" }
Write-Host "Готово: $out  ($([math]::Round((Get-Item $out).Length/1KB,1)) KB)"
