param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\DirectLightPbrIntegration.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\DirectLightPbrIntegrationValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Clamp01 {
    param([double]$Value)
    return [Math]::Max([double]0.0, [Math]::Min([double]1.0, $Value))
}

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

function Get-DirectLighting {
    param($Fixture)
    $normal = Normalize-Vector ([double[]]$Fixture.input.normalWS)
    $view = Normalize-Vector ([double[]]$Fixture.input.viewDirectionWS)
    $light = Normalize-Vector ([double[]]$Fixture.input.lightDirectionWS)
    $normalDotLight = Clamp01 (Dot-Vector $normal $light)
    $normalDotView = Clamp01 (Dot-Vector $normal $view)
    if ($normalDotLight -le 0.0 -or $normalDotView -le 0.0) {
        return [ordered]@{
            directDiffuse = @(0.0, 0.0, 0.0)
            directSpecular = @(0.0, 0.0, 0.0)
        }
    }

    $halfDirection = Normalize-Vector (Add-Vector $view $light)
    $normalDotHalf = Clamp01 (Dot-Vector $normal $halfDirection)
    $viewDotHalf = Clamp01 (Dot-Vector $view $halfDirection)
    $baseColor = @($Fixture.input.baseColor | ForEach-Object { Clamp01 ([double]$_) })
    $roughness = [Math]::Max((Clamp01 ([double]$Fixture.input.roughness)), 0.045)
    $metallic = Clamp01 ([double]$Fixture.input.metallic)
    $radiance = Scale-Vector (
        @($Fixture.input.lightColor | ForEach-Object { [Math]::Max([double]$_, 0.0) })
    ) ([Math]::Max([double]$Fixture.input.lightAttenuation, 0.0))
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
    $diffuseWeight = @(
        ((1.0 - $metallic) * (1.0 - $fresnel[0])),
        ((1.0 - $metallic) * (1.0 - $fresnel[1])),
        ((1.0 - $metallic) * (1.0 - $fresnel[2]))
    )
    $directDiffuse = Scale-Vector (Multiply-Vector (Multiply-Vector $baseColor $diffuseWeight) $radiance) ($normalDotLight / [Math]::PI)
    $directSpecular = Scale-Vector (Multiply-Vector $fresnel $radiance) ($distribution * $visibility * $normalDotLight)
    return [ordered]@{
        directDiffuse = $directDiffuse
        directSpecular = $directSpecular
    }
}

function Add-Check {
    param([string]$Id, [bool]$Pass, [string]$Detail, [double]$MaximumError = 0.0)
    $checks.Add([ordered]@{
        id = $Id
        pass = $Pass
        detail = $Detail
        maximumError = $MaximumError
    })
}

function Add-VectorNumericCheck {
    param([string]$Id, [double[]]$Actual, [double[]]$Expected)
    $maximumError = 0.0
    if ($Actual.Count -ne $Expected.Count) {
        $maximumError = [double]::PositiveInfinity
    } else {
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            $maximumError = [Math]::Max($maximumError, [Math]::Abs($Actual[$index] - $Expected[$index]))
        }
    }
    Add-Check -Id $Id -Pass ($maximumError -le $tolerance) `
        -Detail ("actual=$($Actual -join ', ') expected=$($Expected -join ', ')") `
        -MaximumError $maximumError
}

foreach ($fixture in @($manifest.fixtures)) {
    if ($fixture.function -ne 'TA_EvaluateDirectLighting') {
        throw "Unknown direct-light fixture function: $($fixture.function)"
    }
    $actual = Get-DirectLighting $fixture
    Add-VectorNumericCheck -Id ($fixture.id + '_DIFFUSE') `
        -Actual $actual.directDiffuse `
        -Expected @($fixture.expected.directDiffuse | ForEach-Object { [double]$_ })
    Add-VectorNumericCheck -Id ($fixture.id + '_SPECULAR') `
        -Actual $actual.directSpecular `
        -Expected @($fixture.expected.directSpecular | ForEach-Object { [double]$_ })
}

$sourcePath = Join-Path $projectPath ($manifest.source -replace '/', '\')
$consumerPath = Join-Path $projectPath ($manifest.consumer -replace '/', '\')
$source = Get-Content -LiteralPath $sourcePath -Raw
$consumer = Get-Content -LiteralPath $consumerPath -Raw
foreach ($symbol in @($manifest.publicSymbols)) {
    Add-Check -Id ('PUBLIC_SYMBOL_' + $symbol) `
        -Pass ($source -match ('\b' + [Regex]::Escape([string]$symbol) + '\b')) `
        -Detail ([string]$symbol)
}
Add-Check -Id 'DIRECT_ENTRY_POINT' `
    -Pass ($source -match 'TA_EvaluateDirectLighting\s*\(' -and
        $source -match 'TA_DirectLightingBreakdown\s+TA_EvaluateDirectLighting') `
    -Detail 'Direct light evaluation is a reusable lighting-layer entry point'
Add-Check -Id 'ENERGY_CONSERVING_DIFFUSE' `
    -Pass ($source -match 'diffuseWeight\s*=\s*\(1\.0h - metallic\)\s*\*\s*\(1\.0h - fresnel\)' -and
        $source -match 'result\.directDiffuse\s*=\s*diffuseWeight\s*\*\s*baseColor\s*\*\s*TA_INV_PI') `
    -Detail '(1-F_Schlick) * (1-metallic) * BaseColor / PI'
Add-Check -Id 'BRDF_COMPONENT_INTEGRATION' `
    -Pass ($source -match 'TA_DistributionGGX\(' -and
        $source -match 'TA_VisibilitySmithGGXCorrelated\(' -and
        $source -match 'TA_FresnelSchlick\(' -and
        $source -match 'result\.directSpecular\s*=\s*distribution\s*\*\s*visibility\s*\*\s*fresnel') `
    -Detail 'Direct specular composes GGX distribution, correlated Smith visibility and Schlick Fresnel'
Add-Check -Id 'BACKFACE_GUARD' `
    -Pass ($source -match 'normalDotLight\s*<=\s*0\.0h' -and
        $source -match 'normalDotView\s*<=\s*0\.0h') `
    -Detail 'Back-facing view or light returns zero direct components'
Add-Check -Id 'BASEPASS_CONSUMER_WIRING' `
    -Pass ($consumer -match 'TA_EvaluateLighting\s*\(' -and
        $consumer -match 'TA_LightingBreakdown') `
    -Detail $manifest.consumer

$failed = @($checks | Where-Object { -not $_.pass })
$maximumError = 0.0
foreach ($check in $checks) {
    if ([double]$check.maximumError -gt $maximumError) {
        $maximumError = [double]$check.maximumError
    }
}
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report = [ordered]@{
    status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }
    version = $manifest.version
    sourceLibraryVersion = $manifest.sourceLibraryVersion
    functionCount = @($manifest.publicSymbols).Count
    fixtureCount = @($manifest.fixtures).Count
    tolerance = $tolerance
    maximumError = $maximumError
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    failures = @($failed | ForEach-Object { $_.id })
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($failed.Count -gt 0) {
    throw ('Direct-light PBR integration validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', '))
}

Write-Output 'UNITY_DIRECT_LIGHT_PBR_INTEGRATION: PASS'
Write-Output "Report: $ReportPath"
