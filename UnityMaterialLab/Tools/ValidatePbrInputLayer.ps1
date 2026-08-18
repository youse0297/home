param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\PbrInputLayer.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\PbrInputLayerValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Convert-ToVector {
    param($Value)
    return @($Value | ForEach-Object { [double]$_ })
}

function Clamp01 {
    param([double]$Value)
    return [Math]::Max(0.0, [Math]::Min(1.0, $Value))
}

function Safe-Normalize {
    param([double[]]$Value)
    $lengthSquared = ($Value[0] * $Value[0]) + ($Value[1] * $Value[1]) + ($Value[2] * $Value[2])
    $inverseLength = 1.0 / [Math]::Sqrt([Math]::Max($lengthSquared, 0.0001))
    return @(
        ($Value[0] * $inverseLength),
        ($Value[1] * $inverseLength),
        ($Value[2] * $inverseLength)
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
        -Detail ('actual=' + ($Actual -join ', ')) -MaximumError $maximumError
}

function Flatten-SampledInput {
    param($Value)
    return @(
        (Convert-ToVector $Value.baseColor),
        [double]$Value.alpha,
        (Convert-ToVector $Value.normalTS),
        [double]$Value.ambientOcclusion,
        [double]$Value.roughness,
        [double]$Value.metallic
    ) | ForEach-Object { $_ }
}

function Flatten-ExpectedSample {
    param($Value)
    return @(
        (Convert-ToVector $Value.baseColor),
        [double]$Value.alpha,
        (Convert-ToVector $Value.normalTS),
        [double]$Value.ambientOcclusion,
        [double]$Value.roughness,
        [double]$Value.metallic
    ) | ForEach-Object { $_ }
}

function Flatten-Surface {
    param($Value)
    return @(
        (Convert-ToVector $Value.baseColor),
        (Convert-ToVector $Value.normalWS),
        [double]$Value.ambientOcclusion,
        [double]$Value.roughness,
        [double]$Value.metallic
    ) | ForEach-Object { $_ }
}

function Flatten-ExpectedSurface {
    param($Value)
    return @(
        (Convert-ToVector $Value.baseColor),
        (Convert-ToVector $Value.normalWS),
        [double]$Value.ambientOcclusion,
        [double]$Value.roughness,
        [double]$Value.metallic
    ) | ForEach-Object { $_ }
}

foreach ($fixture in @($manifest.fixtures)) {
    switch ($fixture.function) {
        'TA_SamplePBRInput' {
            $baseSample = Convert-ToVector $fixture.input.baseSample
            $tint = Convert-ToVector $fixture.input.config.baseColorTint
            $ormSample = Convert-ToVector $fixture.input.orm
            $orm = @(
                (Clamp01 $ormSample[0]),
                (Clamp01 $ormSample[1]),
                (Clamp01 $ormSample[2])
            )
            $baseColor = @(
                (Clamp01 ($baseSample[0] * $tint[0])),
                (Clamp01 ($baseSample[1] * $tint[1])),
                (Clamp01 ($baseSample[2] * $tint[2]))
            )
            $actual = [ordered]@{
                baseColor = $baseColor
                alpha = $baseSample[3] * $tint[3]
                normalTS = Convert-ToVector $fixture.input.normalTS
                ambientOcclusion = 1.0 + ($orm[0] - 1.0) * (Clamp01 $fixture.input.config.ambientOcclusionStrength)
                roughness = [Math]::Max((Clamp01 ($orm[1] * [double]$fixture.input.config.roughnessScale)), 0.045)
                metallic = Clamp01 ($orm[2] * [double]$fixture.input.config.metallicScale)
            }
            Add-NumericCheck -Id $fixture.id `
                -Actual (Flatten-SampledInput $actual) `
                -Expected (Flatten-ExpectedSample $fixture.expected)
        }
        'TA_BuildSurfaceData' {
            $actual = [ordered]@{
                baseColor = Convert-ToVector $fixture.input.baseColor
                normalWS = Safe-Normalize (Convert-ToVector $fixture.input.normalWS)
                ambientOcclusion = [double]$fixture.input.ambientOcclusion
                roughness = [double]$fixture.input.roughness
                metallic = [double]$fixture.input.metallic
            }
            Add-NumericCheck -Id $fixture.id `
                -Actual (Flatten-Surface $actual) `
                -Expected (Flatten-ExpectedSurface $fixture.expected)
        }
        default {
            throw "Unknown PBR input fixture: $($fixture.function)"
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
Add-Check -Id 'PBR_INPUT_POLICY' `
    -Pass ($source -match 'saturate\(baseSample\.rgb \* config\.baseColorTint\.rgb\)' -and
        $source -match 'baseSample\.a \* config\.baseColorTint\.a' -and
        $source -match 'TA_SanitizePerceptualRoughness\(orm\.g \* config\.roughnessScale\)' -and
        $source -match 'saturate\(orm\.b \* config\.metallicScale\)') `
    -Detail 'BaseColor, Alpha, Roughness and Metallic policies'
Add-Check -Id 'PBR_INPUT_CONSUMER_WIRING' `
    -Pass ($consumer -match 'TA_PBRInputConfig' -and
        $consumer -match 'TA_SamplePBRInput\(' -and
        $consumer -match 'TA_BuildSurfaceData\(' -and
        $consumer -match 'pbrInput\.alpha') `
    -Detail $manifest.consumer
Add-Check -Id 'PBR_INPUT_NO_INLINE_ASSEMBLY' `
    -Pass ($consumer -notmatch 'surface\.baseColor\s*=' -and
        $consumer -notmatch 'surface\.ambientOcclusion\s*=' -and
        $consumer -notmatch 'surface\.roughness\s*=' -and
        $consumer -notmatch 'surface\.metallic\s*=') `
    -Detail 'BasePass delegates material input assembly to TA_PBRInput'

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
    throw ('PBR input layer validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', '))
}

Write-Output 'UNITY_PBR_INPUT_LAYER: PASS'
Write-Output "Report: $ReportPath"
