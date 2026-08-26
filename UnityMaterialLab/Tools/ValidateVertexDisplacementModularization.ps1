param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\VertexDisplacementModularization.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\VertexDisplacementModularizationValidation.json')
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
        [double]$Frequency,
        [double]$Speed,
        [double]$TimeSeconds,
        [double]$Phase
    )
    $normalizedDirection = Get-NormalizedVector $Direction
    $sanitizedFrequency = Clamp-Value ([Math]::Abs($Frequency)) 0.0 32.0
    $sanitizedSpeed = Clamp-Value $Speed -16.0 16.0
    $spatialPhase = ($Position[0] * $normalizedDirection[0] +
        $Position[2] * $normalizedDirection[1]) * $sanitizedFrequency
    return [Math]::Sin($spatialPhase + $TimeSeconds * $sanitizedSpeed + $Phase)
}

function Get-DeformationResult {
    param($InputData, $Config)
    $position = @($InputData.positionOS | ForEach-Object { [double]$_ })
    $normal = @($InputData.normalOS | ForEach-Object { [double]$_ })
    $normalDirection = Get-NormalizedVector $normal
    $height = Clamp-Value ([double]$InputData.heightSample) 0.0 1.0
    $heightCenter = Clamp-Value ([double]$Config.heightCenter) 0.0 1.0
    $heightAmplitude = Clamp-Value ([double]$Config.heightAmplitude) -1.0 1.0
    $heightDisplacement = ($height - $heightCenter) * $heightAmplitude
    $heightPosition = @(
        ($position[0] + $normalDirection[0] * $heightDisplacement),
        ($position[1] + $normalDirection[1] * $heightDisplacement),
        ($position[2] + $normalDirection[2] * $heightDisplacement)
    )

    $waveDirection = @($Config.waveDirectionXZ | ForEach-Object { [double]$_ })
    $windDirection = @($Config.windDirectionOS | ForEach-Object { [double]$_ })
    $windPhaseDirection = @($windDirection[0], $windDirection[2])
    $waveSignal = Get-TravelingSine $position $waveDirection `
        ([double]$Config.waveFrequency) ([double]$Config.waveSpeed) `
        ([double]$InputData.timeSeconds) ([double]$Config.wavePhase)
    $windSignal = Get-TravelingSine $position $windPhaseDirection `
        ([double]$Config.windFrequency) ([double]$Config.windSpeed) `
        ([double]$InputData.timeSeconds) ([double]$Config.windPhase)
    $safeFade = [Math]::Max([Math]::Abs([double]$Config.windFadeDistanceOS), $minimumDenominator)
    $windWeight = Clamp-Value `
        (($position[1] - [double]$Config.windPivotHeightOS) / $safeFade) 0.0 1.0

    $normalizedWindDirection = Get-NormalizedVector $windDirection
    $waveAmplitude = Clamp-Value ([double]$Config.waveAmplitude) -1.0 1.0
    $windAmplitude = Clamp-Value ([double]$Config.windAmplitude) -1.0 1.0
    $finalPosition = [System.Collections.Generic.List[double]]::new()
    for ($index = 0; $index -lt 3; $index++) {
        $waveOffset = $normalDirection[$index] * $waveSignal * $waveAmplitude
        $windOffset = $normalizedWindDirection[$index] * $windSignal * $windAmplitude * $windWeight
        $finalPosition.Add($heightPosition[$index] + $waveOffset + $windOffset)
    }

    return [pscustomobject]@{
        positionOS = @($finalPosition)
        heightDisplacement = $heightDisplacement
        waveSignal = $waveSignal
        windSignal = $windSignal
        windWeight = $windWeight
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
    $actual = Get-DeformationResult $fixture.input $fixture.config
    Add-VectorCheck -Id ($fixture.id + '_POSITION') `
        -Actual ([double[]]$actual.positionOS) `
        -Expected @($fixture.expected.positionOS | ForEach-Object { [double]$_ })
    foreach ($field in @('heightDisplacement', 'waveSignal', 'windSignal', 'windWeight')) {
        Add-ScalarCheck -Id ($fixture.id + '_' + $field.ToUpperInvariant()) `
            -Actual ([double]$actual.$field) -Expected ([double]$fixture.expected.$field)
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

$declaredIncludes = @([Regex]::Matches(
    $source,
    '(?m)^\s*#include\s+"([^"]+\.hlsl)"'
) | ForEach-Object { $_.Groups[1].Value })
$expectedIncludes = @($manifest.dependencies | ForEach-Object { Split-Path -Leaf ([string]$_) })
Add-Check -Id 'DEPENDENCY_BOUNDARY' `
    -Pass ($declaredIncludes.Count -eq 2 -and
        $declaredIncludes[0] -eq $expectedIncludes[0] -and
        $declaredIncludes[1] -eq $expectedIncludes[1] -and
        $source -notmatch '(?m)^\s*#include\s+["<]Packages/') `
    -Detail ($declaredIncludes -join ' -> ')
Add-Check -Id 'STRUCTURED_CONTRACT' `
    -Pass ($source -match 'struct TA_VertexDeformationInput' -and
        $source -match 'struct TA_VertexDeformationConfig' -and
        $source -match 'struct TA_VertexDeformationResult' -and
        $source -match 'float3 positionOS;' -and
        $source -match 'half heightDisplacement;' -and
        $source -match 'half waveSignal;' -and
        $source -match 'half windSignal;' -and
        $source -match 'half windWeight;') `
    -Detail $manifest.policies.diagnostics
Add-Check -Id 'NO_HIDDEN_RESOURCE_OR_TIME_GLOBAL' `
    -Pass ($source -notmatch 'TEXTURE2D|SAMPLER|_Time\b|unity_Time') `
    -Detail $manifest.policies.resourceBoundary
Add-Check -Id 'FIXED_ORCHESTRATION_ORDER' `
    -Pass ($source -match 'TA_DecodeVertexDisplacement\s*\([\s\S]*?TA_ApplyVertexDisplacementOS\s*\([\s\S]*?TA_EvaluateTravelingSineOS\s*\([\s\S]*?TA_EvaluateHeightWeightOS\s*\([\s\S]*?TA_ApplyWaveWindAnimationOS\s*\(') `
    -Detail $manifest.policies.order
Add-Check -Id 'ORIGINAL_POSITION_PHASE' `
    -Pass ($source -match 'TA_EvaluateTravelingSineOS\s*\(\s*\r?\n\s*inputData\.positionOS' -and
        $source -match 'TA_EvaluateHeightWeightOS\s*\(\s*\r?\n\s*inputData\.positionOS\.y') `
    -Detail 'Wave, wind and height weight use the original mesh position'

$entryPointMatches = [Regex]::Matches($consumer, '\bTA_EvaluateVertexDeformationOS\s*\(')
Add-Check -Id 'SINGLE_CONSUMER_ENTRY' `
    -Pass ($entryPointMatches.Count -eq 1 -and
        $consumer -match 'TA_VertexDeformationInput\s+deformationInput' -and
        $consumer -match 'TA_VertexDeformationConfig\s+deformationConfig' -and
        $consumer -match 'TA_VertexDeformationResult\s+deformation' -and
        $consumer -match 'deformationInput\.heightSample = displacementHeight' -and
        $consumer -match 'deformationInput\.timeSeconds = _Time\.y' -and
        $consumer -match 'GetVertexPositionInputs\(deformation\.positionOS\)') `
    -Detail $manifest.policies.singleEntry
Add-Check -Id 'NO_LOW_LEVEL_CONSUMER_ORCHESTRATION' `
    -Pass ($consumer -notmatch '\bTA_DecodeVertexDisplacement\s*\(' -and
        $consumer -notmatch '\bTA_ApplyVertexDisplacementOS\s*\(' -and
        $consumer -notmatch '\bTA_EvaluateTravelingSineOS\s*\(' -and
        $consumer -notmatch '\bTA_EvaluateHeightWeightOS\s*\(' -and
        $consumer -notmatch '\bTA_ApplyWaveWindAnimationOS\s*\(') `
    -Detail 'BasePass no longer owns low-level effect order'

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
    publicSymbolCount = @($manifest.publicSymbols).Count
    dependencyCount = @($manifest.dependencies).Count
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
    throw ('Vertex displacement modularization validation failed: ' + ($failures -join ', '))
}

Write-Output 'UNITY_VERTEX_DISPLACEMENT_MODULARIZATION: PASS'
Write-Output "Report: $ReportPath"
