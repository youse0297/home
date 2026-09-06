param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\AnisotropyBasics.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\AnisotropyBasicsValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Clamp-Value { param([double]$Value, [double]$Minimum, [double]$Maximum); return [Math]::Max($Minimum, [Math]::Min($Maximum, $Value)) }
function Saturate-Value { param([double]$Value); return Clamp-Value $Value 0.0 1.0 }
function Safe-Normalize {
    param($Value)
    [double]$x = $Value[0]; [double]$y = $Value[1]; [double]$z = $Value[2]
    [double]$lengthSquared = ($x * $x) + ($y * $y) + ($z * $z)
    if ($lengthSquared -le 0.0001) { return ,([double[]]@(0.0, 0.0, 0.0)) }
    [double]$inverseLength = 1.0 / [Math]::Sqrt($lengthSquared)
    [double]$normalizedX = $x * $inverseLength
    [double]$normalizedY = $y * $inverseLength
    [double]$normalizedZ = $z * $inverseLength
    return ,([double[]]@($normalizedX, $normalizedY, $normalizedZ))
}
function Cross-Vector {
    param($Left, $Right)
    [double]$crossX = ([double]$Left[1] * [double]$Right[2]) - ([double]$Left[2] * [double]$Right[1])
    [double]$crossY = ([double]$Left[2] * [double]$Right[0]) - ([double]$Left[0] * [double]$Right[2])
    [double]$crossZ = ([double]$Left[0] * [double]$Right[1]) - ([double]$Left[1] * [double]$Right[0])
    return ,([double[]]@($crossX, $crossY, $crossZ))
}
function Dot-Vector { param($Left, $Right); return ([double]$Left[0] * [double]$Right[0]) + ([double]$Left[1] * [double]$Right[1]) + ([double]$Left[2] * [double]$Right[2]) }
function Get-AnisotropicAlpha {
    param([double]$Roughness, [double]$Anisotropy)
    [double]$perceptualRoughness = [Math]::Max((Saturate-Value $Roughness), 0.045)
    [double]$alpha = [Math]::Max($perceptualRoughness * $perceptualRoughness, 0.002)
    [double]$sanitizedAnisotropy = Clamp-Value $Anisotropy -0.9 0.9
    [double]$aspect = [Math]::Sqrt([Math]::Max(1.0 - 0.9 * [Math]::Abs($sanitizedAnisotropy), 0.1))
    [double]$alphaLong = [Math]::Max($alpha / $aspect, 0.002)
    [double]$alphaShort = [Math]::Max($alpha * $aspect, 0.002)
    if ($sanitizedAnisotropy -ge 0.0) { return ,([double[]]@($alphaLong, $alphaShort)) }
    return ,([double[]]@($alphaShort, $alphaLong))
}
function Evaluate-Distribution {
    param($InputData)
    [double]$alphaT = [Math]::Max([double]$InputData.alphaTB[0], 0.002)
    [double]$alphaB = [Math]::Max([double]$InputData.alphaTB[1], 0.002)
    [double]$normalDotHalf = Saturate-Value ([double]$InputData.normalDotHalf)
    [double]$scaledTangent = [double]$InputData.tangentDotHalf / $alphaT
    [double]$scaledBitangent = [double]$InputData.bitangentDotHalf / $alphaB
    [double]$term = ($scaledTangent * $scaledTangent) + ($scaledBitangent * $scaledBitangent) + ($normalDotHalf * $normalDotHalf)
    return 1.0 / [Math]::Max([Math]::PI * $alphaT * $alphaB * $term * $term, 0.0001)
}
function Evaluate-Visibility {
    param($InputData)
    [double]$normalView = Saturate-Value ([double]$InputData.normalDotView)
    [double]$normalLight = Saturate-Value ([double]$InputData.normalDotLight)
    [double]$alphaT = [Math]::Max([double]$InputData.alphaTB[0], 0.002)
    [double]$alphaB = [Math]::Max([double]$InputData.alphaTB[1], 0.002)
    [double]$viewLength = [Math]::Sqrt(
        [Math]::Pow($alphaT * [double]$InputData.tangentDotView, 2.0) +
        [Math]::Pow($alphaB * [double]$InputData.bitangentDotView, 2.0) +
        ($normalView * $normalView)
    )
    [double]$lightLength = [Math]::Sqrt(
        [Math]::Pow($alphaT * [double]$InputData.tangentDotLight, 2.0) +
        [Math]::Pow($alphaB * [double]$InputData.bitangentDotLight, 2.0) +
        ($normalLight * $normalLight)
    )
    return 0.5 / [Math]::Max(($normalLight * $viewLength) + ($normalView * $lightLength), 0.0001)
}
function Orthogonalize-Tangent {
    param($NormalValue, $TangentValue)
    $normal = Safe-Normalize $NormalValue
    if ((Dot-Vector $normal $normal) -le 0.0001) { $normal = [double[]]@(0.0, 0.0, 1.0) }
    [double]$normalProjection = Dot-Vector $normal $TangentValue
    [double]$projectedX = [double]$TangentValue[0] - [double]$normal[0] * $normalProjection
    [double]$projectedY = [double]$TangentValue[1] - [double]$normal[1] * $normalProjection
    [double]$projectedZ = [double]$TangentValue[2] - [double]$normal[2] * $normalProjection
    $projected = [double[]]@(
        $projectedX,
        $projectedY,
        $projectedZ
    )
    if ((Dot-Vector $projected $projected) -gt 0.0001) { return ,(Safe-Normalize $projected) }
    $reference = if ([Math]::Abs([double]$normal[2]) -lt 0.999) { [double[]]@(0.0, 0.0, 1.0) } else { [double[]]@(0.0, 1.0, 0.0) }
    return ,(Safe-Normalize (Cross-Vector $reference $normal))
}
function Apply-Anisotropy {
    param($InputData)
    $normal = Safe-Normalize $InputData.normal
    $tangent = Orthogonalize-Tangent $normal $InputData.tangent
    [double]$tangentSign = if ([double]$InputData.tangent[3] -lt 0.0) { -1.0 } else { 1.0 }
    $cross = Safe-Normalize (Cross-Vector $normal $tangent)
    [double]$bitangentX = $tangentSign * [double]$cross[0]
    [double]$bitangentY = $tangentSign * [double]$cross[1]
    [double]$bitangentZ = $tangentSign * [double]$cross[2]
    $bitangent = [double[]]@($bitangentX, $bitangentY, $bitangentZ)
    [double]$rotation = Clamp-Value ([double]$InputData.rotation) (-[Math]::PI) ([Math]::PI)
    [double]$sine = [Math]::Sin($rotation); [double]$cosine = [Math]::Cos($rotation)
    [double]$rotatedTangentX = $cosine * [double]$tangent[0] + $sine * [double]$bitangent[0]
    [double]$rotatedTangentY = $cosine * [double]$tangent[1] + $sine * [double]$bitangent[1]
    [double]$rotatedTangentZ = $cosine * [double]$tangent[2] + $sine * [double]$bitangent[2]
    $rotatedTangent = Safe-Normalize ([double[]]@(
        $rotatedTangentX,
        $rotatedTangentY,
        $rotatedTangentZ
    ))
    [double]$rotatedBitangentX = -$sine * [double]$tangent[0] + $cosine * [double]$bitangent[0]
    [double]$rotatedBitangentY = -$sine * [double]$tangent[1] + $cosine * [double]$bitangent[1]
    [double]$rotatedBitangentZ = -$sine * [double]$tangent[2] + $cosine * [double]$bitangent[2]
    $rotatedBitangent = Safe-Normalize ([double[]]@(
        $rotatedBitangentX,
        $rotatedBitangentY,
        $rotatedBitangentZ
    ))
    return ,([double[]]@(
        $rotatedTangent[0], $rotatedTangent[1], $rotatedTangent[2],
        $rotatedBitangent[0], $rotatedBitangent[1], $rotatedBitangent[2],
        (Clamp-Value ([double]$InputData.anisotropy) -0.9 0.9)
    ))
}
function Add-Check { param([string]$Id, [bool]$Pass, [string]$Detail, [double]$MaximumError = 0.0); $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail; maximumError = $MaximumError }) }
function Resolve-Asset { param([string]$Path); return Join-Path $projectPath ($Path -replace '/', '\') }

foreach ($fixture in @($manifest.fixtures)) {
    $actual = switch ([string]$fixture.function) {
        'TA_AnisotropicAlphaFromRoughness' { Get-AnisotropicAlpha ([double]$fixture.input.roughness) ([double]$fixture.input.anisotropy) }
        'TA_DistributionGGXAnisotropic' { Evaluate-Distribution $fixture.input }
        'TA_VisibilitySmithGGXAnisotropic' { Evaluate-Visibility $fixture.input }
        'TA_OrthogonalizeTangentWS' { Orthogonalize-Tangent $fixture.input.normal $fixture.input.tangent }
        'TA_ApplyAnisotropyToSurface' { Apply-Anisotropy $fixture.input }
    }
    $actualValues = @($actual); $expectedValues = @($fixture.expected); [double]$maximumError = 0.0
    for ($index = 0; $index -lt $expectedValues.Count; $index++) {
        $maximumError = [Math]::Max($maximumError, [Math]::Abs([double]$actualValues[$index] - [double]$expectedValues[$index]))
    }
    Add-Check -Id $fixture.id -Pass ($actualValues.Count -eq $expectedValues.Count -and $maximumError -le $tolerance) -Detail ('actual=' + ($actualValues -join ', ')) -MaximumError $maximumError
}

$source = Get-Content -LiteralPath (Resolve-Asset $manifest.source) -Raw
$typesSource = Get-Content -LiteralPath (Resolve-Asset $manifest.typesSource) -Raw
$inputSource = Get-Content -LiteralPath (Resolve-Asset $manifest.inputSource) -Raw
$lightingSource = Get-Content -LiteralPath (Resolve-Asset $manifest.lightingSource) -Raw
$consumer = Get-Content -LiteralPath (Resolve-Asset $manifest.consumer) -Raw
$material = Get-Content -LiteralPath (Resolve-Asset $manifest.material) -Raw
$profile = Get-Content -LiteralPath (Resolve-Asset $manifest.profile) -Raw
foreach ($symbol in @($manifest.publicSymbols)) { Add-Check -Id ('PUBLIC_SYMBOL_' + $symbol) -Pass ($source -match ('\b' + [Regex]::Escape([string]$symbol) + '\b')) -Detail ([string]$symbol) }
Add-Check 'SURFACE_FRAME_DATA' ($typesSource -match 'half3 tangentWS;' -and $typesSource -match 'half3 bitangentWS;' -and $typesSource -match 'half anisotropy;' -and $inputSource -match 'surface\.anisotropy = 0\.0h;') 'Surface data owns a stable zero-anisotropy frame baseline'
Add-Check 'ORTHONORMAL_FRAME_POLICY' ($source -match 'tangentWS - normal \* dot\(normal, tangentWS\)' -and $source -match 'tangentSign \* TA_SafeNormalize\(cross\(normal, tangent\)\)' -and $source -match 'sincos\(rotation') 'Final normal, tangent handedness and rotation define the anisotropy frame'
Add-Check 'SURFACE_ZERO_IDENTITY' ($source -match 'surface\.anisotropy = sanitizedAnisotropy;' -and $source -match 'if \(abs\(sanitizedAnisotropy\) <= TA_MIN_DENOMINATOR\)[\s\S]*?return;') 'Zero anisotropy exits before mutating the established normal and tangent frame'
Add-Check 'ISOTROPIC_FALLBACK' ($lightingSource -match 'TA_DistributionGGX\(normalDotHalf, roughness\)' -and $lightingSource -match 'TA_VisibilitySmithGGXCorrelated' -and $lightingSource -match 'if \(abs\(surface\.anisotropy\) > TA_MIN_DENOMINATOR\)') 'Zero anisotropy retains the established isotropic GGX branch'
Add-Check 'ANISOTROPIC_LIGHTING' ($lightingSource -match 'TA_AnisotropicAlphaFromRoughness' -and $lightingSource -match 'TA_DistributionGGXAnisotropic' -and $lightingSource -match 'TA_VisibilitySmithGGXAnisotropic') 'Direct light consumes anisotropic alpha, distribution and visibility'
Add-Check 'CONSUMER_WIRING' ($consumer -match '_Anisotropy\("Anisotropy", Range\(-1, 1\)\) = 0' -and $consumer -match '_AnisotropyRotation' -and $consumer -match 'TA_ApplyAnisotropyToSurface\(' -and $consumer -match '_Anisotropy \* \(1\.0h - snowMask\)') 'BasePass exposes anisotropy, rotation and snow attenuation'
Add-Check 'MATERIAL_PARAMETERS' ($material -match '_Anisotropy: 0\.65' -and $material -match '_AnisotropyRotation: 0\.35') 'Sample material serializes enabled anisotropy parameters'
Add-Check 'PROFILE_PARAMETERS' ($profile -match 'anisotropy: 0\.65' -and $profile -match 'anisotropyRotation: 0\.35') 'Sample profile serializes enabled anisotropy parameters'

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
if ($failed.Count -gt 0) { throw ('Anisotropy basics validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', ')) }
Write-Output 'UNITY_ANISOTROPY_BASICS: PASS'
Write-Output "Report: $ReportPath"
