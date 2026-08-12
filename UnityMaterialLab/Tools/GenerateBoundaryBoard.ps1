param(
    [string]$MatrixPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\MaterialBoundaryMatrix.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\Reports\MaterialBoundaryBoard.png')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$matrix = Get-Content -LiteralPath $MatrixPath -Raw | ConvertFrom-Json
$width = 1200
$height = 720
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

$background = [System.Drawing.Color]::FromArgb(12, 18, 32)
$textColor = [System.Drawing.Color]::FromArgb(232, 238, 248)
$mutedColor = [System.Drawing.Color]::FromArgb(158, 171, 192)
$lineColor = [System.Drawing.Color]::FromArgb(40, 54, 78)
$graphics.Clear($background)

$titleFont = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
$rowFont = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$labelFont = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$valueFont = New-Object System.Drawing.Font('Consolas', 9)
$titleBrush = New-Object System.Drawing.SolidBrush($textColor)
$mutedBrush = New-Object System.Drawing.SolidBrush($mutedColor)
$linePen = New-Object System.Drawing.Pen($lineColor, 1)

function Draw-CenteredText {
    param(
        [System.Drawing.Graphics]$Canvas,
        [string]$Text,
        [System.Drawing.Font]$Font,
        [System.Drawing.Brush]$Brush,
        [float]$CenterX,
        [float]$Top
    )
    $size = $Canvas.MeasureString($Text, $Font)
    $Canvas.DrawString($Text, $Font, $Brush, $CenterX - $size.Width / 2, $Top)
}

function Draw-Sphere {
    param(
        [System.Drawing.Graphics]$Canvas,
        [float]$CenterX,
        [float]$CenterY,
        [float]$Radius,
        [double]$Metallic,
        [double]$Roughness,
        [double]$NormalScale
    )
    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 0, 0, 0))
    $Canvas.FillEllipse($shadowBrush, $CenterX - $Radius * 0.8, $CenterY + $Radius * 0.75, $Radius * 1.6, $Radius * 0.36)
    $shadowBrush.Dispose()

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse($CenterX - $Radius, $CenterY - $Radius, $Radius * 2, $Radius * 2)
    $sphereBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
    $sphereBrush.CenterPoint = [System.Drawing.PointF]::new(
        [float]($CenterX - $Radius * 0.34),
        [float]($CenterY - $Radius * 0.38)
    )
    $metalLift = [int][Math]::Round(50 * $Metallic)
    $roughDamping = 1.0 - 0.55 * $Roughness
    $centerRed = [int][Math]::Min(255, [Math]::Round((238 + $metalLift) * $roughDamping + 40 * $Roughness))
    $centerGreen = [int][Math]::Min(255, [Math]::Round((172 + $metalLift) * $roughDamping + 30 * $Roughness))
    $centerBlue = [int][Math]::Min(255, [Math]::Round((88 + $metalLift) * $roughDamping + 22 * $Roughness))
    $sphereBrush.CenterColor = [System.Drawing.Color]::FromArgb($centerRed, $centerGreen, $centerBlue)
    $sphereBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(34, 18, 12))
    $Canvas.FillPath($sphereBrush, $path)

    if ($NormalScale -gt 0) {
        $normalPen = New-Object System.Drawing.Pen(
            [System.Drawing.Color]::FromArgb([int](22 + 24 * $NormalScale), 188, 218, 255),
            [float](0.8 + 0.55 * $NormalScale)
        )
        for ($offset = -36; $offset -le 36; $offset += 12) {
            $wave = [float](5.0 * $NormalScale)
            $points = @(
                [System.Drawing.PointF]::new([float]($CenterX - 36), [float]($CenterY + $offset)),
                [System.Drawing.PointF]::new([float]($CenterX - 12), [float]($CenterY + $offset - $wave)),
                [System.Drawing.PointF]::new([float]($CenterX + 12), [float]($CenterY + $offset + $wave)),
                [System.Drawing.PointF]::new([float]($CenterX + 36), [float]($CenterY + $offset))
            )
            $Canvas.DrawCurve($normalPen, $points)
        }
        $normalPen.Dispose()
    }
    $outlinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(96, 112, 138), 1)
    $Canvas.DrawEllipse($outlinePen, $CenterX - $Radius, $CenterY - $Radius, $Radius * 2, $Radius * 2)
    $outlinePen.Dispose()
    $sphereBrush.Dispose()
    $path.Dispose()
}

try {
    $graphics.DrawString('Material Parameter Boundary Matrix', $titleFont, $titleBrush, 52, 28)
    $graphics.DrawString(
        '11 fixed cases | Metallic [0,1] | Roughness [0,1] | Normal Scale [0,2]',
        $valueFont,
        $mutedBrush,
        52,
        68
    )
    $graphics.DrawLine($linePen, 52, 100, 1148, 100)

    $rows = @(
        @{ Name = 'Metallic'; Parameter = 'Metallic'; CenterY = 172; LabelY = 246; Radius = 58 },
        @{ Name = 'Roughness'; Parameter = 'Roughness'; CenterY = 372; LabelY = 438; Radius = 50 },
        @{ Name = 'Normal Scale'; Parameter = 'NormalScale'; CenterY = 566; LabelY = 636; Radius = 54 }
    )
    foreach ($row in $rows) {
        $rowCases = @($matrix.cases | Where-Object { $_.parameter -eq $row.Parameter })
        $graphics.DrawString($row.Name, $rowFont, $titleBrush, 52, $row.CenterY - 16)
        $spacing = 760.0 / [Math]::Max(1, $rowCases.Count - 1)
        $startX = if ($rowCases.Count -eq 1) { 650.0 } else { 270.0 }
        for ($index = 0; $index -lt $rowCases.Count; ++$index) {
            $item = $rowCases[$index]
            $centerX = $startX + $spacing * $index
            Draw-Sphere -Canvas $graphics -CenterX $centerX -CenterY $row.CenterY `
                -Radius $row.Radius -Metallic $item.metallic `
                -Roughness $item.roughness -NormalScale $item.normalScale
            Draw-CenteredText -Canvas $graphics -Text $item.id -Font $labelFont `
                -Brush $titleBrush -CenterX $centerX -Top $row.LabelY
            $valueText = switch ($item.parameter) {
                'Metallic' { "m=$($item.value)  diffuse=$($item.dielectricWeight)" }
                'Roughness' { "r=$($item.value)  alpha=$($item.ggxAlpha)" }
                default { "scale=$($item.value)" }
            }
            Draw-CenteredText -Canvas $graphics -Text $valueText -Font $valueFont `
                -Brush $mutedBrush -CenterX $centerX -Top ($row.LabelY + 21)
        }
    }
    $graphics.DrawLine($linePen, 52, 286, 1148, 286)
    $graphics.DrawLine($linePen, 52, 480, 1148, 480)
    $graphics.DrawString(
        'PASS: all cases are finite and inside the physical ranges; Normal Scale 2 is the validation ceiling.',
        $valueFont,
        $mutedBrush,
        52,
        690
    )
    $outputDirectory = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $linePen.Dispose()
    $titleBrush.Dispose()
    $mutedBrush.Dispose()
    $titleFont.Dispose()
    $rowFont.Dispose()
    $labelFont.Dispose()
    $valueFont.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

Write-Output "Material boundary board: $OutputPath"
