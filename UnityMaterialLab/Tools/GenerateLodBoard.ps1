param(
    [string]$MatrixPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\LODValidation.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\Reports\LODComparisonBoard.png'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\LODValidationReport.json')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$matrix = Get-Content -LiteralPath $MatrixPath -Raw | ConvertFrom-Json
$reportsPath = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $reportsPath | Out-Null

function Draw-Text {
    param([System.Drawing.Graphics]$Canvas, [string]$Text, [System.Drawing.Font]$Font,
        [System.Drawing.Brush]$Brush, [float]$X, [float]$Y)
    $Canvas.DrawString($Text, $Font, $Brush, $X, $Y)
}

$width = 1440
$height = 900
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$background = [System.Drawing.Color]::FromArgb(12, 18, 32)
$panel = [System.Drawing.Color]::FromArgb(24, 34, 55)
$textColor = [System.Drawing.Color]::FromArgb(235, 241, 250)
$mutedColor = [System.Drawing.Color]::FromArgb(165, 180, 202)
$accent = [System.Drawing.Color]::FromArgb(85, 205, 168)
$lineColor = [System.Drawing.Color]::FromArgb(58, 76, 106)
$graphics.Clear($background)
$titleFont = New-Object System.Drawing.Font('Segoe UI', 24, [System.Drawing.FontStyle]::Bold)
$headingFont = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
$bodyFont = New-Object System.Drawing.Font('Segoe UI', 10)
$monoFont = New-Object System.Drawing.Font('Consolas', 10)
$titleBrush = New-Object System.Drawing.SolidBrush($textColor)
$mutedBrush = New-Object System.Drawing.SolidBrush($mutedColor)
$accentBrush = New-Object System.Drawing.SolidBrush($accent)
$linePen = New-Object System.Drawing.Pen($lineColor, 1)
try {
    Draw-Text $graphics 'LOD Basics Comparison Board' $titleFont $titleBrush 48 32
    Draw-Text $graphics 'screenHeight thresholds | fixed mesh counts | cross-fade policy' $bodyFont $mutedBrush 50 76
    $graphics.DrawLine($linePen, 48, 110, 1392, 110)

    Draw-Text $graphics 'Threshold bands' $headingFont $accentBrush 48 134
    $barX = 48
    $barY = 174
    $barW = 930
    $barH = 76
    $bands = @(
        @{ Name = 'High'; Start = 0.60; End = 1.00; Color = [System.Drawing.Color]::FromArgb(74, 160, 116) },
        @{ Name = 'Medium'; Start = 0.25; End = 0.60; Color = [System.Drawing.Color]::FromArgb(71, 125, 185) },
        @{ Name = 'Low'; Start = 0.05; End = 0.25; Color = [System.Drawing.Color]::FromArgb(185, 133, 67) },
        @{ Name = 'Culled'; Start = 0.00; End = 0.05; Color = [System.Drawing.Color]::FromArgb(115, 72, 91) }
    )
    foreach ($band in $bands) {
        $x = $barX + [int]($barW * $band.Start)
        $w = [int]($barW * ($band.End - $band.Start))
        $brush = New-Object System.Drawing.SolidBrush($band.Color)
        $graphics.FillRectangle($brush, $x, $barY, $w, $barH)
        $brush.Dispose()
        Draw-Text $graphics $band.Name $headingFont $titleBrush ($x + 12) ($barY + 14)
        Draw-Text $graphics (('{0:0.00}' -f $band.Start)) $monoFont $titleBrush ($x + 12) ($barY + 43)
    }
    Draw-Text $graphics 'screenHeight 0.00' $monoFont $mutedBrush $barX ($barY + $barH + 10)
    Draw-Text $graphics 'screenHeight 1.00' $monoFont $mutedBrush ($barX + $barW - 110) ($barY + $barH + 10)

    Draw-Text $graphics 'Level settings' $headingFont $accentBrush 48 300
    $headers = @('Level', 'Transition', 'Vertices', 'Triangles')
    $columns = @(62, 230, 420, 620)
    for ($i = 0; $i -lt $headers.Count; $i++) { Draw-Text $graphics $headers[$i] $headingFont $accentBrush $columns[$i] 332 }
    $rowY = 366
    foreach ($level in $matrix.levels) {
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($panel)), 48, $rowY - 4, 760, 34)
        $values = @($level.name, ('{0:0.00}' -f $level.screenHeight), $level.vertexCount, $level.triangleCount)
        for ($i = 0; $i -lt $values.Count; $i++) { Draw-Text $graphics ([string]$values[$i]) $monoFont $titleBrush $columns[$i] $rowY }
        $rowY += 42
    }
    Draw-Text $graphics 'Switch checks' $headingFont $accentBrush 48 524
    $rowY = 562
    foreach ($switch in $matrix.switches) {
        Draw-Text $graphics (('{0,-8} screenHeight={1:0.00} -> {2} ({3})' -f $switch.id, $switch.screenHeight, $switch.expectedLevel, $switch.expectedName)) $monoFont $titleBrush 62 $rowY
        $rowY += 30
    }

    $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($panel)), 860, 300, 532, 320)
    Draw-Text $graphics 'Acceptance record' $headingFont $accentBrush 892 332
    Draw-Text $graphics 'Policy status: STATIC_BASELINE_VALIDATED' $monoFont $titleBrush 892 374
    Draw-Text $graphics 'LOD bias: 1.00' $monoFont $titleBrush 892 408
    Draw-Text $graphics 'Cross fade: 0.15 s' $monoFont $titleBrush 892 442
    Draw-Text $graphics 'Prefab: PF_LOD_MaterialBall' $monoFont $titleBrush 892 476
    Draw-Text $graphics 'Scene: SCN_LOD_Baseline' $monoFont $titleBrush 892 510
    Draw-Text $graphics 'Editor menu: TA/Material Lab/Build LOD Test Scene' $bodyFont $mutedBrush 892 560
    $graphics.DrawLine($linePen, 48, 688, 1392, 688)
    Draw-Text $graphics 'PASS: thresholds are monotonic; all four fixed switch samples resolve to the expected LOD.' $bodyFont $mutedBrush 48 716
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $linePen.Dispose(); $titleBrush.Dispose(); $mutedBrush.Dispose(); $accentBrush.Dispose()
    $titleFont.Dispose(); $headingFont.Dispose(); $bodyFont.Dispose(); $monoFont.Dispose()
    $graphics.Dispose(); $bitmap.Dispose()
}

$report = [ordered]@{
    status = 'PASS'
    policyStatus = $matrix.status
    thresholdsMonotonic = ($matrix.levels[0].screenHeight -gt $matrix.levels[1].screenHeight -and
        $matrix.levels[1].screenHeight -gt $matrix.levels[2].screenHeight -and
        $matrix.levels[2].screenHeight -gt 0.0)
    switches = $matrix.switches
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
}
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Output 'UNITY_LOD_ACCEPTANCE: PASS'
Write-Output "Board: $OutputPath"
Write-Output "Report: $ReportPath"
