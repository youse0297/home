param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\UnifiedMaterialInterface.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\UnifiedMaterialInterfaceValidation.json')
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
    [double]$lengthSquared = $x * $x + $y * $y + $z * $z
    [double]$inverseLength = 1.0 / [Math]::Sqrt([Math]::Max($lengthSquared, 0.0001))
    [double]$normalizedX = $x * $inverseLength
    [double]$normalizedY = $y * $inverseLength
    [double]$normalizedZ = $z * $inverseLength
    return ,([double[]]@($normalizedX, $normalizedY, $normalizedZ))
}
function Dot-Vector { param($Left, $Right); return ([double]$Left[0] * [double]$Right[0]) + ([double]$Left[1] * [double]$Right[1]) + ([double]$Left[2] * [double]$Right[2]) }
function Cross-Vector {
    param($Left, $Right)
    [double]$x = [double]$Left[1] * [double]$Right[2] - [double]$Left[2] * [double]$Right[1]
    [double]$y = [double]$Left[2] * [double]$Right[0] - [double]$Left[0] * [double]$Right[2]
    [double]$z = [double]$Left[0] * [double]$Right[1] - [double]$Left[1] * [double]$Right[0]
    return ,([double[]]@($x, $y, $z))
}
function Add-Vector {
    param($Left, $Right)
    [double]$x = [double]$Left[0] + [double]$Right[0]
    [double]$y = [double]$Left[1] + [double]$Right[1]
    [double]$z = [double]$Left[2] + [double]$Right[2]
    return ,([double[]]@($x, $y, $z))
}
function Resolve-Normal {
    param($NormalTS, $NormalWS, $TangentWS)
    $normal = Normalize-Vector $NormalWS
    $tangent = Normalize-Vector ([double[]]@([double]$TangentWS[0], [double]$TangentWS[1], [double]$TangentWS[2]))
    [double]$sign = if ([double]$TangentWS[3] -lt 0.0) { -1.0 } else { 1.0 }
    $cross = Cross-Vector $normal $tangent
    [double]$bitangentX = $sign * [double]$cross[0]
    [double]$bitangentY = $sign * [double]$cross[1]
    [double]$bitangentZ = $sign * [double]$cross[2]
    $bitangent = [double[]]@($bitangentX, $bitangentY, $bitangentZ)
    [double]$x = [double]$NormalTS[0] * $tangent[0] + [double]$NormalTS[1] * $bitangent[0] + [double]$NormalTS[2] * $normal[0]
    [double]$y = [double]$NormalTS[0] * $tangent[1] + [double]$NormalTS[1] * $bitangent[1] + [double]$NormalTS[2] * $normal[1]
    [double]$z = [double]$NormalTS[0] * $tangent[2] + [double]$NormalTS[1] * $bitangent[2] + [double]$NormalTS[2] * $normal[2]
    return ,(Normalize-Vector ([double[]]@($x, $y, $z)))
}
function Get-SurfaceFrame {
    param($NormalWS, $TangentWS, [double]$Anisotropy, [double]$Rotation)
    $normal = Normalize-Vector $NormalWS
    [double]$sanitizedAnisotropy = Clamp-Value $Anisotropy -0.9 0.9
    if ([Math]::Abs($sanitizedAnisotropy) -le 0.0001) {
        return [ordered]@{ normal = $normal; tangent = [double[]]@(1.0, 0.0, 0.0); bitangent = [double[]]@(0.0, 1.0, 0.0); anisotropy = $sanitizedAnisotropy }
    }
    [double]$projection = Dot-Vector $normal $TangentWS
    [double]$projectedTangentX = [double]$TangentWS[0] - [double]$normal[0] * $projection
    [double]$projectedTangentY = [double]$TangentWS[1] - [double]$normal[1] * $projection
    [double]$projectedTangentZ = [double]$TangentWS[2] - [double]$normal[2] * $projection
    $projectedTangent = [double[]]@($projectedTangentX, $projectedTangentY, $projectedTangentZ)
    $tangent = Normalize-Vector $projectedTangent
    $cross = Normalize-Vector (Cross-Vector $normal $tangent)
    [double]$sign = if ([double]$TangentWS[3] -lt 0.0) { -1.0 } else { 1.0 }
    [double]$bitangentX = $sign * [double]$cross[0]
    [double]$bitangentY = $sign * [double]$cross[1]
    [double]$bitangentZ = $sign * [double]$cross[2]
    $bitangent = [double[]]@($bitangentX, $bitangentY, $bitangentZ)
    [double]$angle = Clamp-Value $Rotation (-[Math]::PI) ([Math]::PI)
    [double]$sine = [Math]::Sin($angle); [double]$cosine = [Math]::Cos($angle)
    [double]$rotatedTangentX = $cosine * [double]$tangent[0] + $sine * [double]$bitangent[0]
    [double]$rotatedTangentY = $cosine * [double]$tangent[1] + $sine * [double]$bitangent[1]
    [double]$rotatedTangentZ = $cosine * [double]$tangent[2] + $sine * [double]$bitangent[2]
    $rotatedTangent = Normalize-Vector ([double[]]@($rotatedTangentX, $rotatedTangentY, $rotatedTangentZ))
    [double]$rotatedBitangentX = -$sine * [double]$tangent[0] + $cosine * [double]$bitangent[0]
    [double]$rotatedBitangentY = -$sine * [double]$tangent[1] + $cosine * [double]$bitangent[1]
    [double]$rotatedBitangentZ = -$sine * [double]$tangent[2] + $cosine * [double]$bitangent[2]
    $rotatedBitangent = Normalize-Vector ([double[]]@($rotatedBitangentX, $rotatedBitangentY, $rotatedBitangentZ))
    return [ordered]@{ normal = $normal; tangent = $rotatedTangent; bitangent = $rotatedBitangent; anisotropy = $sanitizedAnisotropy }
}
function Get-SpecularTerms {
    param($InputData, $Frame, $View, $Light, $HalfDirection, [double]$NormalDotView, [double]$NormalDotLight)
    [double]$normalDotHalf = Saturate-Value (Dot-Vector $Frame.normal $HalfDirection)
    [double]$roughness = [Math]::Max((Saturate-Value ([double]$InputData.roughness)), 0.045)
    [double]$alpha = [Math]::Max($roughness * $roughness, 0.002)
    [double]$alphaSquared = $alpha * $alpha
    [double]$denominator = $normalDotHalf * $normalDotHalf * ($alphaSquared - 1.0) + 1.0
    [double]$distribution = $alphaSquared / [Math]::Max([Math]::PI * $denominator * $denominator, 0.0001)
    [double]$viewLambda = $NormalDotLight * [Math]::Sqrt([Math]::Max((-$NormalDotView * $alphaSquared + $NormalDotView) * $NormalDotView + $alphaSquared, 0.0))
    [double]$lightLambda = $NormalDotView * [Math]::Sqrt([Math]::Max((-$NormalDotLight * $alphaSquared + $NormalDotLight) * $NormalDotLight + $alphaSquared, 0.0))
    [double]$visibility = 0.5 / [Math]::Max($viewLambda + $lightLambda, 0.0001)
    if ([Math]::Abs([double]$Frame.anisotropy) -le 0.0001) { return [ordered]@{ distribution = $distribution; visibility = $visibility } }
    [double]$aspect = [Math]::Sqrt([Math]::Max(1.0 - 0.9 * [Math]::Abs([double]$Frame.anisotropy), 0.1))
    [double]$alphaLong = [Math]::Max($alpha / $aspect, 0.002); [double]$alphaShort = [Math]::Max($alpha * $aspect, 0.002)
    [double]$alphaT = if ([double]$Frame.anisotropy -ge 0.0) { $alphaLong } else { $alphaShort }
    [double]$alphaB = if ([double]$Frame.anisotropy -ge 0.0) { $alphaShort } else { $alphaLong }
    [double]$tangentDotHalf = Dot-Vector $Frame.tangent $HalfDirection; [double]$bitangentDotHalf = Dot-Vector $Frame.bitangent $HalfDirection
    [double]$term = [Math]::Pow($tangentDotHalf / $alphaT, 2.0) + [Math]::Pow($bitangentDotHalf / $alphaB, 2.0) + $normalDotHalf * $normalDotHalf
    $distribution = 1.0 / [Math]::Max([Math]::PI * $alphaT * $alphaB * $term * $term, 0.0001)
    [double]$tangentDotView = Dot-Vector $Frame.tangent $View; [double]$bitangentDotView = Dot-Vector $Frame.bitangent $View
    [double]$tangentDotLight = Dot-Vector $Frame.tangent $Light; [double]$bitangentDotLight = Dot-Vector $Frame.bitangent $Light
    [double]$viewLength = [Math]::Sqrt([Math]::Pow($alphaT * $tangentDotView, 2.0) + [Math]::Pow($alphaB * $bitangentDotView, 2.0) + $NormalDotView * $NormalDotView)
    [double]$lightLength = [Math]::Sqrt([Math]::Pow($alphaT * $tangentDotLight, 2.0) + [Math]::Pow($alphaB * $bitangentDotLight, 2.0) + $NormalDotLight * $NormalDotLight)
    $visibility = 0.5 / [Math]::Max($NormalDotLight * $viewLength + $NormalDotView * $lightLength, 0.0001)
    return [ordered]@{ distribution = $distribution; visibility = $visibility }
}
function Get-MaterialEvaluation {
    param($InputData)
    $normal = Resolve-Normal $InputData.normalTS $InputData.vertexNormalWS $InputData.vertexTangentWS
    $frame = Get-SurfaceFrame $normal $InputData.vertexTangentWS ([double]$InputData.anisotropy) ([double]$InputData.anisotropyRotation)
    $view = Normalize-Vector $InputData.viewDirectionWS; $light = Normalize-Vector $InputData.lightDirectionWS
    [double]$normalDotLight = Saturate-Value (Dot-Vector $frame.normal $light); [double]$normalDotView = Saturate-Value (Dot-Vector $frame.normal $view)
    $directDiffuse = [double[]]@(0.0, 0.0, 0.0); $directSpecular = [double[]]@(0.0, 0.0, 0.0)
    if ($normalDotLight -gt 0.0 -and $normalDotView -gt 0.0) {
        $halfDirection = Normalize-Vector (Add-Vector $view $light)
        [double]$viewDotHalf = Saturate-Value (Dot-Vector $view $halfDirection)
        [double]$metallic = Saturate-Value ([double]$InputData.metallic)
        $terms = Get-SpecularTerms $InputData $frame $view $light $halfDirection $normalDotView $normalDotLight
        $diffuseValues = [System.Collections.Generic.List[double]]::new(); $specularValues = [System.Collections.Generic.List[double]]::new()
        for ($channel = 0; $channel -lt 3; $channel++) {
            [double]$baseColor = Saturate-Value ([double]$InputData.baseColor[$channel])
            [double]$f0 = 0.04 * (1.0 - $metallic) + $baseColor * $metallic
            [double]$fresnel = $f0 + (1.0 - $f0) * [Math]::Pow(1.0 - $viewDotHalf, 5.0)
            [double]$radiance = [Math]::Max([double]$InputData.lightColor[$channel], 0.0) * [Math]::Max([double]$InputData.lightAttenuation, 0.0)
            $diffuseValues.Add((1.0 - $metallic) * (1.0 - $fresnel) * $baseColor / [Math]::PI * $normalDotLight * $radiance)
            $specularValues.Add([double]$terms.distribution * [double]$terms.visibility * $fresnel * $normalDotLight * $radiance)
        }
        $directDiffuse = [double[]]$diffuseValues.ToArray(); $directSpecular = [double[]]$specularValues.ToArray()
    }
    $indirectDiffuse = [System.Collections.Generic.List[double]]::new(); $finalLit = [System.Collections.Generic.List[double]]::new()
    [double]$sanitizedMetallic = Saturate-Value ([double]$InputData.metallic); [double]$ambientOcclusion = Saturate-Value ([double]$InputData.ambientOcclusion)
    for ($channel = 0; $channel -lt 3; $channel++) {
        [double]$indirect = [Math]::Max([double]$InputData.ambientIrradiance[$channel], 0.0) * (1.0 - $sanitizedMetallic) * (Saturate-Value ([double]$InputData.baseColor[$channel])) * $ambientOcclusion
        $indirectDiffuse.Add($indirect); $finalLit.Add($directDiffuse[$channel] + $directSpecular[$channel] + $indirect)
    }
    return [ordered]@{ normalWS = $frame.normal; tangentWS = $frame.tangent; bitangentWS = $frame.bitangent; anisotropy = [double]$frame.anisotropy; alpha = [double]$InputData.alpha; directDiffuse = $directDiffuse; directSpecular = $directSpecular; indirectDiffuse = [double[]]$indirectDiffuse.ToArray(); finalLit = [double[]]$finalLit.ToArray() }
}
function Add-Check { param([string]$Id, [bool]$Pass, [string]$Detail, [double]$MaximumError = 0.0); $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail; maximumError = $MaximumError }) }
function Add-VectorCheck {
    param([string]$Id, $Actual, $Expected)
    [double]$maximumError = 0.0
    for ($index = 0; $index -lt @($Expected).Count; $index++) { $maximumError = [Math]::Max($maximumError, [Math]::Abs([double]$Actual[$index] - [double]$Expected[$index])) }
    Add-Check $Id ($maximumError -le $tolerance) ('actual=' + ($Actual -join ', ') + ' expected=' + ($Expected -join ', ')) $maximumError
}
function Add-ScalarCheck { param([string]$Id, [double]$Actual, [double]$Expected); [double]$error = [Math]::Abs($Actual - $Expected); Add-Check $Id ($error -le $tolerance) "actual=$Actual expected=$Expected" $error }
function Resolve-Asset { param([string]$Path); return Join-Path $projectPath ($Path -replace '/', '\') }

foreach ($fixture in @($manifest.fixtures)) {
    if ($fixture.kind -eq 'normal') {
        $normal = Resolve-Normal $fixture.input.normalTS $fixture.input.vertexNormalWS $fixture.input.vertexTangentWS
        Add-VectorCheck ($fixture.id + '_NORMAL') $normal $fixture.expected.normalWS
        continue
    }
    $actual = Get-MaterialEvaluation $fixture.input
    foreach ($field in @('normalWS', 'tangentWS', 'bitangentWS', 'directDiffuse', 'directSpecular', 'indirectDiffuse', 'finalLit')) {
        Add-VectorCheck ($fixture.id + '_' + $field.ToUpperInvariant()) $actual[$field] $fixture.expected.$field
    }
    foreach ($field in @('anisotropy', 'alpha')) { Add-ScalarCheck ($fixture.id + '_' + $field.ToUpperInvariant()) ([double]$actual[$field]) ([double]$fixture.expected.$field) }
}

$source = Get-Content -LiteralPath (Resolve-Asset $manifest.source) -Raw
foreach ($symbol in @($manifest.publicSymbols)) { Add-Check ('PUBLIC_SYMBOL_' + $symbol) ($source -match ('\b' + [Regex]::Escape([string]$symbol) + '\b')) ([string]$symbol) }
$declaredIncludes = @([Regex]::Matches($source, '(?m)^\s*#include\s+"([^"]+\.hlsl)"') | ForEach-Object { $_.Groups[1].Value })
$expectedIncludes = @($manifest.dependencies | ForEach-Object { Split-Path -Leaf ([string]$_) })
Add-Check 'DEPENDENCY_BOUNDARY' (($declaredIncludes -join '|') -eq ($expectedIncludes -join '|') -and $source -notmatch 'Packages/') ($declaredIncludes -join ' -> ')
$configBlock = [Regex]::Match($source, 'struct TA_MaterialConfig\s*\{(?<body>[\s\S]*?)\};').Groups['body'].Value
Add-Check 'FLAT_RENDERER_CONTRACT' ($configBlock -match 'half4 baseColorTint;' -and $configBlock -match 'half anisotropyRotation;' -and $configBlock -notmatch 'TA_PBRInputConfig') $manifest.policies.flatContract
Add-Check 'FIXED_EVALUATION_ORDER' ($source -match 'TA_BuildSurfaceData\s*\([\s\S]*?TA_ApplyAnisotropyToSurface\s*\([\s\S]*?TA_EvaluateLighting\s*\(surface, lightingInput\)' -and $source -match 'result\.alpha = inputData\.alpha;') $manifest.policies.evaluationOrder
Add-Check 'NO_ENGINE_GLOBALS' ($source -notmatch '\bLight\b|GetMainLight|SampleSH|SampleSceneColor|_Time\b|TEXTURE2D\(') $manifest.policies.engineBoundary

$legacyCalls = @('TA_SamplePBRInput', 'TA_TransformTangentToWorld', 'TA_BuildSurfaceData', 'TA_ApplyAnisotropyToSurface', 'TA_EvaluateLighting')
foreach ($consumerPath in @($manifest.consumers)) {
    $consumer = Get-Content -LiteralPath (Resolve-Asset $consumerPath) -Raw
    $consumerName = [System.IO.Path]::GetFileNameWithoutExtension([string]$consumerPath).ToUpperInvariant()
    $unifiedCalls = @('TA_SampleMaterial', 'TA_ResolveMaterialNormalWS', 'TA_EvaluateMaterial')
    $singleEntry = $true
    foreach ($entry in $unifiedCalls) { $singleEntry = $singleEntry -and ([Regex]::Matches($consumer, ('\b' + $entry + '\s*\(')).Count -eq 1) }
    Add-Check ($consumerName + '_UNIFIED_ENTRIES') $singleEntry $consumerPath
    $hasLegacyCall = @($legacyCalls | Where-Object { $consumer -match ('\b' + $_ + '\s*\(') }).Count -gt 0
    Add-Check ($consumerName + '_NO_LEGACY_CALLS') (-not $hasLegacyCall) ($legacyCalls -join ', ')
    Add-Check ($consumerName + '_FLAT_TYPES') ($consumer -match 'TA_MaterialConfig' -and $consumer -match 'TA_MaterialInputData' -and $consumer -match 'TA_MaterialEvaluation' -and $consumer -notmatch '\bTA_PBRInputConfig\b|\bTA_PBRInputData\b') $manifest.policies.flatContract
}

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
    consumerCount = @($manifest.consumers).Count
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
if ($failed.Count -gt 0) { throw ('Unified material interface validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', ')) }
Write-Output 'UNITY_UNIFIED_MATERIAL_INTERFACE: PASS'
Write-Output "Report: $ReportPath"
