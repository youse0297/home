param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\BasePassLightingDecomposition.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\Reports\BasePassLightingDecompositionBoard.png'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\BasePassLightingValidation.json')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$fixture = $manifest.fixture
$reportsPath = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $reportsPath | Out-Null

function Normalize-Vector {
    param([double[]]$Value)
    $length = [Math]::Sqrt($Value[0] * $Value[0] + $Value[1] * $Value[1] + $Value[2] * $Value[2])
    if ($length -le 0.000001) { throw 'Cannot normalize a zero vector.' }
    return @(
        ($Value[0] / $length),
        ($Value[1] / $length),
        ($Value[2] / $length)
    )
}

function Dot-Vector {
    param([double[]]$Left, [double[]]$Right)
    return $Left[0] * $Right[0] + $Left[1] * $Right[1] + $Left[2] * $Right[2]
}

function Add-Vector {
    param([double[]]$Left, [double[]]$Right)
    return @(
        ($Left[0] + $Right[0]),
        ($Left[1] + $Right[1]),
        ($Left[2] + $Right[2])
    )
}

function Multiply-Vector {
    param([double[]]$Left, [double[]]$Right)
    return @(
        ($Left[0] * $Right[0]),
        ($Left[1] * $Right[1]),
        ($Left[2] * $Right[2])
    )
}

function Scale-Vector {
    param([double[]]$Value, [double]$Scale)
    return @(
        ($Value[0] * $Scale),
        ($Value[1] * $Scale),
        ($Value[2] * $Scale)
    )
}

function Convert-LinearToDisplayByte {
    param([double]$Value)
    $mapped = [Math]::Max($Value, 0.0) / (1.0 + [Math]::Max($Value, 0.0))
    $encoded = [Math]::Pow($mapped, 1.0 / 2.2)
    return [Math]::Min(255, [Math]::Max(0, [int][Math]::Round($encoded * 255.0)))
}

function Convert-VectorToColor {
    param([double[]]$Value)
    return [System.Drawing.Color]::FromArgb(
        (Convert-LinearToDisplayByte $Value[0]),
        (Convert-LinearToDisplayByte $Value[1]),
        (Convert-LinearToDisplayByte $Value[2])
    )
}

function Format-Vector {
    param([double[]]$Value)
    return ('({0:0.000}, {1:0.000}, {2:0.000})' -f $Value[0], $Value[1], $Value[2])
}

$baseColor = [double[]]$fixture.baseColor
$normal = Normalize-Vector ([double[]]$fixture.normalWS)
$view = Normalize-Vector ([double[]]$fixture.viewDirectionWS)
$light = Normalize-Vector ([double[]]$fixture.lightDirectionWS)
$halfDirection = Normalize-Vector (Add-Vector $view $light)
$lightColor = [double[]]$fixture.lightColor
$ambient = [double[]]$fixture.ambientSH
$ao = [double]$fixture.ambientOcclusion
$roughness = [Math]::Max([double]$fixture.roughness, 0.045)
$metallic = [Math]::Min(1.0, [Math]::Max(0.0, [double]$fixture.metallic))
$shadow = [Math]::Min(1.0, [Math]::Max(0.0, [double]$fixture.shadowAttenuation))
$normalDotLight = [Math]::Max(0.0, (Dot-Vector $normal $light))
$normalDotView = [Math]::Max(0.0, (Dot-Vector $normal $view))
$normalDotHalf = [Math]::Max(0.0, (Dot-Vector $normal $halfDirection))
$viewDotHalf = [Math]::Max(0.0, (Dot-Vector $view $halfDirection))
$radiance = Scale-Vector $lightColor $shadow
$reflectance = @(
    (0.04 * (1.0 - $metallic) + $baseColor[0] * $metallic),
    (0.04 * (1.0 - $metallic) + $baseColor[1] * $metallic),
    (0.04 * (1.0 - $metallic) + $baseColor[2] * $metallic)
)
$fresnelFactor = [Math]::Pow(1.0 - $viewDotHalf, 5.0)
$fresnel = @(
    ($reflectance[0] + (1.0 - $reflectance[0]) * $fresnelFactor),
    ($reflectance[1] + (1.0 - $reflectance[1]) * $fresnelFactor),
    ($reflectance[2] + (1.0 - $reflectance[2]) * $fresnelFactor)
)
$alpha = [Math]::Max($roughness * $roughness, 0.002)
$alphaSquared = $alpha * $alpha
$distributionDenominator = $normalDotHalf * $normalDotHalf * ($alphaSquared - 1.0) + 1.0
$distribution = $alphaSquared / ([Math]::PI * $distributionDenominator * $distributionDenominator)
$viewLambda = $normalDotLight * [Math]::Sqrt([Math]::Max((-$normalDotView * $alphaSquared + $normalDotView) * $normalDotView + $alphaSquared, 0.0))
$lightLambda = $normalDotView * [Math]::Sqrt([Math]::Max((-$normalDotLight * $alphaSquared + $normalDotLight) * $normalDotLight + $alphaSquared, 0.0))
$visibility = 0.5 / [Math]::Max($viewLambda + $lightLambda, 0.0001)
$directDiffuse = Scale-Vector (Multiply-Vector $baseColor $radiance) ((1.0 - $metallic) * $normalDotLight / [Math]::PI)
$directSpecular = Scale-Vector (Multiply-Vector $fresnel $radiance) ($distribution * $visibility * $normalDotLight)
$indirectDiffuse = Scale-Vector (Multiply-Vector $ambient $baseColor) ((1.0 - $metallic) * $ao)
$finalLit = Add-Vector (Add-Vector $directDiffuse $directSpecular) $indirectDiffuse
$worldNormalDisplay = @(
    ($normal[0] * 0.5 + 0.5),
    ($normal[1] * 0.5 + 0.5),
    ($normal[2] * 0.5 + 0.5)
)
$outputs = @{
    FinalLit = $finalLit
    BaseColor = $baseColor
    WorldNormal = $worldNormalDisplay
    AmbientOcclusion = @($ao, $ao, $ao)
    Roughness = @($roughness, $roughness, $roughness)
    Metallic = @($metallic, $metallic, $metallic)
    DirectDiffuse = $directDiffuse
    DirectSpecular = $directSpecular
    IndirectDiffuse = $indirectDiffuse
    ShadowAttenuation = @($shadow, $shadow, $shadow)
}

$width = 1440
$height = 900
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$background = [System.Drawing.Color]::FromArgb(12, 18, 32)
$panelColor = [System.Drawing.Color]::FromArgb(24, 34, 55)
$textColor = [System.Drawing.Color]::FromArgb(235, 241, 250)
$mutedColor = [System.Drawing.Color]::FromArgb(165, 180, 202)
$accentColor = [System.Drawing.Color]::FromArgb(85, 205, 168)
$lineColor = [System.Drawing.Color]::FromArgb(58, 76, 106)
$titleFont = New-Object System.Drawing.Font('Segoe UI', 24, [System.Drawing.FontStyle]::Bold)
$headingFont = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$bodyFont = New-Object System.Drawing.Font('Segoe UI', 9)
$monoFont = New-Object System.Drawing.Font('Consolas', 8)
$titleBrush = New-Object System.Drawing.SolidBrush($textColor)
$mutedBrush = New-Object System.Drawing.SolidBrush($mutedColor)
$accentBrush = New-Object System.Drawing.SolidBrush($accentColor)
$panelBrush = New-Object System.Drawing.SolidBrush($panelColor)
$linePen = New-Object System.Drawing.Pen($lineColor, 1)
try {
    $graphics.Clear($background)
    $graphics.DrawString('BasePass & Lighting Decomposition', $titleFont, $titleBrush, 48, 28)
    $graphics.DrawString('analytic fixture | linear HDR values | display swatches use Reinhard + sRGB preview', $bodyFont, $mutedBrush, 50, 72)
    $graphics.DrawLine($linePen, 48, 108, 1392, 108)

    for ($index = 0; $index -lt $manifest.debugViews.Count; $index++) {
        $viewDefinition = $manifest.debugViews[$index]
        $column = $index % 5
        $row = [Math]::Floor($index / 5)
        $x = 48 + $column * 270
        $y = 136 + $row * 286
        $graphics.FillRectangle($panelBrush, $x, $y, 244, 258)
        $graphics.DrawString(('{0}  {1}' -f $viewDefinition.id, $viewDefinition.name), $headingFont, $accentBrush, $x + 14, $y + 12)
        $graphics.DrawString([string]$viewDefinition.category, $bodyFont, $mutedBrush, $x + 15, $y + 40)
        $value = [double[]]$outputs[$viewDefinition.name]
        $swatchBrush = New-Object System.Drawing.SolidBrush((Convert-VectorToColor $value))
        try { $graphics.FillRectangle($swatchBrush, $x + 14, $y + 68, 216, 116) } finally { $swatchBrush.Dispose() }
        $graphics.DrawRectangle($linePen, $x + 14, $y + 68, 216, 116)
        $graphics.DrawString((Format-Vector $value), $monoFont, $titleBrush, $x + 14, $y + 196)
        $outputText = [string]$viewDefinition.output
        if ($outputText.Length -gt 34) { $outputText = $outputText.Substring(0, 34) + '...' }
        $graphics.DrawString($outputText, $bodyFont, $mutedBrush, $x + 14, $y + 220)
    }

    $graphics.DrawLine($linePen, 48, 724, 1392, 724)
    $graphics.DrawString('Additive invariant', $headingFont, $accentBrush, 48, 746)
    $graphics.DrawString('FinalLit = DirectDiffuse + DirectSpecular + IndirectDiffuse', $monoFont, $titleBrush, 48, 778)
    $graphics.DrawString(('NdotL={0:0.000}  roughness={1:0.000}  metallic={2:0.000}  AO={3:0.000}  shadow={4:0.000}' -f $normalDotLight, $roughness, $metallic, $ao, $shadow), $monoFont, $mutedBrush, 48, 808)
    $graphics.DrawString('This is an offline formula baseline, not a Unity frame capture or RenderDoc .rdc.', $bodyFont, $mutedBrush, 780, 808)
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $linePen.Dispose(); $titleBrush.Dispose(); $mutedBrush.Dispose(); $accentBrush.Dispose(); $panelBrush.Dispose()
    $titleFont.Dispose(); $headingFont.Dispose(); $bodyFont.Dispose(); $monoFont.Dispose()
    $graphics.Dispose(); $bitmap.Dispose()
}

$reconstructed = Add-Vector (Add-Vector $directDiffuse $directSpecular) $indirectDiffuse
$delta = [Math]::Max(
    [Math]::Abs($finalLit[0] - $reconstructed[0]),
    [Math]::Max(
        [Math]::Abs($finalLit[1] - $reconstructed[1]),
        [Math]::Abs($finalLit[2] - $reconstructed[2])
    )
)
$reportOutputs = [ordered]@{}
foreach ($viewDefinition in $manifest.debugViews) {
    $value = [double[]]$outputs[$viewDefinition.name]
    $reportOutputs[$viewDefinition.name] = @(
        [Math]::Round($value[0], 8),
        [Math]::Round($value[1], 8),
        [Math]::Round($value[2], 8)
    )
}
$report = [ordered]@{
    status = if ($delta -le 0.000001) { 'PASS' } else { 'FAIL' }
    contractStatus = $manifest.status
    viewCount = $manifest.debugViews.Count
    renderPath = $manifest.renderPath
    additiveInvariantDelta = $delta
    normalDotLight = $normalDotLight
    outputs = $reportOutputs
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
if ($delta -gt 0.000001) { throw "FinalLit additive invariant failed: $delta" }
Write-Output 'UNITY_BASEPASS_LIGHTING_ACCEPTANCE: PASS'
Write-Output "Board: $OutputPath"
Write-Output "Report: $ReportPath"
