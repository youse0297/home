param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\PbrParameterRegression.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\PbrParameterRegressionValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[string]]::new()
$tolerance = 0.000001

function Clamp01 {
    param([double]$Value)
    return [Math]::Max([double]0.0, [Math]::Min([double]1.0, $Value))
}

function Normalize-Vector {
    param([double[]]$Value)
    $length = [Math]::Sqrt($Value[0] * $Value[0] + $Value[1] * $Value[1] + $Value[2] * $Value[2])
    if ($length -le 0.000001) { throw 'Cannot normalize a zero vector.' }
    return @(($Value[0] / $length), ($Value[1] / $length), ($Value[2] / $length))
}

function Dot-Vector {
    param([double[]]$Left, [double[]]$Right)
    return $Left[0] * $Right[0] + $Left[1] * $Right[1] + $Left[2] * $Right[2]
}

function Add-Vector {
    param([double[]]$Left, [double[]]$Right)
    return @(($Left[0] + $Right[0]), ($Left[1] + $Right[1]), ($Left[2] + $Right[2]))
}

function Multiply-Vector {
    param([double[]]$Left, [double[]]$Right)
    return @(($Left[0] * $Right[0]), ($Left[1] * $Right[1]), ($Left[2] * $Right[2]))
}

function Scale-Vector {
    param([double[]]$Value, [double]$Scale)
    return @(($Value[0] * $Scale), ($Value[1] * $Scale), ($Value[2] * $Scale))
}

function Merge-FixtureInput {
    param($Fixture, $Defaults)
    $merged = [ordered]@{}
    foreach ($property in $Defaults.PSObject.Properties) {
        $merged[$property.Name] = $property.Value
    }
    foreach ($property in $Fixture.inputs.PSObject.Properties) {
        $merged[$property.Name] = $property.Value
    }
    return [pscustomobject]$merged
}

function Get-DirectLighting {
    param($FixtureInput)
    $normal = Normalize-Vector ([double[]]$FixtureInput.normalWS)
    $view = Normalize-Vector ([double[]]$FixtureInput.viewDirectionWS)
    $light = Normalize-Vector ([double[]]$FixtureInput.lightDirectionWS)
    $normalDotLight = Clamp01 (Dot-Vector $normal $light)
    $normalDotView = Clamp01 (Dot-Vector $normal $view)
    $roughness = [Math]::Max((Clamp01 ([double]$FixtureInput.roughness)), 0.045)
    $alpha = [Math]::Max($roughness * $roughness, 0.002)
    if ($normalDotLight -le 0.0 -or $normalDotView -le 0.0) {
        return [ordered]@{
            directDiffuse = @(0.0, 0.0, 0.0)
            directSpecular = @(0.0, 0.0, 0.0)
            alpha = $alpha
        }
    }

    $halfDirection = Normalize-Vector (Add-Vector $view $light)
    $normalDotHalf = Clamp01 (Dot-Vector $normal $halfDirection)
    $viewDotHalf = Clamp01 (Dot-Vector $view $halfDirection)
    $baseColor = @($FixtureInput.baseColor | ForEach-Object { Clamp01 ([double]$_) })
    $metallic = Clamp01 ([double]$FixtureInput.metallic)
    $lightColor = @($FixtureInput.lightColor | ForEach-Object { [Math]::Max([double]$_, 0.0) })
    $radiance = Scale-Vector $lightColor ([Math]::Max([double]$FixtureInput.lightAttenuation, 0.0))
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
        alpha = $alpha
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
    if (-not $Pass) { $failures.Add($Id) }
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

$fixtureResults = [ordered]@{}
$inputs = [ordered]@{}
foreach ($fixture in @($manifest.fixtures)) {
    $fixtureInput = Merge-FixtureInput $fixture $manifest.defaults
    $inputs[$fixture.id] = $fixtureInput
    $actual = Get-DirectLighting $fixtureInput
    $fixtureResults[$fixture.id] = $actual
    Add-VectorNumericCheck -Id ($fixture.id + '_DIFFUSE') `
        -Actual $actual.directDiffuse `
        -Expected @($fixture.expected.directDiffuse | ForEach-Object { [double]$_ })
    Add-VectorNumericCheck -Id ($fixture.id + '_SPECULAR') `
        -Actual $actual.directSpecular `
        -Expected @($fixture.expected.directSpecular | ForEach-Object { [double]$_ })
}

function Get-VectorSum {
    param([double[]]$Value)
    return $Value[0] + $Value[1] + $Value[2]
}

$metallicDiffuse = @('METALLIC_00','METALLIC_35','METALLIC_50','METALLIC_10') | ForEach-Object {
    Get-VectorSum $fixtureResults[$_].directDiffuse
}
Add-Check -Id 'METALLIC_DIFFUSE_MONOTONIC' `
    -Pass ($metallicDiffuse[0] -ge $metallicDiffuse[1] -and
        $metallicDiffuse[1] -ge $metallicDiffuse[2] -and
        $metallicDiffuse[2] -ge $metallicDiffuse[3]) `
    -Detail 'Diffuse energy does not increase as metallic rises'
Add-Check -Id 'PURE_METAL_DIFFUSE_ZERO' `
    -Pass ($metallicDiffuse[3] -le $tolerance) `
    -Detail 'Metallic 1 produces no direct diffuse'
Add-Check -Id 'ROUGHNESS_ALPHA_MONOTONIC' `
    -Pass ($fixtureResults['ROUGHNESS_00'].alpha -le $fixtureResults['ROUGHNESS_25'].alpha -and
        $fixtureResults['ROUGHNESS_25'].alpha -le $fixtureResults['ROUGHNESS_50'].alpha -and
        $fixtureResults['ROUGHNESS_50'].alpha -le $fixtureResults['ROUGHNESS_75'].alpha -and
        $fixtureResults['ROUGHNESS_75'].alpha -le $fixtureResults['ROUGHNESS_10'].alpha) `
    -Detail 'Sanitized GGX alpha is monotonic with perceptual roughness'
Add-VectorNumericCheck -Id 'ROUGHNESS_CLAMP_EQUALS_ZERO' `
    -Actual $fixtureResults['ROUGHNESS_CLAMP'].directSpecular `
    -Expected $fixtureResults['ROUGHNESS_00'].directSpecular
Add-Check -Id 'FINITE_NON_NEGATIVE_OUTPUTS' `
    -Pass (@($fixtureResults.GetEnumerator() | ForEach-Object {
        @($_.Value.directDiffuse + $_.Value.directSpecular) | Where-Object {
            [double]::IsNaN([double]$_) -or [double]::IsInfinity([double]$_) -or [double]$_ -lt 0.0
        }
    }).Count -eq 0) `
    -Detail 'All direct diffuse and specular channels are finite and non-negative'

$inputSourcePath = Join-Path $projectPath ($manifest.inputSource -replace '/', '\')
$lightingSourcePath = Join-Path $projectPath ($manifest.lightingSource -replace '/', '\')
$consumerPath = Join-Path $projectPath ($manifest.consumer -replace '/', '\')
$inputSource = Get-Content -LiteralPath $inputSourcePath -Raw
$lightingSource = Get-Content -LiteralPath $lightingSourcePath -Raw
$consumer = Get-Content -LiteralPath $consumerPath -Raw
foreach ($symbol in @($manifest.publicSymbols)) {
    $symbolSource = if ($symbol -in @('TA_SamplePBRInput','TA_BuildSurfaceData')) { $inputSource } else { $lightingSource }
    Add-Check -Id ('PUBLIC_SYMBOL_' + $symbol) `
        -Pass ($symbolSource -match ('\b' + [Regex]::Escape([string]$symbol) + '\b')) `
        -Detail ([string]$symbol)
}
Add-Check -Id 'INPUT_POLICY_WIRING' `
    -Pass ($inputSource -match 'TA_SamplePBRInput' -and
        $inputSource -match 'TA_BuildSurfaceData' -and
        $inputSource -match 'TA_SanitizePerceptualRoughness') `
    -Detail 'PBR input layer exposes sampling, surface assembly and roughness policy'
Add-Check -Id 'LIGHTING_POLICY_WIRING' `
    -Pass ($lightingSource -match 'TA_EvaluateDirectLighting' -and
        $lightingSource -match 'TA_EvaluateLighting' -and
        $lightingSource -match 'TA_DistributionGGX' -and
        $lightingSource -match 'TA_VisibilitySmithGGXCorrelated' -and
        $lightingSource -match 'TA_FresnelSchlick') `
    -Detail 'Lighting layer consumes the integrated direct-light PBR components'
Add-Check -Id 'BASEPASS_PARAMETER_WIRING' `
    -Pass ($consumer -match 'TA_SamplePBRInput\s*\(' -and
        $consumer -match 'TA_BuildSurfaceData\s*\(' -and
        $consumer -match 'TA_EvaluateLighting\s*\(') `
    -Detail $manifest.consumer

$outputReport = [ordered]@{}
foreach ($fixture in @($manifest.fixtures)) {
    $actual = $fixtureResults[$fixture.id]
    $outputReport[$fixture.id] = [ordered]@{
        parameter = $fixture.parameter
        alpha = [Math]::Round([double]$actual.alpha, 8)
        directDiffuse = @($actual.directDiffuse | ForEach-Object { [Math]::Round([double]$_, 8) })
        directSpecular = @($actual.directSpecular | ForEach-Object { [Math]::Round([double]$_, 8) })
    }
}
$maximumError = 0.0
foreach ($check in $checks) {
    if ([double]$check.maximumError -gt $maximumError) { $maximumError = [double]$check.maximumError }
}
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report = [ordered]@{
    status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
    version = $manifest.version
    sourceLibraryVersion = $manifest.sourceLibraryVersion
    parameterCount = @($manifest.parameterRanges.PSObject.Properties).Count
    fixtureCount = @($manifest.fixtures).Count
    tolerance = $tolerance
    maximumError = $maximumError
    outputs = $outputReport
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    failures = $failures
}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($failures.Count -gt 0) {
    throw ('PBR parameter regression validation failed: ' + ($failures -join ', '))
}

Write-Output 'UNITY_PBR_PARAMETER_REGRESSION: PASS'
Write-Output "Report: $ReportPath"
