param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\SnowCover.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\SnowCoverValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Clamp-Value { param([double]$Value, [double]$Minimum, [double]$Maximum); return [Math]::Max($Minimum, [Math]::Min($Maximum, $Value)) }
function Safe-Normalize {
    param($Value)
    [double]$x = $Value[0]; [double]$y = $Value[1]; [double]$z = $Value[2]
    [double]$lengthSquared = ($x * $x) + ($y * $y) + ($z * $z)
    [double]$length = [Math]::Sqrt($lengthSquared)
    if ($length -le 0.000001) { return ,([double[]]@(0.0, 1.0, 0.0)) }
    [double]$nx = $x / $length; [double]$ny = $y / $length; [double]$nz = $z / $length
    return ,([double[]]@($nx, $ny, $nz))
}
function Add-Check { param([string]$Id, [bool]$Pass, [string]$Detail, [double]$MaximumError = 0.0); $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail; maximumError = $MaximumError }) }
function Resolve-Asset { param([string]$Path); return Join-Path $projectPath ($Path -replace '/', '\') }
function Evaluate-Snow {
    param($Config)
    $normal = Safe-Normalize $Config.normal
    [double]$upwardness = Clamp-Value ([double]$normal[1]) 0.0 1.0
    [double]$threshold = Clamp-Value ([double]$Config.normalThreshold) 0.0 1.0
    [double]$softness = [Math]::Max([double]$Config.normalSoftness, 0.0001)
    [double]$slopeMask = Clamp-Value (($upwardness - ($threshold - $softness)) / (2.0 * $softness)) 0.0 1.0
    [double]$slopeMask = $slopeMask * $slopeMask * (3.0 - 2.0 * $slopeMask)
    [double]$heightFade = [Math]::Max([Math]::Abs([double]$Config.heightFade), 0.0001)
    [double]$heightMask = Clamp-Value (([double]$Config.position[1] - [double]$Config.heightStart) / $heightFade) 0.0 1.0
    [double]$heightBlend = Clamp-Value ([double]$Config.heightBlend) 0.0 1.0
    [double]$combined = 1.0 + ($heightMask - 1.0) * $heightBlend
    return (Clamp-Value ([double]$Config.coverage) 0.0 1.0) * $slopeMask * $combined
}
foreach ($fixture in @($manifest.fixtures)) {
    $actual = $null
    if ([string]$fixture.function -eq 'TA_EvaluateSnowCover') {
        $actual = Evaluate-Snow $fixture.input
    } elseif ([string]$fixture.function -eq 'TA_ApplySnowCoverColor') {
        [double]$mask = Clamp-Value ([double]$fixture.input.snowMask) 0.0 1.0
        [double]$baseX = Clamp-Value ([double]$fixture.input.baseColor[0]) 0.0 1.0
        [double]$baseY = Clamp-Value ([double]$fixture.input.baseColor[1]) 0.0 1.0
        [double]$baseZ = Clamp-Value ([double]$fixture.input.baseColor[2]) 0.0 1.0
        [double]$snowX = Clamp-Value ([double]$fixture.input.snowColor[0]) 0.0 1.0
        [double]$snowY = Clamp-Value ([double]$fixture.input.snowColor[1]) 0.0 1.0
        [double]$snowZ = Clamp-Value ([double]$fixture.input.snowColor[2]) 0.0 1.0
        [double]$colorX = $baseX + ($snowX - $baseX) * $mask
        [double]$colorY = $baseY + ($snowY - $baseY) * $mask
        [double]$colorZ = $baseZ + ($snowZ - $baseZ) * $mask
        $actual = [double[]]@($colorX, $colorY, $colorZ)
    } elseif ([string]$fixture.function -eq 'TA_ApplySnowCoverRoughness') {
        [double]$roughness = Clamp-Value ([double]$fixture.input.roughness) 0.045 1.0
        [double]$snowRoughness = Clamp-Value ([double]$fixture.input.snowRoughness) 0.045 1.0
        [double]$mask = Clamp-Value ([double]$fixture.input.snowMask) 0.0 1.0
        $actual = $roughness + ($snowRoughness - $roughness) * $mask
    } elseif ([string]$fixture.function -eq 'TA_ApplySnowCoverMetallic') {
        [double]$metallic = Clamp-Value ([double]$fixture.input.metallic) 0.0 1.0
        [double]$mask = Clamp-Value ([double]$fixture.input.snowMask) 0.0 1.0
        $actual = $metallic * (1.0 - $mask)
    }
    $actualValues = @($actual); $expectedValues = @($fixture.expected); $maximumError = 0.0
    for ($index = 0; $index -lt $expectedValues.Count; $index++) { $maximumError = [Math]::Max($maximumError, [Math]::Abs([double]$actualValues[$index] - [double]$expectedValues[$index])) }
    Add-Check -Id $fixture.id -Pass ($maximumError -le $tolerance) -Detail ('actual=' + ($actualValues -join ', ')) -MaximumError $maximumError
}
$source = Get-Content -LiteralPath (Resolve-Asset $manifest.source) -Raw
$consumer = Get-Content -LiteralPath (Resolve-Asset $manifest.consumer) -Raw
$material = Get-Content -LiteralPath (Resolve-Asset $manifest.material) -Raw
$profile = Get-Content -LiteralPath (Resolve-Asset $manifest.profile) -Raw
foreach ($symbol in @($manifest.publicSymbols)) { Add-Check -Id ('PUBLIC_SYMBOL_' + $symbol) -Pass ($source -match ('\b' + [Regex]::Escape([string]$symbol) + '\b')) -Detail ([string]$symbol) }
Add-Check 'UPWARDNESS_SIGNAL' ($source -match 'dot\(safeNormal, half3\(0\.0h, 1\.0h, 0\.0h\)\)') 'Snow mask derives world-up normal coverage'
Add-Check 'HEIGHT_BLEND' ($source -match 'positionWS\.y - config\.heightStart' -and $source -match 'saturate\(config\.heightBlend\)') 'Snow mask supports optional world-height accumulation'
Add-Check 'BOUNDED_RESPONSES' ($source -match 'TA_ApplySnowCoverColor' -and $source -match 'TA_ApplySnowCoverRoughness' -and $source -match 'TA_ApplySnowCoverMetallic' -and $source -match 'saturate\(snowMask\)') 'Snow material responses remain bounded'
Add-Check 'CONSUMER_WIRING' ($consumer -match 'TA_EvaluateSnowCover\(' -and $consumer -match 'TA_ApplySnowCoverColor\(' -and $consumer -match 'TA_ApplySnowCoverRoughness\(' -and $consumer -match 'TA_ApplySnowCoverMetallic\(') 'BasePass applies snow to color, roughness and metallic'
Add-Check 'MATERIAL_PARAMETERS' ($material -match '_SnowColor:' -and $material -match '_SnowCoverage: 0\.7' -and $material -match '_SnowRoughness: 0\.82') 'Material serializes snow cover parameters'
Add-Check 'PROFILE_PARAMETERS' ($profile -match 'snowColor:' -and $profile -match 'snowCoverage: 0\.7' -and $profile -match 'snowHeightFade: 1') 'Profile serializes snow cover parameters'
$failed = @($checks | Where-Object { -not $_.pass })
$maximumError = ($checks | ForEach-Object { [double]$_.maximumError } | Measure-Object -Maximum).Maximum
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report = [ordered]@{ status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }; version = $manifest.version; sourceLibraryVersion = $manifest.sourceLibraryVersion; publicSymbolCount = @($manifest.publicSymbols).Count; dependencyCount = @($manifest.dependencies).Count; fixtureCount = @($manifest.fixtures).Count; invariantCount = @($manifest.invariants).Count; limitationCount = @($manifest.limitations).Count; tolerance = $tolerance; maximumError = $maximumError; generatedAtUtc = [DateTime]::UtcNow.ToString('O'); checks = $checks; failures = @($failed | ForEach-Object { $_.id }) }
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
if ($failed.Count -gt 0) { throw ('Snow cover validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', ')) }
Write-Output 'UNITY_SNOW_COVER: PASS'
Write-Output "Report: $ReportPath"
