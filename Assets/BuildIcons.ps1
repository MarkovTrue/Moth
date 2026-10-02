<#
    BuildIcons.ps1 - рисует иконки кнопок Moth из набора Lucide (лицензия ISC) в серые PNG.

    Генератор перенесён из VCLauncher (Assets/Icons/BuildLucideIcons.ps1). Исходные SVG
    берутся с unpkg (версия lucide-static закреплена ниже) и кешируются в Assets/Icons/,
    без сети используется кеш. Цвет PNG не важен: скин перекрашивает иконку по альфе.

    Иконка рисуется сразу в том размере, который просит рантайм (_FluentButton_Create), –
    скин масштабирует без сглаживания, и уменьшенная иконка теряет пиксели контура.

    Соответствие:
      settings-2  -> Themes/Icons/Settings.png  (кнопка настроек главного окна, 16 px)
      refresh-cw  -> Themes/Icons/Refresh.png   (проверка обновлений в настройках, 18 px)
      monitor, sun, moon -> SegSystem, SegLight, SegDark.png (сегмент темы в настройках, 14 px, как в VCLauncher)
      move-horizontal, move-vertical -> FieldWidth, FieldHeight.png (поля ширины и высоты в окне размеров, 14 px)
      arrow-down  -> Themes/Icons/NoEnlarge.png (кнопка «Не увеличивать» в окне размеров, 16 px: та же стрелка,
                     что ↓ в подписи пресета)

    После сборки скопировать PNG в MothPortable\Themes\Icons.
    Запуск: powershell -ExecutionPolicy Bypass -File Assets\BuildIcons.ps1
#>
param(
    [string]$Version = '1.17.0',
    [int]   $Size    = 64,
    [string]$Gray    = '909090',
    [double]$StrokePx = 2.0,  # ЦЕЛЕВАЯ толщина линии в пикселях вывода (одинакова для всех размеров)
    [int]   $Super    = 1     # 1 = нативный рендер в целевой размер (резче), >1 = суперсэмплинг
)

# RenderTargetBitmap requires an STA thread.
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    & powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File $PSCommandPath `
        -Version $Version -Size $Size -Gray $Gray -StrokePx $StrokePx -Super $Super
    exit $LASTEXITCODE
}

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Xaml

$AssetsDir = Split-Path -Parent $MyInvocation.MyCommand.Path                      # Source/Assets
$IconDir   = Join-Path (Split-Path -Parent $AssetsDir) 'Themes\Icons'           # Source/Themes/Icons

# sw – толщина линии в px вывода (null – общий $StrokePx), size – размер PNG в px.
$map = @(
    @{ name = 'settings-2'; out = (Join-Path $IconDir 'Settings.png') ; sw = 1.5  ; size = 16 },
    @{ name = 'refresh-cw'; out = (Join-Path $IconDir 'Refresh.png')  ; sw = 1.75 ; size = 18 },
    @{ name = 'monitor'        ; out = (Join-Path $IconDir 'SegSystem.png')   ; sw = $null ; size = 14 },
    @{ name = 'sun'            ; out = (Join-Path $IconDir 'SegLight.png')    ; sw = $null ; size = 14 },
    @{ name = 'moon'           ; out = (Join-Path $IconDir 'SegDark.png')     ; sw = $null ; size = 14 },
    @{ name = 'move-horizontal'; out = (Join-Path $IconDir 'FieldWidth.png')  ; sw = $null ; size = 14 },
    @{ name = 'move-vertical'  ; out = (Join-Path $IconDir 'FieldHeight.png') ; sw = $null ; size = 14 },
    @{ name = 'arrow-down'     ; out = (Join-Path $IconDir 'NoEnlarge.png')   ; sw = 1.5   ; size = 16 }
)

$rgb   = [System.Windows.Media.Color]::FromRgb(
            [Convert]::ToInt32($Gray.Substring(0,2),16),
            [Convert]::ToInt32($Gray.Substring(2,2),16),
            [Convert]::ToInt32($Gray.Substring(4,2),16))
$brush = New-Object System.Windows.Media.SolidColorBrush($rgb)
$brush.Freeze()

function Get-Attr([string]$attrs, [string]$name) {
    $m = [regex]::Match($attrs, $name + '="([\d.\-]+)"')
    if ($m.Success) { return [double]$m.Groups[1].Value }
    return $null
}

function Render-Svg([string]$svg, [string]$outPng, $swOverride, [int]$renderSize) {
    $vb = [regex]::Match($svg, 'viewBox="0 0 ([\d.]+) ([\d.]+)"')
    $vw = if ($vb.Success) { [double]$vb.Groups[1].Value } else { 24.0 }
    # Толщина задаётся в пикселях вывода и переводится в единицы viewBox: scale (renderSize/vw)
    # позже домножит обратно, поэтому линия выходит ровно $px при ЛЮБОМ размере иконки.
    # На 14px штрих в 2px съедает рисунок (crop, scan): там держим 1px,
    # на кнопочных 16px и выше остаётся общая толщина.
    $px = if ($renderSize -le 14) { 1.0 } else { $StrokePx }
    if ($null -ne $swOverride) { $px = [double]$swOverride }
    $sw = $px * $vw / $renderSize

    $pen = New-Object System.Windows.Media.Pen($brush, $sw)
    $pen.StartLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen.EndLineCap   = [System.Windows.Media.PenLineCap]::Round
    $pen.LineJoin     = [System.Windows.Media.PenLineJoin]::Round

    $geos = New-Object System.Collections.Generic.List[System.Windows.Media.Geometry]
    $dots = New-Object System.Collections.Generic.List[System.Windows.Media.Geometry] # мелкие круги -> заливка
    foreach ($mm in [regex]::Matches($svg, '<path\b[^>]*\bd="([^"]+)"')) {
        $geos.Add([System.Windows.Media.Geometry]::Parse($mm.Groups[1].Value))
    }
    foreach ($mm in [regex]::Matches($svg, '<rect\b([^>]*)>')) {
        $a = $mm.Groups[1].Value
        $x = Get-Attr $a '\bx'; $y = Get-Attr $a '\by'
        $w = Get-Attr $a 'width'; $h = Get-Attr $a 'height'
        $rx = Get-Attr $a '\brx'; if ($null -eq $rx) { $rx = 0 }
        $rect = New-Object System.Windows.Rect($x, $y, $w, $h)
        $geos.Add((New-Object System.Windows.Media.RectangleGeometry($rect, $rx, $rx)))
    }
    foreach ($mm in [regex]::Matches($svg, '<circle\b([^>]*)>')) {
        $a = $mm.Groups[1].Value
        $cx = Get-Attr $a 'cx'; $cy = Get-Attr $a 'cy'; $r = Get-Attr $a '\br'
        $eg = New-Object System.Windows.Media.EllipseGeometry((New-Object System.Windows.Point($cx, $cy)), $r, $r)
        if ($r -le 1.5) {
            # Точку заливаем, а не обводим. Радиус тянем до половины толщины штриха:
            # иначе r=1 в viewBox 24 даёт на 16px точку в 1.3px – на кнопке её не видно.
            $rDot = [Math]::Max($r, $sw / 2)
            $dots.Add((New-Object System.Windows.Media.EllipseGeometry((New-Object System.Windows.Point($cx, $cy)), $rDot, $rDot)))
        } else { $geos.Add($eg) }
    }
    foreach ($mm in [regex]::Matches($svg, '<line\b([^>]*)>')) {
        $a = $mm.Groups[1].Value
        $p1 = New-Object System.Windows.Point((Get-Attr $a 'x1'), (Get-Attr $a 'y1'))
        $p2 = New-Object System.Windows.Point((Get-Attr $a 'x2'), (Get-Attr $a 'y2'))
        $geos.Add((New-Object System.Windows.Media.LineGeometry($p1, $p2)))
    }

    # Рендерим в увеличенном размере (суперсэмплинг), потом даунскейлим – гладкие, резкие края.
    $ss  = [Math]::Max(1, $Super)
    $big = [int]($renderSize * $ss)

    $dv = New-Object System.Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    $scale = $big / $vw
    $dc.PushTransform((New-Object System.Windows.Media.ScaleTransform($scale, $scale)))
    foreach ($g in $geos) { $dc.DrawGeometry($null, $pen, $g) }
    foreach ($g in $dots) { $dc.DrawGeometry($brush, $null, $g) } # заливка точек цветом штриха
    $dc.Pop()
    $dc.Close()

    $rtbBig = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($big, $big, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtbBig.Render($dv)

    if ($ss -gt 1) {
        # Качественный даунскейл big -> renderSize (HighQuality = Fant)
        $dv2 = New-Object System.Windows.Media.DrawingVisual
        $dc2 = $dv2.RenderOpen()
        [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($dv2, [System.Windows.Media.BitmapScalingMode]::HighQuality)
        $dc2.DrawImage($rtbBig, (New-Object System.Windows.Rect(0, 0, $renderSize, $renderSize)))
        $dc2.Close()
        $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($renderSize, $renderSize, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
        $rtb.Render($dv2)
    } else {
        $rtb = $rtbBig
    }

    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [System.IO.File]::Open($outPng, [System.IO.FileMode]::Create)
    try { $enc.Save($fs) } finally { $fs.Close() }
}

# SVG-исходники лежат в Assets/Icons/: это кеш и запас на случай работы без сети.
# Файл назван именем Lucide с большой буквы, без дефисов: move-horizontal -> MoveHorizontal.svg
$svgDir = Join-Path $AssetsDir 'Icons'
if (-not (Test-Path $svgDir)) { New-Item -ItemType Directory -Path $svgDir | Out-Null }

foreach ($it in $map) {
    $url = "https://unpkg.com/lucide-static@$Version/icons/$($it.name).svg"
    $svgName = (($it.name -split '-') | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ''
    $svgPath = Join-Path $svgDir ($svgName + '.svg')
    try {
        $svg = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content
        [System.IO.File]::WriteAllText($svgPath, $svg, [System.Text.UTF8Encoding]::new($false))
    } catch {
        if (Test-Path $svgPath) {
            $svg = [System.IO.File]::ReadAllText($svgPath)   # офлайн: берём сохранённый исходник
            Write-Host ("  {0,-14} (offline: используем Icons\{1}.svg)" -f $it.name, $svgName)
        } else {
            throw
        }
    }
    $renderSize = if ($null -ne $it.size) { [int]$it.size } else { $Size }
    Render-Svg $svg $it.out $it.sw $renderSize
    Write-Host ("  {0,-14} -> {1}  ({2}px)" -f $it.name, $it.out, $renderSize)
}
Write-Host "Lucide icons rendered (per-icon size, x$Super SS, #$Gray), version $Version"
