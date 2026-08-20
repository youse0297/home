param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\GgxNormalDistribution.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\GgxNormalDistributionValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Clamp01 {
    param([double]$Value)
    return [Math]::Max(0.0, [Math]::Min(1.0, $Value))
}

function Get-GGXAlphaFromRoughness {
    param([double]$Roughness)
    $sanitizedRoughness = [Math]::Max((Clamp01 $Roughness), 0.045)
    return [Math]::Max(
        $sanitizedRoughness * $sanitizedRoughness,
        0.002
    )
}

function Get-GGXDistributionFromAlpha {
    param(
        [double]$NormalDotHalf,
        [double]$Alpha
    )
    $cosine = Clamp01 $NormalDotHalf
    $sanitizedAlpha = [Math]::Max((Clamp01 $Alpha), 0.002)
    $alphaSquared = $sanitizedAlpha * $sanitizedAlpha
    $denominator = $cosine * $cosine * ($alphaSquared - 1.0) + 1.0
    return $alphaSquared / [Math]::Max(
        [Math]::PI * $denominator * $denominator,
        0.0001
    )
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

foreach ($fixture in @($manifest.fixtures)) {
    switch ($fixture.function) {
        'TA_GGXAlphaFromRoughness' {
            $actual = Get-GGXAlphaFromRoughness ([double]$fixture.input.roughness)
        }
        'TA_DistributionGGXFromAlpha' {
            $actual = Get-GGXDistributionFromAlpha `
                ([double]$fixture.input.normalDotHalf) `
                ([double]$fixture.input.alpha)
        }
        'TA_DistributionGGX' {
            $alpha = Get-GGXAlphaFromRoughness ([double]$fixture.input.roughness)
            $actual = Get-GGXDistributionFromAlpha `
                ([double]$fixture.input.normalDotHalf) `
                $alpha
        }
        default {
            throw "Unknown GGX fixture function: $($fixture.function)"
        }
    }
    Add-NumericCheck -Id $fixture.id -Actual $actual `
        -Expected ([double]$fixture.expected)
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
Add-Check -Id 'ALPHA_POLICY' `
    -Pass ($source -match 'TA_SanitizePerceptualRoughness\(roughness\)' -and
        $source -match 'TA_MIN_GGX_ALPHA') `
    -Detail 'Perceptual roughness is sanitized before alpha conversion'
Add-Check -Id 'NDF_FORMULA' `
    -Pass ($source -match 'saturate\(normalDotHalf\)' -and
        $source -match 'alphaSquared\s*=\s*sanitizedAlpha\s*\*\s*sanitizedAlpha' -and
        $source -match 'TA_MIN_DENOMINATOR') `
    -Detail 'Trowbridge-Reitz distribution clamps cosine and denominator'
Add-Check -Id 'LIGHTING_CONSUMER_WIRING' `
    -Pass ($consumer -match 'TA_DistributionGGX\(') `
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
    throw ('GGX normal distribution validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', '))
}

Write-Output 'UNITY_GGX_NORMAL_DISTRIBUTION: PASS'
Write-Output "Report: $ReportPath"
