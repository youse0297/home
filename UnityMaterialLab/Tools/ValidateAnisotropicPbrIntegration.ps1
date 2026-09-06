param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\AnisotropicPbrIntegration.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\AnisotropicPbrIntegrationValidation.json')
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
    if ($length -le 0.000001) { throw 'Cannot normalize a zero vector.' }
    [double]$normalizedX = $x / $length; [double]$normalizedY = $y / $length; [double]$normalizedZ = $z / $length
    return ,([double[]]@($normalizedX, $normalizedY, $normalizedZ))
}
function Dot-Vector { param($Left, $Right); return ([double]$Left[0] * [double]$Right[0]) + ([double]$Left[1] * [double]$Right[1]) + ([double]$Left[2] * [double]$Right[2]) }
function Add-Vector {
    param($Left, $Right)
    [double]$x = [double]$Left[0] + [double]$Right[0]; [double]$y = [double]$Left[1] + [double]$Right[1]; [double]$z = [double]$Left[2] + [double]$Right[2]
    return ,([double[]]@($x, $y, $z))
}
function Cross-Vector {
    param($Left, $Right)
    [double]$x = ([double]$Left[1] * [double]$Right[2]) - ([double]$Left[2] * [double]$Right[1])
    [double]$y = ([double]$Left[2] * [double]$Right[0]) - ([double]$Left[0] * [double]$Right[2])
    [double]$z = ([double]$Left[0] * [double]$Right[1]) - ([double]$Left[1] * [double]$Right[0])
    return ,([double[]]@($x, $y, $z))
}
function Get-RotatedFrame {
    param($Normal, $Tangent, [double]$Rotation)
    $normalValue = Normalize-Vector $Normal
    [double]$projection = Dot-Vector $normalValue $Tangent
    [double]$projectedX = [double]$Tangent[0] - [double]$normalValue[0] * $projection
    [double]$projectedY = [double]$Tangent[1] - [double]$normalValue[1] * $projection
    [double]$projectedZ = [double]$Tangent[2] - [double]$normalValue[2] * $projection
    $tangentValue = Normalize-Vector ([double[]]@($projectedX, $projectedY, $projectedZ))
    $cross = Normalize-Vector (Cross-Vector $normalValue $tangentValue)
    [double]$sign = if ([double]$Tangent[3] -lt 0.0) { -1.0 } else { 1.0 }
    [double]$bitangentX = $sign * [double]$cross[0]; [double]$bitangentY = $sign * [double]$cross[1]; [double]$bitangentZ = $sign * [double]$cross[2]
    $bitangentValue = [double[]]@($bitangentX, $bitangentY, $bitangentZ)
    [double]$angle = Clamp-Value $Rotation (-[Math]::PI) ([Math]::PI)
    [double]$sine = [Math]::Sin($angle); [double]$cosine = [Math]::Cos($angle)
    [double]$rotatedTX = $cosine * [double]$tangentValue[0] + $sine * [double]$bitangentValue[0]
    [double]$rotatedTY = $cosine * [double]$tangentValue[1] + $sine * [double]$bitangentValue[1]
    [double]$rotatedTZ = $cosine * [double]$tangentValue[2] + $sine * [double]$bitangentValue[2]
    [double]$rotatedBX = -$sine * [double]$tangentValue[0] + $cosine * [double]$bitangentValue[0]
    [double]$rotatedBY = -$sine * [double]$tangentValue[1] + $cosine * [double]$bitangentValue[1]
    [double]$rotatedBZ = -$sine * [double]$tangentValue[2] + $cosine * [double]$bitangentValue[2]
    return [ordered]@{
        tangent = Normalize-Vector ([double[]]@($rotatedTX, $rotatedTY, $rotatedTZ))
        bitangent = Normalize-Vector ([double[]]@($rotatedBX, $rotatedBY, $rotatedBZ))
    }
}
function Get-SpecularTerms {
    param($InputData, $Normal, $View, $Light, $HalfDirection, [double]$NormalDotView, [double]$NormalDotLight)
    [double]$normalDotHalf = Saturate-Value (Dot-Vector $Normal $HalfDirection)
    [double]$roughness = [Math]::Max((Saturate-Value ([double]$InputData.roughness)), 0.045)
    [double]$alpha = [Math]::Max($roughness * $roughness, 0.002)
    [double]$alphaSquared = $alpha * $alpha
    [double]$distributionDenominator = ($normalDotHalf * $normalDotHalf * ($alphaSquared - 1.0)) + 1.0
    [double]$distribution = $alphaSquared / [Math]::Max([Math]::PI * $distributionDenominator * $distributionDenominator, 0.0001)
    [double]$viewLambda = $NormalDotLight * [Math]::Sqrt([Math]::Max((-$NormalDotView * $alphaSquared + $NormalDotView) * $NormalDotView + $alphaSquared, 0.0))
    [double]$lightLambda = $NormalDotView * [Math]::Sqrt([Math]::Max((-$NormalDotLight * $alphaSquared + $NormalDotLight) * $NormalDotLight + $alphaSquared, 0.0))
    [double]$visibility = 0.5 / [Math]::Max($viewLambda + $lightLambda, 0.0001)
    [double]$effectiveAnisotropy = Clamp-Value `
        ([double]$InputData.anisotropy * (1.0 - (Saturate-Value ([double]$InputData.snowMask)))) `
        (-0.9) `
        0.9
    if ([Math]::Abs($effectiveAnisotropy) -le 0.0001) { return [ordered]@{ distribution = $distribution; visibility = $visibility } }
    $frame = Get-RotatedFrame $Normal $InputData.tangentWS ([double]$InputData.rotation)
    [double]$aspect = [Math]::Sqrt([Math]::Max(1.0 - 0.9 * [Math]::Abs($effectiveAnisotropy), 0.1))
    [double]$alphaLong = [Math]::Max($alpha / $aspect, 0.002); [double]$alphaShort = [Math]::Max($alpha * $aspect, 0.002)
    [double]$alphaT = if ($effectiveAnisotropy -ge 0.0) { $alphaLong } else { $alphaShort }
    [double]$alphaB = if ($effectiveAnisotropy -ge 0.0) { $alphaShort } else { $alphaLong }
    [double]$tangentDotHalf = Dot-Vector $frame.tangent $HalfDirection; [double]$bitangentDotHalf = Dot-Vector $frame.bitangent $HalfDirection
    [double]$term = [Math]::Pow($tangentDotHalf / $alphaT, 2.0) + [Math]::Pow($bitangentDotHalf / $alphaB, 2.0) + ($normalDotHalf * $normalDotHalf)
    $distribution = 1.0 / [Math]::Max([Math]::PI * $alphaT * $alphaB * $term * $term, 0.0001)
    [double]$tangentDotView = Dot-Vector $frame.tangent $View; [double]$bitangentDotView = Dot-Vector $frame.bitangent $View
    [double]$tangentDotLight = Dot-Vector $frame.tangent $Light; [double]$bitangentDotLight = Dot-Vector $frame.bitangent $Light
    [double]$viewLength = [Math]::Sqrt([Math]::Pow($alphaT * $tangentDotView, 2.0) + [Math]::Pow($alphaB * $bitangentDotView, 2.0) + ($NormalDotView * $NormalDotView))
    [double]$lightLength = [Math]::Sqrt([Math]::Pow($alphaT * $tangentDotLight, 2.0) + [Math]::Pow($alphaB * $bitangentDotLight, 2.0) + ($NormalDotLight * $NormalDotLight))
    $visibility = 0.5 / [Math]::Max(($NormalDotLight * $viewLength) + ($NormalDotView * $lightLength), 0.0001)
    return [ordered]@{ distribution = $distribution; visibility = $visibility }
}
function Get-DirectLighting {
    param($InputData)
    $normal = Normalize-Vector $InputData.normalWS; $view = Normalize-Vector $InputData.viewDirectionWS; $light = Normalize-Vector $InputData.lightDirectionWS
    [double]$normalDotLight = Saturate-Value (Dot-Vector $normal $light); [double]$normalDotView = Saturate-Value (Dot-Vector $normal $view)
    if ($normalDotLight -le 0.0 -or $normalDotView -le 0.0) { return [ordered]@{ directDiffuse = [double[]]@(0.0, 0.0, 0.0); directSpecular = [double[]]@(0.0, 0.0, 0.0) } }
    $halfDirection = Normalize-Vector (Add-Vector $view $light)
    [double]$viewDotHalf = Saturate-Value (Dot-Vector $view $halfDirection); [double]$metallic = Saturate-Value ([double]$InputData.metallic)
    $terms = Get-SpecularTerms $InputData $normal $view $light $halfDirection $normalDotView $normalDotLight
    $directDiffuse = [System.Collections.Generic.List[double]]::new(); $directSpecular = [System.Collections.Generic.List[double]]::new()
    for ($channel = 0; $channel -lt 3; $channel++) {
        [double]$baseColor = Saturate-Value ([double]$InputData.baseColor[$channel])
        [double]$reflectance = 0.04 * (1.0 - $metallic) + $baseColor * $metallic
        [double]$fresnel = $reflectance + (1.0 - $reflectance) * [Math]::Pow(1.0 - $viewDotHalf, 5.0)
        [double]$radiance = [Math]::Max([double]$InputData.lightColor[$channel], 0.0) * [Math]::Max([double]$InputData.lightAttenuation, 0.0)
        $directDiffuse.Add((1.0 - $metallic) * (1.0 - $fresnel) * $baseColor / [Math]::PI * $normalDotLight * $radiance)
        $directSpecular.Add([double]$terms.distribution * [double]$terms.visibility * $fresnel * $normalDotLight * $radiance)
    }
    return [ordered]@{ directDiffuse = [double[]]$directDiffuse.ToArray(); directSpecular = [double[]]$directSpecular.ToArray() }
}
function Merge-Input {
    param($Fixture, $Defaults)
    $merged = [ordered]@{}
    foreach ($property in $Defaults.PSObject.Properties) { $merged[$property.Name] = $property.Value }
    foreach ($property in $Fixture.inputs.PSObject.Properties) { $merged[$property.Name] = $property.Value }
    return [pscustomobject]$merged
}
function Add-Check { param([string]$Id, [bool]$Pass, [string]$Detail, [double]$MaximumError = 0.0); $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail; maximumError = $MaximumError }) }
function Add-VectorCheck {
    param([string]$Id, $Actual, $Expected)
    [double]$maximumError = 0.0
    for ($index = 0; $index -lt 3; $index++) { $maximumError = [Math]::Max($maximumError, [Math]::Abs([double]$Actual[$index] - [double]$Expected[$index])) }
    Add-Check $Id ($maximumError -le $tolerance) ('actual=' + ($Actual -join ', ') + ' expected=' + ($Expected -join ', ')) $maximumError
}
function Sum-Vector { param($Value); return [double]$Value[0] + [double]$Value[1] + [double]$Value[2] }
function Resolve-Asset { param([string]$Path); return Join-Path $projectPath ($Path -replace '/', '\') }

$results = [ordered]@{}
foreach ($fixture in @($manifest.fixtures)) {
    $actual = Get-DirectLighting (Merge-Input $fixture $manifest.defaults)
    $results[$fixture.id] = $actual
    Add-VectorCheck ($fixture.id + '_DIFFUSE') $actual.directDiffuse $fixture.expected.directDiffuse
    Add-VectorCheck ($fixture.id + '_SPECULAR') $actual.directSpecular $fixture.expected.directSpecular
}
Add-VectorCheck 'NEGATIVE_EQUALS_QUARTER_ROTATION' $results['ANISOTROPY_NEGATIVE'].directSpecular $results['ROTATION_QUARTER_TURN'].directSpecular
Add-VectorCheck 'HALF_TURN_PERIODICITY' $results['ANISOTROPY_POSITIVE'].directSpecular $results['ROTATION_HALF_TURN'].directSpecular
Add-Check 'PURE_METAL_DIFFUSE_ZERO' ((Sum-Vector $results['PURE_METAL'].directDiffuse) -le $tolerance) 'Metallic one has no direct diffuse'
[double]$isotropicEnergy = Sum-Vector $results['ISOTROPIC_REFERENCE'].directSpecular; [double]$snowEnergy = Sum-Vector $results['SNOW_ATTENUATED'].directSpecular; [double]$anisotropicEnergy = Sum-Vector $results['ANISOTROPY_POSITIVE'].directSpecular
Add-Check 'SNOW_ATTENUATION_BETWEEN_ENDPOINTS' ($snowEnergy -gt $isotropicEnergy -and $snowEnergy -lt $anisotropicEnergy) 'Half snow coverage produces a response between isotropic and full anisotropy for the fixed fixture'
Add-Check 'FINITE_NON_NEGATIVE_OUTPUTS' (@($results.GetEnumerator() | ForEach-Object { @($_.Value.directDiffuse + $_.Value.directSpecular) | Where-Object { [double]::IsNaN([double]$_) -or [double]::IsInfinity([double]$_) -or [double]$_ -lt 0.0 } }).Count -eq 0) 'All final direct-light channels are finite and non-negative'

$anisotropySource = Get-Content -LiteralPath (Resolve-Asset $manifest.anisotropySource) -Raw
$lightingSource = Get-Content -LiteralPath (Resolve-Asset $manifest.lightingSource) -Raw
$debugSource = Get-Content -LiteralPath (Resolve-Asset $manifest.debugSource) -Raw
$consumer = Get-Content -LiteralPath (Resolve-Asset $manifest.consumer) -Raw
Add-Check 'SPECULAR_TERMS_ENTRY' ($anisotropySource -match 'struct TA_GGXSpecularTerms' -and $anisotropySource -match 'TA_GGXSpecularTerms TA_EvaluateGGXSpecularTerms' -and $anisotropySource -match 'abs\(surface\.anisotropy\) <= TA_MIN_DENOMINATOR') 'One entry point selects isotropic or anisotropic GGX terms'
Add-Check 'LIGHTING_LAYER_DELEGATION' ($lightingSource -match 'TA_GGXSpecularTerms specularTerms = TA_EvaluateGGXSpecularTerms' -and $lightingSource -match 'distribution \* visibility \* fresnel' -and $lightingSource -notmatch 'TA_DistributionGGXAnisotropic\(') 'Lighting composes shared GGX terms with Fresnel and radiance without duplicating directional formulas'
Add-Check 'ENERGY_CONSERVING_METALLIC_WORKFLOW' ($lightingSource -match 'reflectanceAtNormal = lerp\(' -and $lightingSource -match 'diffuseWeight = \(1\.0h - metallic\) \* \(1\.0h - fresnel\)') 'F0 and diffuse energy use the metallic workflow'
Add-Check 'BASEPASS_SURFACE_WIRING' ($consumer -match 'TA_ApplyAnisotropyToSurface\(' -and $consumer -match '_Anisotropy \* \(1\.0h - snowMask\)' -and $consumer -match 'TA_EvaluateLighting\(surface, lightingInput\)') 'BasePass applies anisotropy and snow attenuation before lighting'
Add-Check 'DIRECT_SPECULAR_DEBUG_VIEW' ($debugSource -match 'TA_DEBUG_DIRECT_SPECULAR 7\.0h' -and $debugSource -match 'half4\(lighting\.directSpecular, 1\.0h\)') 'Existing debug ID 7 displays integrated anisotropic specular'

$failed = @($checks | Where-Object { -not $_.pass })
$maximumError = ($checks | ForEach-Object { [double]$_.maximumError } | Measure-Object -Maximum).Maximum
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report = [ordered]@{
    status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }
    version = $manifest.version
    sourceLibraryVersion = $manifest.sourceLibraryVersion
    publicSymbolCount = @($manifest.publicSymbols).Count
    fixtureCount = @($manifest.fixtures).Count
    invariantCount = @($manifest.invariants).Count
    limitationCount = @($manifest.limitations).Count
    tolerance = $tolerance
    maximumError = $maximumError
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    failures = @($failed | ForEach-Object { $_.id })
}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
if ($failed.Count -gt 0) { throw ('Anisotropic PBR integration validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', ')) }
Write-Output 'UNITY_ANISOTROPIC_PBR_INTEGRATION: PASS'
Write-Output "Report: $ReportPath"
