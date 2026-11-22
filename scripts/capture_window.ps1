# Скриншот окна MyCactus (вариант 2 — «честный» скриншот живого приложения).
#
# Использование:
#   1. Запустить приложение:  flutter run -d windows
#   2. Дойти до нужного экрана (например, галерея растения с фото-паспортами)
#   3. Из корня репозитория:
#        powershell -File scripts\capture_window.ps1 -OutFile ".\screenshots\gallery_menu.png"
#
# Скрипт находит окно процесса my_cactus.exe, выводит его на передний план
# и сохраняет содержимое окна в PNG. Ничего устанавливать не нужно —
# используются System.Drawing и user32.dll из Windows.

param(
    [string]$OutFile = ".\my_cactus_window.png",
    [string]$ProcessName = "my_cactus",
    [int]$SettleMs = 400
)

Add-Type -AssemblyName System.Drawing

$signature = @'
[DllImport("user32.dll")] public static extern bool GetWindowRect(System.IntPtr hWnd, out RECT rect);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
'@
Add-Type -MemberDefinition $signature -Name Win32 -Namespace Native

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1

if (-not $proc) {
    Write-Error "Окно '$ProcessName' не найдено. Запустите приложение: flutter run -d windows"
    exit 1
}

$hwnd = $proc.MainWindowHandle

# Развернуть, если свёрнуто, и поднять на передний план
[Native.Win32]::ShowWindow($hwnd, 9) | Out-Null  # SW_RESTORE
[Native.Win32]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds $SettleMs

$rect = New-Object Native.Win32+RECT
[Native.Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

$width  = $rect.Right  - $rect.Left
$height = $rect.Bottom - $rect.Top

if ($width -le 0 -or $height -le 0) {
    Write-Error "Нулевой размер окна ($width x $height) — окно свёрнуто?"
    exit 1
}

$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
$g.Dispose()

$outDir = Split-Path -Parent $OutFile
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

$bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Output "Сохранено: $OutFile ($width x $height)"
