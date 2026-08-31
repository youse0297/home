param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\LayeredNormalMaterial.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\LayeredNormalMaterialValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Id, [bool]$Pass, [string]$Detail)
    $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail })
}
function Resolve-Asset { param([string]$Path); return Join-Path $projectPath ($Path -replace '/', '\') }

$materialPath = Resolve-Asset $manifest.material
$profilePath = Resolve-Asset $manifest.profile
$material = if (Test-Path -LiteralPath $materialPath) { Get-Content -LiteralPath $materialPath -Raw } else { '' }
$profile = if (Test-Path -LiteralPath $profilePath) { Get-Content -LiteralPath $profilePath -Raw } else { '' }
Add-Check 'MATERIAL_EXISTS' (Test-Path -LiteralPath $materialPath -PathType Leaf) $manifest.material
Add-Check 'PROFILE_EXISTS' (Test-Path -LiteralPath $profilePath -PathType Leaf) $manifest.profile
Add-Check 'SHADER_BINDING' ($material -match 'm_Name: MAT_LayeredNormal' -and $material -match 'guid: 9d11a224cf8446da9d70751a2ced3fd8') 'TA/BasePass Lighting Decomposition'
Add-Check 'MATERIAL_LAYER_TEXTURES' ($material -match '_BumpMap:' -and $material -match '_DetailNormalMap:' -and $material -match '_MacroNormalMap:' -and $material -match '_ORMMap:') 'Base, detail, macro and ORM texture slots are serialized'
Add-Check 'MATERIAL_LAYER_WEIGHTS' ($material -match '_DetailNormalWeight: 0\.65' -and $material -match '_MacroNormalWeight: 0\.35') 'Serialized layer weights are non-zero'
Add-Check 'PROFILE_LAYER_TEXTURES' ($profile -match 'normal:' -and $profile -match 'detailNormal:' -and $profile -match 'macroNormal:' -and $profile -match 'orm:') 'Profile exposes all material texture inputs'
Add-Check 'PROFILE_LAYER_PARAMETERS' ($profile -match 'normalScale: 1' -and $profile -match 'detailNormalScale: 0\.75' -and $profile -match 'detailNormalWeight: 0\.65' -and $profile -match 'macroNormalScale: 0\.5' -and $profile -match 'macroNormalWeight: 0\.35') 'Profile serializes bounded multi-layer parameters'
Add-Check 'PROFILE_INPUT_POLICY' ($profile -match 'metallic: 0\.15' -and $profile -match 'roughness: 0\.42' -and $profile -match 'occlusionStrength: 1') 'Profile retains PBR input policy'
$failed = @($checks | Where-Object { -not $_.pass })
$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report = [ordered]@{
    status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }
    version = $manifest.version
    sourceLibraryVersion = $manifest.sourceLibraryVersion
    checkCount = $checks.Count
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    failures = @($failed | ForEach-Object { $_.id })
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
if ($failed.Count -gt 0) { throw ('Layered normal material validation failed: ' + (($failed | ForEach-Object { $_.id }) -join ', ')) }
Write-Output 'UNITY_LAYERED_NORMAL_MATERIAL: PASS'
Write-Output "Report: $ReportPath"
