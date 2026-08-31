param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\EdgeWear.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\EdgeWearValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Clamp-Value { param([double]$Value, [double]$Minimum, [double]$Maximum); return [Math]::Max($Minimum, [Math]::Min($Maximum, $Value)) }
function Safe-Normalize {
    param($Value)
    $x = [double]$Value[0]
    $y = [double]$Value[1]
    $z = [double]$Value[2]
    [double]$lengthSquared = ($x * $x) + ($y * $y) + ($z * $z)
    [double]$length = [Math]::Sqrt([double]$lengthSquared)
    if ($length -le 0.000001) { return ,([double[]]@(0.0, 0.0, 1.0)) }
    [double]$normalizedX = $x / $length
    [double]$normalizedY = $y / $length
    [double]$normalizedZ = $z / $length
    $normalized = [double[]]@($normalizedX, $normalizedY, $normalizedZ)
    return ,$normalized
}
function Add-Check { param([string]$Id, [bool]$Pass, [string]$Detail, [double]$MaximumError = 0.0); $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail; maximumError = $MaximumError }) }
function Resolve-Asset { param([string]$Path); return Join-Path $projectPath ($Path -replace '/', '\') }
function Evaluate-Wear {
    param($Config)
    $normal = Safe-Normalize $Config.normal
    $view = Safe-Normalize $Config.view
    $dot = $normal[0] * $view[0] + $normal[1] * $view[1] + $normal[2] * $view[2]
    $grazing = 1.0 - (Clamp-Value $dot 0.0 1.0)
    $threshold = Clamp-Value ([double]$Config.threshold) 0.0 1.0
    $softness = [Math]::Max([double]$Config.softness, 0.0001)
    $progress = Clamp-Value (($grazing - $threshold) / $softness) 0.0 1.0
    $edgeMask = $progress * $progress * (3.0 - 2.0 * $progress)
    return $edgeMask * (Clamp-Value ([double]$Config.strength) 0.0 1.0)
}
foreach ($fixture in @($manifest.fixtures)) {
    $actual = switch ([string]$fixture.function) {
        'TA_EvaluateEdgeWear' { Evaluate-Wear $fixture.input; break }
        'TA_ApplyEdgeWearColor' {
            $mask = Clamp-Value ([double]$fixture.input.wearMask) 0.0 1.0
            [double]$baseX = Clamp-Value ([double]$fixture.input.baseColor[0]) 0.0 1.0
            [double]$baseY = Clamp-Value ([double]$fixture.input.baseColor[1]) 0.0 1.0
            [double]$baseZ = Clamp-Value ([double]$fixture.input.baseColor[2]) 0.0 1.0
            [double]$wearX = Clamp-Value ([double]$fixture.input.wearColor[0]) 0.0 1.0
            [double]$wearY = Clamp-Value ([double]$fixture.input.wearColor[1]) 0.0 1.0
            [double]$wearZ = Clamp-Value ([double]$fixture.input.wearColor[2]) 0.0 1.0
            [double]$colorX = $baseX + ($wearX - $baseX) * $mask
            [double]$colorY = $baseY + ($wearY - $baseY) * $mask
            [double]$colorZ = $baseZ + ($wearZ - $baseZ) * $mask
            [double[]]@($colorX, $colorY, $colorZ); break
        }
        'TA_ApplyEdgeWearRoughness' {
            $roughness = [Math]::Max(0.045, [Math]::Min(1.0, [double]$fixture.input.roughness))
            $boost = Clamp-Value ([double]$fixture.input.roughnessBoost) 0.0 1.0
            $mask = Clamp-Value ([double]$fixture.input.wearMask) 0.0 1.0
            $target = $roughness + (1.0 - $roughness) * $boost
            [Math]::Max(0.045, [Math]::Min(1.0, $roughness + ($target - $roughness) * $mask)); break
        }
    }
    $expected = $fixture.expected
    $actualValues = @($actual)
    $expectedValues = @($expected)
    $maximumError = 0.0
    for ($index = 0; $index -lt $expectedValues.Count; $index++) { $maximumError = [Math]::Max($maximumError, [Math]::Abs([double]$actualValues[$index] - [double]$expectedValues[$index])) }
    Add-Check -Id $fixture.id -Pass ($maximumError -le $tolerance) -Detail ('actual=' + ($actualValues -join ', ')) -MaximumError $maximumError
}
$source = Get-Content -LiteralPath (Resolve-Asset $manifest.source) -Raw
$consumer = Get-Content -LiteralPath (Resolve-Asset $manifest.consumer) -Raw
$material = Get-Content -LiteralPath (Resolve-Asset $manifest.material) -Raw
$profile = Get-Content -LiteralPath (Resolve-Asset $manifest.profile) -Raw
foreach ($symbol in @($manifest.publicSymbols)) { Add-Check -Id ('PUBLIC_SYMBOL_' + $symbol) -Pass ($source -match ('\b' + [Regex]::Escape([string]$symbol) + '\b')) -Detail ([string]$symbol) }
Add-Check 'GRAZING_SIGNAL' ($source -match '1\.0h - saturate\(dot\(' -and $source -match 'smoothstep|progress \* progress') 'Edge wear derives a grazing-angle signal'
Add-Check 'BOUNDED_PARAMETERS' ($source -match 'saturate\(config\.threshold\)' -and $source -match 'saturate\(config\.strength\)' -and $source -match 'saturate\(config\.roughnessBoost\)') 'Edge wear parameters are bounded'
Add-Check 'CONSUMER_WIRING' ($consumer -match 'TA_EvaluateEdgeWear\(' -and $consumer -match 'TA_ApplyEdgeWearColor\(' -and $consumer -match 'TA_ApplyEdgeWearRoughness\(') 'BasePass applies edge wear to color and roughness'
Add-Check 'MATERIAL_PARAMETERS' ($material -match '_EdgeWearColor:' -and $material -match '_EdgeWearStrength: 0\.7') 'Material serializes edge wear parameters'
Add-Check 'PROFILE_PARAMETERS' ($profile -match 'edgeWearColor:' -and $profile -match 'edgeWearStrength: 0\.7' -and $profile -match 'edgeWearRoughnessBoost: 0\.35') 'Profile serializes edge wear parameters'
$failed = @($checks | Where-Object { -not $_.pass })
$maximumError = ($checks | ForEach-Object { [double]$_.maximumError } | Measure-Object -Maximum).Maximum
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report = [ordered]@{ status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }; version = $manifest.version; sourceLibraryVersion = $manifest.sourceLibraryVersion; publicSymbolCount = @($manifest.publicSymbols).Count; dependencyCount = @($manifest.dependencies).Count; fixtureCount = @($manifest.fixtures).Count; invariantCount = @($manifest.invariants).Count; limitationCount = @($manifest.limitations).Count; tolerance = $tolerance; maximumError = $maximumError; generatedAtUtc = [DateTime]::UtcNow.ToString('O'); checks = $checks; failures = @($failed | ForEach-Object { $_.id }) }
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
if ($failed.Count -gt 0) { throw ('Edge wear validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', ')) }
Write-Output 'UNITY_EDGE_WEAR: PASS'
Write-Output "Report: $ReportPath"
