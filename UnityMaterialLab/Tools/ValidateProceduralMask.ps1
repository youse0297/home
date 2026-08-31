param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\ProceduralMask.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\ProceduralMaskValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Clamp-Value { param([double]$Value, [double]$Minimum, [double]$Maximum); return [Math]::Max($Minimum, [Math]::Min($Maximum, $Value)) }
function Add-Check { param([string]$Id, [bool]$Pass, [string]$Detail, [double]$MaximumError = 0.0); $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail; maximumError = $MaximumError }) }
function Resolve-Asset { param([string]$Path); return Join-Path $projectPath ($Path -replace '/', '\') }
function Evaluate-Mask {
    param($Config)
    $scaleX = [Math]::Min([Math]::Abs([double]$Config.uvScale[0]), 64.0)
    $scaleY = [Math]::Min([Math]::Abs([double]$Config.uvScale[1]), 64.0)
    $transformedX = [double]$Config.uv[0] * $scaleX + [double]$Config.uvOffset[0]
    $transformedY = [double]$Config.uv[1] * $scaleY + [double]$Config.uvOffset[1]
    $angle = Clamp-Value ([double]$Config.rotationRadians) -3.141592653589793 3.141592653589793
    $sine = [Math]::Sin($angle); $cosine = [Math]::Cos($angle)
    $rotatedX = $cosine * $transformedX - $sine * $transformedY
    $rotatedY = $sine * $transformedX + $cosine * $transformedY
    $animatedPhase = 1.61803399 * $rotatedX + 2.41421356 * $rotatedY + [double]$Config.timeSeconds * (Clamp-Value ([double]$Config.timeScale) -16.0 16.0) + (Clamp-Value ([double]$Config.phase) (-2.0 * 3.141592653589793) (2.0 * 3.141592653589793))
    $raw = 0.5 + 0.5 * [Math]::Sin($animatedPhase)
    $contrast = [Math]::Max([double]$Config.contrast, 0.0)
    $shaped = Clamp-Value (($raw - 0.5) * $contrast + 0.5) 0.0 1.0
    $strength = Clamp-Value ([double]$Config.strength) 0.0 1.0
    return 1.0 + ($shaped - 1.0) * $strength
}
foreach ($fixture in @($manifest.fixtures)) {
    $actual = if ([string]$fixture.function -eq 'TA_ApplyProceduralMask') {
        $layerWeight = Clamp-Value ([double]$fixture.input.layerWeight) 0.0 1.0
        $mask = Clamp-Value ([double]$fixture.input.proceduralMask) 0.0 1.0
        $layerWeight * $mask
    } else {
        Evaluate-Mask $fixture.input
    }
    $expected = [double]$fixture.expected
    $maximumError = [Math]::Abs($actual - $expected)
    Add-Check -Id $fixture.id -Pass ($maximumError -le $tolerance) -Detail ('actual=' + $actual) -MaximumError $maximumError
}
$sourcePath = Resolve-Asset $manifest.source
$consumerPath = Resolve-Asset $manifest.consumer
$materialPath = Resolve-Asset $manifest.material
$profilePath = Resolve-Asset $manifest.profile
$source = Get-Content -LiteralPath $sourcePath -Raw
$consumer = Get-Content -LiteralPath $consumerPath -Raw
$material = Get-Content -LiteralPath $materialPath -Raw
$profile = Get-Content -LiteralPath $profilePath -Raw
foreach ($symbol in @($manifest.publicSymbols)) {
    Add-Check -Id ('PUBLIC_SYMBOL_' + $symbol) -Pass ($source -match ('\b' + [Regex]::Escape([string]$symbol) + '\b')) -Detail ([string]$symbol)
}
Add-Check 'BOUNDED_OUTPUT' ($source -match 'saturate\(config\.strength\)' -and $source -match 'saturate\(\(raw') 'Mask strength and contrast are bounded'
Add-Check 'EXPLICIT_TIME' ($source -match 'timeSeconds \* clamp\(config\.timeScale') 'Time is an explicit function input'
Add-Check 'CONSUMER_WIRING' ($consumer -match 'TA_EvaluateProceduralMask\(' -and $consumer -match 'TA_ApplyProceduralMask\(' -and $consumer -match '_Time\.y') 'BasePass evaluates and applies the mask'
Add-Check 'MATERIAL_PARAMETERS' ($material -match '_ProceduralMaskScale:' -and $material -match '_ProceduralMaskStrength: 0\.75') 'Material serializes procedural mask parameters'
Add-Check 'PROFILE_PARAMETERS' ($profile -match 'proceduralMaskScale:' -and $profile -match 'proceduralMaskContrast: 1\.4' -and $profile -match 'proceduralMaskStrength: 0\.75') 'Profile serializes procedural mask parameters'
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
if ($failed.Count -gt 0) { throw ('Procedural mask validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', ')) }
Write-Output 'UNITY_PROCEDURAL_MASK: PASS'
Write-Output "Report: $ReportPath"
