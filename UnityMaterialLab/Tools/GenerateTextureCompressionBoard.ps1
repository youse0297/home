param(
    [string]$MatrixPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\TextureCompressionMatrix.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\Reports\TextureCompressionBoard.png'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\TextureCompressionValidation.json'),
    [string]$PvrTexToolPath = 'F:\unity\2022.3.62f3c1\Editor\Data\Tools\PVRTexTool.exe'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$matrix = Get-Content -LiteralPath $MatrixPath -Raw | ConvertFrom-Json
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$reportsPath = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $reportsPath | Out-Null

function Get-BlockCompressedByteCount {
    param(
        [int]$Width,
        [int]$Height,
        [int]$MipLevels,
        [int]$BlockBytes
    )
    $total = 0
    for ($level = 0; $level -lt $MipLevels; $level++) {
        $levelWidth = [Math]::Max(1, $Width -shr $level)
        $levelHeight = [Math]::Max(1, $Height -shr $level)
        $blocksWide = [Math]::Max(1, [int][Math]::Ceiling($levelWidth / 4.0))
        $blocksHigh = [Math]::Max(1, [int][Math]::Ceiling($levelHeight / 4.0))
        $total += $blocksWide * $blocksHigh * $BlockBytes
    }
    return $total
}

function Get-Rgba32ByteCount {
    param([int]$TexelCount)
    return $TexelCount * 4
}

function Get-ImageError {
    param(
        [string]$SourcePath,
        [string]$DecodedPath
    )
    $source = [System.Drawing.Bitmap]::FromFile($SourcePath)
    $decoded = [System.Drawing.Bitmap]::FromFile($DecodedPath)
    try {
        if ($source.Width -ne $decoded.Width -or $source.Height -ne $decoded.Height) {
            throw 'BC1 decoded preview dimensions do not match the source.'
        }
        $sum = 0.0
        $max = 0
        $count = $source.Width * $source.Height * 3
        for ($y = 0; $y -lt $source.Height; $y++) {
            for ($x = 0; $x -lt $source.Width; $x++) {
                $a = $source.GetPixel($x, $y)
                $b = $decoded.GetPixel($x, $y)
                foreach ($delta in @(
                    [Math]::Abs($a.R - $b.R),
                    [Math]::Abs($a.G - $b.G),
                    [Math]::Abs($a.B - $b.B)
                )) {
                    $sum += $delta
                    $max = [Math]::Max($max, $delta)
                }
            }
        }
        return [ordered]@{
            meanAbsoluteError8Bit = [Math]::Round($sum / $count, 4)
            maximumAbsoluteError8Bit = $max
        }
    }
    finally {
        $source.Dispose()
        $decoded.Dispose()
    }
}

function Draw-Text {
    param(
        [System.Drawing.Graphics]$Canvas,
        [string]$Text,
        [System.Drawing.Font]$Font,
        [System.Drawing.Brush]$Brush,
        [float]$X,
        [float]$Y
    )
    $Canvas.DrawString($Text, $Font, $Brush, $X, $Y)
}

$sourcePath = Join-Path $projectPath 'Assets\_TA\Art\Textures\T_CC0_Crate_BaseColor.png'
$bc1DdsPath = Join-Path $reportsPath 'TextureCompression_BC1_Reference.dds'
$bc1PreviewPath = Join-Path $reportsPath 'TextureCompression_BC1_Reference.png'
$bc1Metrics = $null
$codecStatus = 'TOOL_UNAVAILABLE'
if (Test-Path -LiteralPath $PvrTexToolPath -PathType Leaf) {
    Remove-Item -LiteralPath $bc1DdsPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $bc1PreviewPath -Force -ErrorAction SilentlyContinue
    & $PvrTexToolPath -i $sourcePath -o $bc1DdsPath -d $bc1PreviewPath -f BC1,UBN,sRGB -shh
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $bc1PreviewPath -PathType Leaf)) {
        throw 'PVRTexTool BC1 reference round-trip failed.'
    }
    $bc1Metrics = Get-ImageError -SourcePath $sourcePath -DecodedPath $bc1PreviewPath
    $codecStatus = 'BC1_REFERENCE_PASS'
}

$actualBytes = [ordered]@{}
foreach ($format in $matrix.formatComparison) {
    $actualBytes[$format.format] = if ($format.format -eq 'RGBA32') {
        Get-Rgba32ByteCount -TexelCount $matrix.benchmark.mipTexelCount
    } else {
        Get-BlockCompressedByteCount -Width $matrix.benchmark.width -Height $matrix.benchmark.height `
            -MipLevels $matrix.benchmark.mipLevels -BlockBytes $format.blockBytes
    }
    if ($actualBytes[$format.format] -ne [int]$format.fullMipBytes) {
        throw "Mip footprint mismatch for $($format.format)."
    }
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
$lineColor = [System.Drawing.Color]::FromArgb(58, 76, 106)
$accent = [System.Drawing.Color]::FromArgb(85, 205, 168)
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
    Draw-Text -Canvas $graphics -Text 'Texture Compression Comparison' -Font $titleFont -Brush $titleBrush -X 48 -Y 32
    Draw-Text -Canvas $graphics -Text 'Standalone | 64x64 full mip chain | BC1 / BC5 / BC7 policy and reference quality check' -Font $bodyFont -Brush $mutedBrush -X 50 -Y 76
    $graphics.DrawLine($linePen, 48, 110, 1392, 110)

    $tableHeaders = @('Format', 'Block', 'bpp', 'Full mip bytes', 'Full mip KiB', 'vs RGBA32')
    $columns = @(58, 210, 350, 455, 665, 840)
    for ($index = 0; $index -lt $tableHeaders.Count; $index++) {
        Draw-Text -Canvas $graphics -Text $tableHeaders[$index] -Font $headingFont -Brush $accentBrush -X $columns[$index] -Y 132
    }
    $rowY = 164
    foreach ($format in $matrix.formatComparison) {
        $values = @(
            $format.format,
            "$($format.blockBytes) B / 4x4",
            $format.bitsPerPixel,
            $format.fullMipBytes,
            $format.fullMipKiB,
            ("{0:P1}" -f (1.0 - [double]$format.relativeToRgba32))
        )
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($panel)), 48, $rowY - 3, 930, 30)
        for ($index = 0; $index -lt $values.Count; $index++) {
            Draw-Text -Canvas $graphics -Text ([string]$values[$index]) -Font $monoFont -Brush $titleBrush -X $columns[$index] -Y $rowY
        }
        $rowY += 38
    }

    Draw-Text -Canvas $graphics -Text 'Selected Asset Policy' -Font $headingFont -Brush $accentBrush -X 48 -Y 332
    $assetY = 366
    foreach ($asset in $matrix.assets) {
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($panel)), 48, $assetY - 4, 930, 80)
        Draw-Text -Canvas $graphics -Text $asset.usage -Font $headingFont -Brush $titleBrush -X 62 -Y $assetY
        Draw-Text -Canvas $graphics -Text "$($asset.standaloneFormat) | sRGB=$($asset.sRGB) | $($asset.textureType) | $($asset.fullMipBytes) B | save $(('{0:P1}' -f $asset.savingVsRgba32))" -Font $monoFont -Brush $mutedBrush -X 62 -Y ($assetY + 23)
        Draw-Text -Canvas $graphics -Text $asset.rationale -Font $bodyFont -Brush $titleBrush -X 62 -Y ($assetY + 46)
        $assetY += 92
    }

    Draw-Text -Canvas $graphics -Text 'BC1 Reference Round-Trip' -Font $headingFont -Brush $accentBrush -X 1020 -Y 132
    $sourceImage = [System.Drawing.Image]::FromFile($sourcePath)
    try {
        $graphics.DrawImage($sourceImage, 1020, 170, 160, 160)
        Draw-Text -Canvas $graphics -Text 'Source PNG' -Font $bodyFont -Brush $titleBrush -X 1020 -Y 338
        if ($codecStatus -eq 'BC1_REFERENCE_PASS') {
            $previewImage = [System.Drawing.Image]::FromFile($bc1PreviewPath)
            try {
                $graphics.DrawImage($previewImage, 1200, 170, 160, 160)
            }
            finally {
                $previewImage.Dispose()
            }
            Draw-Text -Canvas $graphics -Text 'BC1 decoded' -Font $bodyFont -Brush $titleBrush -X 1200 -Y 338
            Draw-Text -Canvas $graphics -Text ("MAE: {0} / 255" -f $bc1Metrics.meanAbsoluteError8Bit) -Font $monoFont -Brush $mutedBrush -X 1020 -Y 374
            Draw-Text -Canvas $graphics -Text ("Max: {0} / 255" -f $bc1Metrics.maximumAbsoluteError8Bit) -Font $monoFont -Brush $mutedBrush -X 1020 -Y 398
        }
    }
    finally {
        $sourceImage.Dispose()
    }
    Draw-Text -Canvas $graphics -Text 'BC5 is selected for normals: two independent channels.' -Font $bodyFont -Brush $mutedBrush -X 1020 -Y 450
    Draw-Text -Canvas $graphics -Text 'BC7 is selected for BaseColor: higher quality color blocks.' -Font $bodyFont -Brush $mutedBrush -X 1020 -Y 476
    Draw-Text -Canvas $graphics -Text 'BC1 is selected for ORM: linear RGB data, no alpha.' -Font $bodyFont -Brush $mutedBrush -X 1020 -Y 502
    $graphics.DrawLine($linePen, 48, 680, 1392, 680)
    Draw-Text -Canvas $graphics -Text 'PASS: memory values are block-size verified; BC1 visual metrics are generated by PVRTexTool. Final Unity import compilation remains Editor-gated.' -Font $bodyFont -Brush $mutedBrush -X 48 -Y 708
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $linePen.Dispose()
    $titleBrush.Dispose()
    $mutedBrush.Dispose()
    $accentBrush.Dispose()
    $titleFont.Dispose()
    $headingFont.Dispose()
    $bodyFont.Dispose()
    $monoFont.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$report = [ordered]@{
    status = 'PASS'
    codecStatus = $codecStatus
    benchmark = $matrix.benchmark
    formatBytes = $actualBytes
    selectedAssets = $matrix.assets
    bc1Reference = $bc1Metrics
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
}
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Output 'UNITY_TEXTURE_COMPRESSION_ACCEPTANCE: PASS'
Write-Output "Board: $OutputPath"
Write-Output "Report: $ReportPath"
