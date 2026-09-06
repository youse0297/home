param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\TransparencyRefraction.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\TransparencyRefractionValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Clamp-Value { param([double]$Value, [double]$Minimum, [double]$Maximum); return [Math]::Max($Minimum, [Math]::Min($Maximum, $Value)) }
function Saturate-Value { param([double]$Value); return Clamp-Value $Value 0.0 1.0 }
function Normalize-Vector {
    param($Value)
    [double]$x = $Value[0]; [double]$y = $Value[1]; [double]$z = $Value[2]
    [double]$length = [Math]::Sqrt(($x * $x) + ($y * $y) + ($z * $z))
    if ($length -le 0.0001) { return ,([double[]]@(0.0, 0.0, 0.0)) }
    [double]$normalizedX = $x / $length
    [double]$normalizedY = $y / $length
    [double]$normalizedZ = $z / $length
    return ,([double[]]@($normalizedX, $normalizedY, $normalizedZ))
}
function Dot-Vector { param($Left, $Right); return ([double]$Left[0] * [double]$Right[0]) + ([double]$Left[1] * [double]$Right[1]) + ([double]$Left[2] * [double]$Right[2]) }
function Get-DielectricF0 {
    param([double]$IndexOfRefraction)
    [double]$ior = Clamp-Value $IndexOfRefraction 1.0 2.5
    [double]$ratio = ($ior - 1.0) / ($ior + 1.0)
    return $ratio * $ratio
}
function Get-SchlickFresnel {
    param([double]$Cosine, [double]$ReflectanceAtNormal)
    [double]$oneMinusCosine = 1.0 - (Saturate-Value $Cosine)
    return (Saturate-Value $ReflectanceAtNormal) + (1.0 - (Saturate-Value $ReflectanceAtNormal)) * [Math]::Pow($oneMinusCosine, 5.0)
}
function Get-RefractionDirection {
    param($InputData)
    $normal = Normalize-Vector $InputData.normal
    $viewDirection = Normalize-Vector $InputData.viewDirection
    $incident = [double[]]@(-$viewDirection[0], -$viewDirection[1], -$viewDirection[2])
    [double]$eta = 1.0 / (Clamp-Value ([double]$InputData.indexOfRefraction) 1.0 2.5)
    [double]$incidentDotNormal = Dot-Vector $incident $normal
    [double]$radicand = 1.0 - $eta * $eta * (1.0 - $incidentDotNormal * $incidentDotNormal)
    [double]$scale = $eta * $incidentDotNormal + [Math]::Sqrt([Math]::Max($radicand, 0.0))
    [double]$refractedX = $eta * [double]$incident[0] - $scale * [double]$normal[0]
    [double]$refractedY = $eta * [double]$incident[1] - $scale * [double]$normal[1]
    [double]$refractedZ = $eta * [double]$incident[2] - $scale * [double]$normal[2]
    return ,(Normalize-Vector ([double[]]@($refractedX, $refractedY, $refractedZ)))
}
function Get-RefractionUV {
    param($InputData)
    $incident = Normalize-Vector $InputData.incidentDirectionVS
    $direction = Normalize-Vector $InputData.refractionDirectionVS
    [double]$incidentProjectionDepth = [Math]::Max([Math]::Abs([double]$incident[2]), 0.1)
    [double]$projectionDepth = [Math]::Max([Math]::Abs([double]$direction[2]), 0.1)
    [double]$scale = (Clamp-Value ([double]$InputData.strength) 0.0 0.1) * (Clamp-Value ([double]$InputData.thickness) 0.0 10.0)
    [double]$offsetX = ([double]$direction[0] / $projectionDepth - [double]$incident[0] / $incidentProjectionDepth) * $scale
    [double]$offsetY = ([double]$direction[1] / $projectionDepth - [double]$incident[1] / $incidentProjectionDepth) * $scale
    [double]$screenX = Saturate-Value ([double]$InputData.screenUV[0] + $offsetX)
    [double]$screenY = Saturate-Value ([double]$InputData.screenUV[1] + $offsetY)
    return ,([double[]]@($screenX, $screenY))
}
function Get-Transmittance {
    param($AbsorptionCoefficient, [double]$Thickness)
    [double]$opticalDepth = Clamp-Value $Thickness 0.0 10.0
    return ,([double[]]@(
        [Math]::Exp(-[Math]::Max([double]$AbsorptionCoefficient[0], 0.0) * $opticalDepth),
        [Math]::Exp(-[Math]::Max([double]$AbsorptionCoefficient[1], 0.0) * $opticalDepth),
        [Math]::Exp(-[Math]::Max([double]$AbsorptionCoefficient[2], 0.0) * $opticalDepth)
    ))
}
function Get-Composite {
    param($InputData)
    $transmittance = Get-Transmittance $InputData.absorptionCoefficient ([double]$InputData.thickness)
    [double]$transmittedRed = [Math]::Max([double]$InputData.opaqueSceneColor[0], 0.0) * [double]$transmittance[0]
    [double]$transmittedGreen = [Math]::Max([double]$InputData.opaqueSceneColor[1], 0.0) * [double]$transmittance[1]
    [double]$transmittedBlue = [Math]::Max([double]$InputData.opaqueSceneColor[2], 0.0) * [double]$transmittance[2]
    $transmitted = [double[]]@($transmittedRed, $transmittedGreen, $transmittedBlue)
    [double]$fresnel = Get-SchlickFresnel ([double]$InputData.normalDotView) (Get-DielectricF0 ([double]$InputData.indexOfRefraction))
    [double]$opacity = Saturate-Value ([double]$InputData.opacity)
    [double]$surfaceWeight = $opacity + (1.0 - $opacity) * $fresnel
    [double]$colorRed = [double]$transmitted[0] * (1.0 - $surfaceWeight) + [Math]::Max([double]$InputData.surfaceLighting[0], 0.0) * $surfaceWeight
    [double]$colorGreen = [double]$transmitted[1] * (1.0 - $surfaceWeight) + [Math]::Max([double]$InputData.surfaceLighting[1], 0.0) * $surfaceWeight
    [double]$colorBlue = [double]$transmitted[2] * (1.0 - $surfaceWeight) + [Math]::Max([double]$InputData.surfaceLighting[2], 0.0) * $surfaceWeight
    return ,([double[]]@(
        $transmittedRed, $transmittedGreen, $transmittedBlue,
        [double]$transmittance[0], [double]$transmittance[1], [double]$transmittance[2],
        $fresnel, $surfaceWeight,
        $colorRed, $colorGreen, $colorBlue
    ))
}
function Add-Check { param([string]$Id, [bool]$Pass, [string]$Detail, [double]$MaximumError = 0.0); $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail; maximumError = $MaximumError }) }
function Resolve-Asset { param([string]$Path); return Join-Path $projectPath ($Path -replace '/', '\') }

foreach ($fixture in @($manifest.fixtures)) {
    $actual = switch ([string]$fixture.function) {
        'TA_DielectricF0FromIOR' { [double[]]@((Get-DielectricF0 ([double]$fixture.input.indexOfRefraction))) }
        'TA_EvaluateRefractionDirectionWS' { Get-RefractionDirection $fixture.input }
        'TA_EvaluateRefractionUV' { Get-RefractionUV $fixture.input }
        'TA_EvaluateBeerLambertTransmittance' { Get-Transmittance $fixture.input.absorptionCoefficient ([double]$fixture.input.thickness) }
        'TA_EvaluateTransparencyRefraction' { Get-Composite $fixture.input }
    }
    $actualValues = @($actual); $expectedValues = @($fixture.expected); [double]$maximumError = 0.0
    for ($index = 0; $index -lt $expectedValues.Count; $index++) {
        $maximumError = [Math]::Max($maximumError, [Math]::Abs([double]$actualValues[$index] - [double]$expectedValues[$index]))
    }
    Add-Check -Id $fixture.id -Pass ($actualValues.Count -eq $expectedValues.Count -and $maximumError -le $tolerance) -Detail ('actual=' + ($actualValues -join ', ')) -MaximumError $maximumError
}

$source = Get-Content -LiteralPath (Resolve-Asset $manifest.source) -Raw
$shader = Get-Content -LiteralPath (Resolve-Asset $manifest.shader) -Raw
$material = Get-Content -LiteralPath (Resolve-Asset $manifest.material) -Raw
$pipelineAsset = Get-Content -LiteralPath (Resolve-Asset $manifest.pipelineAsset) -Raw
foreach ($symbol in @($manifest.publicSymbols)) { Add-Check -Id ('PUBLIC_SYMBOL_' + $symbol) -Pass ($source -match ('\b' + [Regex]::Escape([string]$symbol) + '\b')) -Detail ([string]$symbol) }
Add-Check 'PURE_SOURCE_MODULE' ($source -notmatch 'TEXTURE2D|SAMPLER|Packages/' -and $source -match 'exp\(-coefficient \* opticalDepth\)') 'Module owns numeric optics without renderer resources'
Add-Check 'TRANSPARENT_RENDER_STATE' ($shader -match '"RenderType" = "Transparent"' -and $shader -match '"Queue" = "Transparent"' -and $shader -match 'Blend One Zero' -and $shader -match 'ZWrite Off') 'Transparent queue overwrites its already-composited color and does not write depth'
Add-Check 'OPAQUE_SCENE_SAMPLE' ($shader -match 'DeclareOpaqueTexture\.hlsl' -and $shader -match 'SampleSceneColor\(refractionUV\)' -and $shader -match 'TA_EvaluateRefractionUV\(') 'Shader samples the URP opaque texture at bounded refracted UV'
Add-Check 'OPTICAL_INTEGRATION' ($shader -match 'TA_EvaluateRefractionDirectionWS\(' -and $shader -match 'TA_EvaluateTransparencyRefraction\(' -and $shader -match '_IndexOfRefraction' -and $shader -match '_AbsorptionCoefficient') 'Shader wires Snell direction, dielectric Fresnel and absorption'
Add-Check 'OPAQUE_TEXTURE_ENABLED' ($pipelineAsset -match 'm_RequireOpaqueTexture: 1') 'URP asset enables the opaque scene-color copy required by refraction'
Add-Check 'MATERIAL_CONTRACT' ($material -match 'm_Name: MAT_TransparentRefraction' -and $material -match 'guid: 6f8a3d72c4be4910a65f2e1b9d307c84' -and $material -match 'm_CustomRenderQueue: 3000' -and $material -match '_IndexOfRefraction: 1\.5' -and $material -match '_Opacity: 0\.12' -and $material -match '_Thickness: 0\.6') 'Sample material serializes the transparent shader and bounded optical defaults'

$failed = @($checks | Where-Object { -not $_.pass })
$maximumError = ($checks | ForEach-Object { [double]$_.maximumError } | Measure-Object -Maximum).Maximum
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report = [ordered]@{
    status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }
    version = $manifest.version
    sourceLibraryVersion = $manifest.sourceLibraryVersion
    publicSymbolCount = @($manifest.publicSymbols).Count
    dependencyCount = @($manifest.dependencies).Count
    fixtureCount = @($manifest.fixtures).Count
    invariantCount = @($manifest.invariants).Count
    limitationCount = @($manifest.limitations).Count
    tolerance = $tolerance
    maximumError = $maximumError
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    failures = @($failed | ForEach-Object { $_.id })
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
if ($failed.Count -gt 0) { throw ('Transparency and refraction validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', ')) }
Write-Output 'UNITY_TRANSPARENCY_REFRACTION: PASS'
Write-Output "Report: $ReportPath"
