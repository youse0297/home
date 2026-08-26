param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\WaveWindAnimation.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\WaveWindAnimationValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[string]]::new()
$tolerance = 0.000001
$minimumDenominator = 0.0001

function Clamp-Value {
    param([double]$Value, [double]$Minimum, [double]$Maximum)
    return [Math]::Max($Minimum, [Math]::Min($Maximum, $Value))
}

function Get-NormalizedVector {
    param([double[]]$Value)
    $lengthSquared = 0.0
    foreach ($component in $Value) { $lengthSquared += $component * $component }
    $inverseLength = 1.0 / [Math]::Sqrt([Math]::Max($lengthSquared, $minimumDenominator))
    return @($Value | ForEach-Object { $_ * $inverseLength })
}

function Get-TravelingSine {
    param(
        [double[]]$Position,
        [double[]]$Direction,
        [double]$SpatialFrequency,
        [double]$Speed,
        [double]$TimeSeconds,
        [double]$PhaseOffset
    )
    $normalizedDirection = Get-NormalizedVector $Direction
    $frequency = Clamp-Value ([Math]::Abs($SpatialFrequency)) 0.0 32.0
    $sanitizedSpeed = Clamp-Value $Speed -16.0 16.0
    $spatialPhase = ($Position[0] * $normalizedDirection[0] +
        $Position[2] * $normalizedDirection[1]) * $frequency
    return [Math]::Sin($spatialPhase + $TimeSeconds * $sanitizedSpeed + $PhaseOffset)
}

function Get-HeightWeight {
    param([double]$PositionHeight, [double]$PivotHeight, [double]$FadeDistance)
    $safeFadeDistance = [Math]::Max([Math]::Abs($FadeDistance), $minimumDenominator)
    return Clamp-Value (($PositionHeight - $PivotHeight) / $safeFadeDistance) 0.0 1.0
}

function Get-WaveWindPosition {
    param(
        [double[]]$Position,
        [double[]]$Normal,
        [double]$WaveSignal,
        [double]$WaveAmplitude,
        [double[]]$WindDirection,
        [double]$WindSignal,
        [double]$WindAmplitude,
        [double]$WindWeight
    )
    $waveDirection = Get-NormalizedVector $Normal
    $normalizedWindDirection = Get-NormalizedVector $WindDirection
    $sanitizedWaveAmplitude = Clamp-Value $WaveAmplitude -1.0 1.0
    $sanitizedWindAmplitude = Clamp-Value $WindAmplitude -1.0 1.0
    $sanitizedWindWeight = Clamp-Value $WindWeight 0.0 1.0
    $result = [System.Collections.Generic.List[double]]::new()
    for ($index = 0; $index -lt 3; $index++) {
        $waveOffset = $waveDirection[$index] * $WaveSignal * $sanitizedWaveAmplitude
        $windOffset = $normalizedWindDirection[$index] * $WindSignal *
            $sanitizedWindAmplitude * $sanitizedWindWeight
        $result.Add($Position[$index] + $waveOffset + $windOffset)
    }
    return @($result)
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

function Add-ScalarCheck {
    param([string]$Id, [double]$Actual, [double]$Expected)
    $error = [Math]::Abs($Actual - $Expected)
    Add-Check -Id $Id -Pass ($error -le $tolerance) `
        -Detail "actual=$Actual expected=$Expected" -MaximumError $error
}

function Add-VectorCheck {
    param([string]$Id, [double[]]$Actual, [double[]]$Expected)
    $error = 0.0
    if ($Actual.Count -ne $Expected.Count) {
        $error = [double]::PositiveInfinity
    } else {
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            $error = [Math]::Max($error, [Math]::Abs($Actual[$index] - $Expected[$index]))
        }
    }
    Add-Check -Id $Id -Pass ($error -le $tolerance) `
        -Detail "actual=$($Actual -join ', ') expected=$($Expected -join ', ')" `
        -MaximumError $error
}

foreach ($fixture in @($manifest.fixtures)) {
    switch ($fixture.function) {
        'TA_EvaluateTravelingSineOS' {
            $actual = Get-TravelingSine `
                ([double[]]$fixture.input.positionOS) `
                ([double[]]$fixture.input.directionXZ) `
                ([double]$fixture.input.spatialFrequency) `
                ([double]$fixture.input.speed) `
                ([double]$fixture.input.timeSeconds) `
                ([double]$fixture.input.phaseOffset)
            Add-ScalarCheck -Id $fixture.id -Actual $actual -Expected ([double]$fixture.expected)
        }
        'TA_EvaluateHeightWeightOS' {
            $actual = Get-HeightWeight `
                ([double]$fixture.input.positionHeightOS) `
                ([double]$fixture.input.pivotHeightOS) `
                ([double]$fixture.input.fadeDistanceOS)
            Add-ScalarCheck -Id $fixture.id -Actual $actual -Expected ([double]$fixture.expected)
        }
        'TA_ApplyWaveWindAnimationOS' {
            $actual = Get-WaveWindPosition `
                ([double[]]$fixture.input.positionOS) `
                ([double[]]$fixture.input.normalOS) `
                ([double]$fixture.input.waveSignal) `
                ([double]$fixture.input.waveAmplitude) `
                ([double[]]$fixture.input.windDirectionOS) `
                ([double]$fixture.input.windSignal) `
                ([double]$fixture.input.windAmplitude) `
                ([double]$fixture.input.windWeight)
            Add-VectorCheck -Id $fixture.id -Actual $actual `
                -Expected @($fixture.expected | ForEach-Object { [double]$_ })
        }
        default { throw "Unknown wave/wind fixture function: $($fixture.function)" }
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
Add-Check -Id 'TRAVELING_SINE_POLICY' `
    -Pass ($source -match 'float timeSeconds' -and
        $source -match 'rsqrt\(max\(directionLengthSquared, \(float\)TA_MIN_DENOMINATOR\)\)' -and
        $source -match 'clamp\(abs\(\(float\)spatialFrequency\), 0\.0, 32\.0\)' -and
        $source -match 'clamp\(\(float\)speed, -16\.0, 16\.0\)' -and
        $source -match 'return \(half\)sin\(phase\)') `
    -Detail $manifest.policies.phase
Add-Check -Id 'HEIGHT_WEIGHT_POLICY' `
    -Pass ($source -match 'max\(abs\(fadeDistanceOS\), \(float\)TA_MIN_DENOMINATOR\)' -and
        $source -match 'saturate\(\(positionHeightOS - pivotHeightOS\) / safeFadeDistance\)') `
    -Detail $manifest.policies.windWeight
Add-Check -Id 'ADDITIVE_APPLICATION_POLICY' `
    -Pass ($source -match 'TA_SafeNormalize\(normalOS\)' -and
        $source -match 'TA_SafeNormalize\(windDirectionOS\)' -and
        $source -match 'clamp\(waveAmplitude, -1\.0h, 1\.0h\)' -and
        $source -match 'clamp\(windAmplitude, -1\.0h, 1\.0h\)' -and
        $source -match 'waveOffsetOS \+ windOffsetOS') `
    -Detail $manifest.policies.composition
Add-Check -Id 'CONSUMER_PARAMETERS' `
    -Pass ($consumer -match '_WaveDirection' -and
        $consumer -match '_WaveFrequency' -and
        $consumer -match '_WaveSpeed' -and
        $consumer -match '_WavePhase' -and
        $consumer -match '_WindDirection' -and
        $consumer -match '_WindFrequency' -and
        $consumer -match '_WindSpeed' -and
        $consumer -match '_WindPhase' -and
        $consumer -match '_WindPivotHeight' -and
        $consumer -match '_WindFadeDistance') `
    -Detail 'BasePass exposes wave and height-anchored wind controls'
Add-Check -Id 'DEFAULT_PRESERVES_BASELINE' `
    -Pass ($consumer -match '_WaveAmplitude\("Wave Amplitude", Range\(-1, 1\)\) = 0' -and
        $consumer -match '_WindAmplitude\("Wind Amplitude", Range\(-1, 1\)\) = 0') `
    -Detail $manifest.policies.default
Add-Check -Id 'EXPLICIT_UNITY_TIME' `
    -Pass ($consumer -match 'TA_EvaluateTravelingSineOS\s*\([\s\S]*?_Time\.y') `
    -Detail 'BasePass supplies Unity time explicitly to the reusable signal function'
Add-Check -Id 'HEIGHT_ANCHOR_INPUT' `
    -Pass ($consumer -match 'TA_EvaluateHeightWeightOS\s*\(\s*\r?\n\s*input\.positionOS\.y') `
    -Detail 'Wind anchoring is derived from original object-space mesh height'
Add-Check -Id 'COMPOSITION_ORDER' `
    -Pass ($consumer -match 'TA_ApplyVertexDisplacementOS\s*\([\s\S]*?TA_ApplyWaveWindAnimationOS\s*\([\s\S]*?GetVertexPositionInputs\(animatedPositionOS\)') `
    -Detail $manifest.policies.composition

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
    functionCount = @($manifest.publicSymbols).Count
    fixtureCount = @($manifest.fixtures).Count
    invariantCount = @($manifest.invariants).Count
    limitationCount = @($manifest.limitations).Count
    tolerance = $tolerance
    maximumError = $maximumError
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    failures = $failures
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($failures.Count -gt 0) {
    throw ('Wave and wind animation validation failed: ' + ($failures -join ', '))
}

Write-Output 'UNITY_WAVE_WIND_ANIMATION: PASS'
Write-Output "Report: $ReportPath"
