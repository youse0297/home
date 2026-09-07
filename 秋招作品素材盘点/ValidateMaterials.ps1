param(
    [string]$ReportPath = (Join-Path $PSScriptRoot 'MaterialInventoryValidation.json')
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$checks = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Check {
    param([string]$Id, [bool]$Pass, [string]$Detail)
    $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail })
    if (-not $Pass) { $failures.Add($Id) }
}

$allFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File)
$markdownFiles = @($allFiles | Where-Object { $_.Extension -eq '.md' })
$jsonFiles = @($allFiles | Where-Object { $_.Extension -eq '.json' -and $_.FullName -ne $ReportPath })
$imageFiles = @($allFiles | Where-Object { $_.Extension -in '.png', '.ppm' })
$videoFiles = @($allFiles | Where-Object { $_.Extension -in '.mp4', '.mov', '.webm' })
$zipFiles = @($allFiles | Where-Object { $_.Extension -eq '.zip' })

Add-Check 'README' (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'README.md')) 'Inventory navigation exists'
Add-Check 'MARKDOWN_COUNT' ($markdownFiles.Count -ge 12) 'Inventory, evidence and checklist documents are present'
Add-Check 'IMAGE_COUNT' ($imageFiles.Count -ge 9) 'Direct-use and offline-reference images are present'
Add-Check 'RELEASE_COUNT' ($zipFiles.Count -eq 2) 'CPU snapshot and HLSL release archives are present'
Add-Check 'VIDEO_GAP_RECORDED' ($videoFiles.Count -eq 0) 'No video is present; the gap board must remain open'

$hlslArchive = $zipFiles | Where-Object { $_.Name -eq 'TA_HLSL_MaterialLibrary_v1.0.0.zip' } | Select-Object -First 1
$hlslChecksum = $allFiles | Where-Object { $_.Name -eq 'TA_HLSL_MaterialLibrary_v1.0.0.sha256' } | Select-Object -First 1
$hlslHash = if ($hlslArchive) {
    (Get-FileHash -LiteralPath $hlslArchive.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
} else { '' }
$checksumText = if ($hlslChecksum) { (Get-Content -LiteralPath $hlslChecksum.FullName -Raw).Trim() } else { '' }
Add-Check 'HLSL_ARCHIVE_HASH' ($hlslHash -eq '70a8abf77aef7de6bb1750deae824de961493f3aed2f099daaa65653f5236990' -and
    $checksumText.StartsWith($hlslHash)) 'HLSL v1.0 archive matches the frozen checksum'

$reports = [System.Collections.Generic.List[object]]::new()
foreach ($file in $jsonFiles) {
    try { $reports.Add((Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json)) }
    catch { Add-Check ('JSON_' + $file.BaseName) $false 'JSON report could not be parsed' }
}
$stageReport = $reports | Where-Object { $null -ne $_.requiredGateCount } | Select-Object -First 1
$hlslReport = $reports | Where-Object { $null -ne $_.validatorCount } | Select-Object -First 1
$showcaseReport = $reports | Where-Object { $null -ne $_.showcaseCount } | Select-Object -First 1
$basePassReport = $reports | Where-Object { $null -ne $_.viewCount } | Select-Object -First 1
$compressionReport = $reports | Where-Object { $null -ne $_.formatBytes } | Select-Object -First 1
$lodReport = $reports | Where-Object { $null -ne $_.switches } | Select-Object -First 1

Add-Check 'STAGE_REPORT' ($stageReport.status -eq 'CONDITIONAL_PASS' -and
    $stageReport.passedRequiredGateCount -eq 26 -and $stageReport.requiredGateCount -eq 26 -and
    @($stageReport.blockers).Count -eq 2) 'Stage 1 keeps 26/26 required gates and two external blockers'
Add-Check 'HLSL_REPORT' ($hlslReport.status -eq 'PASS' -and
    $hlslReport.passedValidatorCount -eq 18 -and $hlslReport.validatorCount -eq 18 -and
    $hlslReport.moduleCount -eq 18 -and $hlslReport.hlslFileCount -eq 19 -and
    $hlslReport.publicSymbolCount -eq 74 -and $hlslReport.sourceLibraryCheckCount -eq 116 -and
    $hlslReport.compiler.warningCount -eq 0 -and $hlslReport.release.sha256 -eq $hlslHash) `
    'HLSL inventory claims match the acceptance report'
Add-Check 'SHOWCASE_REPORT' ($showcaseReport.status -eq 'PASS' -and
    $showcaseReport.showcaseCount -eq 6 -and $showcaseReport.uniqueMaterialCount -eq 6) `
    'Showcase report keeps six static showcase definitions'
Add-Check 'BASEPASS_REPORT' ($basePassReport.status -eq 'PASS' -and
    $basePassReport.viewCount -eq 10 -and $basePassReport.additiveInvariantDelta -eq 0) `
    'BasePass report keeps ten views and zero additive delta'
Add-Check 'COMPRESSION_REPORT' ($compressionReport.status -eq 'PASS' -and
    $compressionReport.formatBytes.RGBA32 -eq 21844 -and $compressionReport.formatBytes.BC1 -eq 2744) `
    'Compression report keeps the documented 64x64 full-mip byte baseline'
Add-Check 'LOD_REPORT' ($lodReport.status -eq 'PASS' -and @($lodReport.switches).Count -eq 4) `
    'LOD report keeps four fixed switch checks'

$remote = (& git -C $repoRoot remote get-url origin 2>$null).Trim()
$head = (& git -C $repoRoot rev-parse HEAD 2>$null).Trim()
$originMain = (& git -C $repoRoot rev-parse refs/remotes/origin/main 2>$null).Trim()
$aheadBehind = (& git -C $repoRoot rev-list --left-right --count refs/remotes/origin/main...HEAD 2>$null).Trim()
Add-Check 'GIT_REMOTE' ($remote -eq 'https://github.com/youse0297/home.git') 'Expected GitHub remote is configured'
Add-Check 'GIT_HEAD' ($head -eq 'c5758c5a544b774bb96903a2b0ce06dd320fb26e') 'Inventory snapshot matches the HLSL acceptance commit'
Add-Check 'REMOTE_GAP_RECORDED' ($aheadBehind -match '^0\s+1$' -and
    $originMain -eq '6d5b395db82494b092cdd137a38061d7478f00c3') `
    'Local main is one commit ahead of the recorded remote branch'

$fileRecords = @($allFiles | Where-Object { $_.FullName -ne $ReportPath } | Sort-Object FullName |
    ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($PSScriptRoot.Length + 1).Replace('\', '/')
            bytes = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })

$status = if ($failures.Count -eq 0) { 'PASS_WITH_EXTERNAL_GAPS' } else { 'FAIL' }
$report = [ordered]@{
    status = $status
    snapshotDate = '2026-09-07'
    git = [ordered]@{ remote = $remote; head = $head; originMain = $originMain; aheadBehind = $aheadBehind }
    inventory = [ordered]@{
        files = $fileRecords.Count
        markdown = $markdownFiles.Count
        images = $imageFiles.Count
        videos = $videoFiles.Count
        archives = $zipFiles.Count
    }
    checks = $checks
    failures = $failures
    files = $fileRecords
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($failures.Count -gt 0) {
    throw ('Recruiting material inventory validation failed: ' + ($failures -join ', '))
}

Write-Output 'RECRUITING_MATERIAL_INVENTORY: PASS_WITH_EXTERNAL_GAPS'
Write-Output "Report: $ReportPath"
