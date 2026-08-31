param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\NormalLayerBlending.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\NormalLayerBlendingValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$tolerance = 0.000001

function Convert-ToVector { param($Value); return @($Value | ForEach-Object { [double]$_ }) }
function Safe-Normalize {
    param([double[]]$Value)
    $x = [double]($Value[0]); $y = [double]($Value[1]); $z = [double]($Value[2])
    $lengthSquared = ([double]$x * [double]$x) + ([double]$y * [double]$y) + ([double]$z * [double]$z)
    $length = [double]([Math]::Sqrt([double]$lengthSquared))
    if ($length -le 0.000001) { return ,([double[]]@(0.0, 0.0, 1.0)) }
    $normalizedX = [double]$x / [double]$length
    $normalizedY = [double]$y / [double]$length
    $normalizedZ = [double]$z / [double]$length
    return ,([double[]]@($normalizedX, $normalizedY, $normalizedZ))
}
function Cross {
    param([double[]]$Left, [double[]]$Right)
    $leftX = [double]($Left[0]); $leftY = [double]($Left[1]); $leftZ = [double]($Left[2])
    $rightX = [double]($Right[0]); $rightY = [double]($Right[1]); $rightZ = [double]($Right[2])
    $crossX = $leftY * $rightZ - $leftZ * $rightY
    $crossY = $leftZ * $rightX - $leftX * $rightZ
    $crossZ = $leftX * $rightY - $leftY * $rightX
    return ,([double[]]@($crossX, $crossY, $crossZ))
}
function Dot { param([double[]]$Left, [double[]]$Right); return $Left[0] * $Right[0] + $Left[1] * $Right[1] + $Left[2] * $Right[2] }
function Reorient {
    param([double[]]$Base, [double[]]$Detail)
    $baseNormal = Safe-Normalize $Base
    $detailNormal = Safe-Normalize $Detail
    $reference = if ([Math]::Abs($baseNormal[2]) -lt 0.999) { [double[]]@(0.0, 0.0, 1.0) } else { [double[]]@(0.0, 1.0, 0.0) }
    $tangent = Safe-Normalize (Cross $reference $baseNormal)
    $bitangent = Cross $baseNormal $tangent
    $x = [double]($tangent[0]) * [double]($detailNormal[0]) + [double]($bitangent[0]) * [double]($detailNormal[1]) + [double]($baseNormal[0]) * [double]($detailNormal[2])
    $y = [double]($tangent[1]) * [double]($detailNormal[0]) + [double]($bitangent[1]) * [double]($detailNormal[1]) + [double]($baseNormal[1]) * [double]($detailNormal[2])
    $z = [double]($tangent[2]) * [double]($detailNormal[0]) + [double]($bitangent[2]) * [double]($detailNormal[1]) + [double]($baseNormal[2]) * [double]($detailNormal[2])
    return ,(Safe-Normalize ([double[]]@($x, $y, $z)))
}
function Lerp-Vector {
    param([double[]]$Left, [double[]]$Right, [double]$Weight)
    $clamped = [Math]::Max(0.0, [Math]::Min(1.0, $Weight))
    $x = [double]($Left[0]) + ([double]($Right[0]) - [double]($Left[0])) * $clamped
    $y = [double]($Left[1]) + ([double]($Right[1]) - [double]($Left[1])) * $clamped
    $z = [double]($Left[2]) + ([double]($Right[2]) - [double]($Left[2])) * $clamped
    return ,(Safe-Normalize ([double[]]@($x, $y, $z)))
}
function Compose {
    param($Fixture)
    $result = Safe-Normalize (Convert-ToVector $Fixture.input.base)
    $detail = Reorient $result (Convert-ToVector $Fixture.input.detail)
    $result = Lerp-Vector $result $detail ([double]$Fixture.input.detailWeight)
    $macro = Reorient $result (Convert-ToVector $Fixture.input.macro)
    return Lerp-Vector $result $macro ([double]$Fixture.input.macroWeight)
}
function Add-Check {
    param([string]$Id, [bool]$Pass, [string]$Detail, [double]$MaximumError = 0.0)
    $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail; maximumError = $MaximumError })
}
foreach ($fixture in @($manifest.fixtures)) {
    $actual = Compose $fixture
    $expected = Convert-ToVector $fixture.expected
    $maximumError = 0.0
    for ($index = 0; $index -lt 3; $index++) {
        $maximumError = [Math]::Max($maximumError, [Math]::Abs($actual[$index] - $expected[$index]))
    }
    Add-Check -Id $fixture.id -Pass ($maximumError -le $tolerance) -Detail ('actual=' + ($actual -join ', ')) -MaximumError $maximumError
}
$sourcePath = Join-Path $projectPath ($manifest.source -replace '/', '\')
$consumerPath = Join-Path $projectPath ($manifest.consumer -replace '/', '\')
$source = Get-Content -LiteralPath $sourcePath -Raw
$consumer = Get-Content -LiteralPath $consumerPath -Raw
foreach ($symbol in @($manifest.publicSymbols)) {
    Add-Check -Id ('PUBLIC_SYMBOL_' + $symbol) -Pass ($source -match ('\b' + [Regex]::Escape([string]$symbol) + '\b')) -Detail ([string]$symbol)
}
Add-Check -Id 'RNM_FRAME_CONTRACT' -Pass ($source -match 'cross\(reference, base\)' -and $source -match 'tangent \* detail\.x' -and $source -match 'TA_SafeNormalize\(\s*\r?\n\s*tangent') -Detail 'Stable tangent frame reorients each detail normal'
Add-Check -Id 'WEIGHT_POLICY' -Pass ($source -match 'saturate\(layer\.weight\)' -and $source -match 'lerp\(') -Detail 'Layer weights are clamped before blending'
Add-Check -Id 'CONSUMER_WIRING' -Pass ($consumer -match '_DetailNormalMap' -and $consumer -match '_MacroNormalMap' -and $consumer -match 'TA_ComposeNormalLayersTS\(') -Detail $manifest.consumer
Add-Check -Id 'NO_INLINE_NORMAL_COMPOSITION' -Pass ($consumer -notmatch 'normalTS\s*\+=') -Detail 'BasePass delegates normal layer composition to TA_NormalBlend'
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
if ($failed.Count -gt 0) { throw ('Normal layer blending validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', ')) }
Write-Output 'UNITY_NORMAL_LAYER_BLENDING: PASS'
Write-Output "Report: $ReportPath"
