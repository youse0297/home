param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\GgxGeometryFresnel.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\GgxGeometryFresnelValidation.json')
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

function Get-GGXAlphaFromRoughness {
    param([double]$Roughness)
    $sanitizedRoughness = [Math]::Max((Clamp01 $Roughness), 0.045)
    return [Math]::Max(
        $sanitizedRoughness * $sanitizedRoughness,
        0.002
    )
}

function Get-FresnelSchlick {
    param(
        [double]$CosineTheta,
        [double]$ReflectanceAtNormal
    )
    $cosine = Clamp01 $CosineTheta
    $reflectance = Clamp01 $ReflectanceAtNormal
    $oneMinusCosine = 1.0 - $cosine
    $factor = $oneMinusCosine * $oneMinusCosine
    $factor = $factor * $factor * $oneMinusCosine
    return $reflectance + (1.0 - $reflectance) * $factor
}

function Get-SmithLambda {
    param(
        [double]$NormalDotDirection,
        [double]$OtherDotDirection,
        [double]$Alpha
    )
    $cosine = Clamp01 $NormalDotDirection
    $otherCosine = Clamp01 $OtherDotDirection
    $sanitizedAlpha = [Math]::Max((Clamp01 $Alpha), 0.002)
    $alphaSquared = $sanitizedAlpha * $sanitizedAlpha
    $radicand = (-$cosine * $alphaSquared + $cosine) * $cosine + $alphaSquared
    return $otherCosine * [Math]::Sqrt([Math]::Max([double]0.0, $radicand))
}

function Get-SmithVisibility {
    param(
        [double]$NormalDotView,
        [double]$NormalDotLight,
        [double]$Roughness
    )
    $alpha = Get-GGXAlphaFromRoughness $Roughness
    $viewLambda = Get-SmithLambda $NormalDotView $NormalDotLight $alpha
    $lightLambda = Get-SmithLambda $NormalDotLight $NormalDotView $alpha
    return 0.5 / [Math]::Max([double]0.0001, ($viewLambda + $lightLambda))
}

function Add-Check {
    param(
        [string]$Id,
        [bool]$Pass,
        [string]$Detail,
        [double]$MaximumError = 0.0
    )
    $checks.Add([ordered]@{
        id = $Id
        pass = $Pass
        detail = $Detail
        maximumError = $MaximumError
    })
}

function Add-NumericCheck {
    param(
        [string]$Id,
        [double]$Actual,
        [double]$Expected
    )
    $maximumError = [Math]::Abs($Actual - $Expected)
    Add-Check -Id $Id -Pass ($maximumError -le $tolerance) `
        -Detail ("actual=$Actual expected=$Expected") `
        -MaximumError $maximumError
}

function Add-VectorNumericCheck {
    param(
        [string]$Id,
        [double[]]$Actual,
        [double[]]$Expected
    )
    $maximumError = 0.0
    if ($Actual.Count -ne $Expected.Count) {
        $maximumError = [double]::PositiveInfinity
    } else {
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            $maximumError = [Math]::Max(
                $maximumError,
                [Math]::Abs($Actual[$index] - $Expected[$index])
            )
        }
    }
    Add-Check -Id $Id -Pass ($maximumError -le $tolerance) `
        -Detail ("actual=$($Actual -join ', ') expected=$($Expected -join ', ')") `
        -MaximumError $maximumError
}

foreach ($fixture in @($manifest.fixtures)) {
    switch ($fixture.function) {
        'TA_FresnelSchlickScalar' {
            $actual = Get-FresnelSchlick `
                ([double]$fixture.input.cosineTheta) `
                ([double]$fixture.input.reflectanceAtNormal)
            Add-NumericCheck -Id $fixture.id -Actual $actual `
                -Expected ([double]$fixture.expected)
        }
        'TA_FresnelSchlick' {
            $actual = @($fixture.input.reflectanceAtNormal | ForEach-Object {
                Get-FresnelSchlick `
                    ([double]$fixture.input.cosineTheta) `
                    ([double]$_)
            })
            Add-VectorNumericCheck -Id $fixture.id -Actual $actual `
                -Expected @($fixture.expected | ForEach-Object { [double]$_ })
        }
        'TA_SmithGGXLambdaTerm' {
            $actual = Get-SmithLambda `
                ([double]$fixture.input.normalDotDirection) `
                ([double]$fixture.input.otherDotDirection) `
                ([double]$fixture.input.alpha)
            Add-NumericCheck -Id $fixture.id -Actual $actual `
                -Expected ([double]$fixture.expected)
        }
        'TA_VisibilitySmithGGXCorrelated' {
            $actual = Get-SmithVisibility `
                ([double]$fixture.input.normalDotView) `
                ([double]$fixture.input.normalDotLight) `
                ([double]$fixture.input.roughness)
            Add-NumericCheck -Id $fixture.id -Actual $actual `
                -Expected ([double]$fixture.expected)
        }
        default {
            throw "Unknown GGX geometry/Fresnel fixture function: $($fixture.function)"
        }
    }
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
Add-Check -Id 'FRESNEL_POLICY' `
    -Pass ($source -match 'TA_FresnelSchlickScalar' -and
        $source -match 'saturate\(cosineTheta\)' -and
        $source -match 'saturate\(reflectanceAtNormal\)') `
    -Detail 'Schlick Fresnel clamps cosine and normal-incidence reflectance'
Add-Check -Id 'GEOMETRY_POLICY' `
    -Pass ($source -match 'TA_SmithGGXLambdaTerm' -and
        $source -match 'TA_MIN_GGX_ALPHA' -and
        $source -match 'TA_MIN_DENOMINATOR') `
    -Detail 'Correlated Smith visibility uses explicit lambda terms and denominator floor'
Add-Check -Id 'LIGHTING_CONSUMER_WIRING' `
    -Pass ($consumer -match 'TA_FresnelSchlick\(' -and
        $consumer -match 'TA_VisibilitySmithGGXCorrelated\(') `
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
    throw ('GGX geometry and Fresnel validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', '))
}

Write-Output 'UNITY_GGX_GEOMETRY_FRESNEL: PASS'
Write-Output "Report: $ReportPath"
