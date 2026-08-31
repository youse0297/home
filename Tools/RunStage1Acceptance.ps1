param(
    [string]$BuildDirectory = '',
    [string]$Configuration = 'Debug',
    [switch]$SkipConfigure,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $BuildDirectory) {
    $BuildDirectory = Join-Path $repoRoot 'build'
} elseif (-not [System.IO.Path]::IsPathRooted($BuildDirectory)) {
    $BuildDirectory = Join-Path $repoRoot $BuildDirectory
}
$outputDirectory = Join-Path $repoRoot 'output'
$reportPath = Join-Path $outputDirectory 'Stage1AcceptanceReport.json'
$summaryPath = Join-Path $outputDirectory 'Stage1AcceptanceSummary.md'
$unityRoot = Join-Path $repoRoot 'UnityMaterialLab'
$unityTools = Join-Path $unityRoot 'Tools'
$unityReports = Join-Path $unityRoot 'Reports'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$gates = [System.Collections.Generic.List[object]]::new()

function Resolve-BuildTool {
    param(
        [string]$CommandName,
        [string]$CacheKey
    )

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $cachePath = Join-Path $BuildDirectory 'CMakeCache.txt'
    if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
        $match = Select-String -LiteralPath $cachePath -Pattern ('^' + $CacheKey + ':INTERNAL=(.+)$') |
            Select-Object -First 1
        if ($match) {
            $candidate = $match.Matches[0].Groups[1].Value -replace '/', '\'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    }
    return $null
}

function New-GateResult {
    param(
        [string]$Name,
        [string]$Category,
        [bool]$Required,
        [string]$Status,
        [string]$Evidence,
        [string]$Detail,
        [int]$ExitCode = 0,
        [string[]]$OutputTail = @()
    )

    return [pscustomobject][ordered]@{
        name = $Name
        category = $Category
        required = $Required
        status = $Status
        evidence = $Evidence
        detail = $Detail
        exitCode = $ExitCode
        outputTail = $OutputTail
    }
}

function Invoke-ProcessGate {
    param(
        [string]$Name,
        [string]$Category,
        [bool]$Required,
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [string]$ExpectedPattern,
        [string]$Evidence
    )

    Write-Host ("[{0}] running" -f $Name)
    $outputLines = @()
    $exitCode = -1
    Push-Location $WorkingDirectory
    try {
        $outputLines = @(& $Executable @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    catch {
        $outputLines += $_.Exception.Message
    }
    finally {
        Pop-Location
    }

    $patternMatched = -not $ExpectedPattern -or
        (($outputLines -join [Environment]::NewLine) -match $ExpectedPattern)
    $status = if ($exitCode -eq 0 -and $patternMatched) { 'PASS' } else { 'FAIL' }
    $detail = if ($status -eq 'PASS') {
        'Command completed with the required acceptance marker.'
    } elseif ($exitCode -ne 0) {
        'Command failed with exit code ' + $exitCode + '.'
    } else {
        'Command completed but the required acceptance marker was missing.'
    }
    $tail = @($outputLines | Select-Object -Last 16)
    return New-GateResult -Name $Name -Category $Category -Required $Required `
        -Status $status -Evidence $Evidence -Detail $detail -ExitCode $exitCode `
        -OutputTail $tail
}

function Read-JsonReport {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Add-ScriptGate {
    param(
        [string]$Name,
        [string]$ScriptName,
        [string]$ExpectedPattern,
        [string]$Evidence,
        [string]$ReportName = '',
        [string]$ExpectedReportStatus = 'PASS'
    )

    $powerShellPath = Join-Path $PSHOME 'powershell.exe'
    $scriptPath = Join-Path $unityTools $ScriptName
    $result = Invoke-ProcessGate -Name $Name -Category 'Unity Offline' -Required $true `
        -Executable $powerShellPath `
        -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) `
        -WorkingDirectory $unityRoot -ExpectedPattern $ExpectedPattern -Evidence $Evidence
    if ($result.status -eq 'PASS' -and $ReportName) {
        $report = Read-JsonReport (Join-Path $unityReports $ReportName)
        if ($null -eq $report -or $report.status -ne $ExpectedReportStatus) {
            $result.status = 'FAIL'
            $result.detail = 'Generated report is missing, invalid, or does not contain status ' +
                $ExpectedReportStatus + '.'
        } else {
            $result.detail = 'Command and generated JSON report both passed.'
        }
    }
    $gates.Add($result)
}

$cmakePath = Resolve-BuildTool -CommandName 'cmake.exe' -CacheKey 'CMAKE_COMMAND'
$ctestPath = Resolve-BuildTool -CommandName 'ctest.exe' -CacheKey 'CMAKE_CTEST_COMMAND'

if ($SkipConfigure) {
    $gates.Add((New-GateResult -Name 'CMake Configure' -Category 'CPU Renderer' `
        -Required $true -Status 'PASS' -Evidence 'build/CMakeCache.txt' `
        -Detail 'Skipped by request; the existing CMake cache is used.'))
} elseif (-not $cmakePath) {
    $gates.Add((New-GateResult -Name 'CMake Configure' -Category 'CPU Renderer' `
        -Required $true -Status 'FAIL' -Evidence 'build/CMakeCache.txt' `
        -Detail 'cmake.exe could not be resolved from PATH or the existing CMake cache.' -ExitCode -1))
} else {
    $gates.Add((Invoke-ProcessGate -Name 'CMake Configure' -Category 'CPU Renderer' `
        -Required $true -Executable $cmakePath `
        -Arguments @('-S', $repoRoot, '-B', $BuildDirectory) -WorkingDirectory $repoRoot `
        -ExpectedPattern 'Build files have been written|Configuring done' `
        -Evidence 'build/CMakeCache.txt'))
}

if ($SkipBuild) {
    $gates.Add((New-GateResult -Name 'Debug Build' -Category 'CPU Renderer' `
        -Required $true -Status 'PASS' -Evidence 'build/Debug' `
        -Detail 'Skipped by request; existing Debug binaries are used.'))
} elseif (-not $cmakePath) {
    $gates.Add((New-GateResult -Name 'Debug Build' -Category 'CPU Renderer' `
        -Required $true -Status 'FAIL' -Evidence 'build/Debug' `
        -Detail 'cmake.exe is unavailable.' -ExitCode -1))
} else {
    $gates.Add((Invoke-ProcessGate -Name 'Debug Build' -Category 'CPU Renderer' `
        -Required $true -Executable $cmakePath `
        -Arguments @('--build', $BuildDirectory, '--config', $Configuration, '--parallel') `
        -WorkingDirectory $repoRoot -ExpectedPattern 'release_acceptance\.vcxproj|Built target release_acceptance' `
        -Evidence 'build/Debug/release_acceptance.exe'))
}

if (-not $ctestPath) {
    $gates.Add((New-GateResult -Name 'CTest 12/12' -Category 'CPU Renderer' `
        -Required $true -Status 'FAIL' -Evidence 'build/Testing/Temporary/LastTest.log' `
        -Detail 'ctest.exe could not be resolved from PATH or the existing CMake cache.' -ExitCode -1))
} else {
    $ctestResult = Invoke-ProcessGate -Name 'CTest 12/12' -Category 'CPU Renderer' `
        -Required $true -Executable $ctestPath `
        -Arguments @('--test-dir', $BuildDirectory, '-C', $Configuration, '--output-on-failure') `
        -WorkingDirectory $repoRoot `
        -ExpectedPattern '100% tests passed, 0 tests failed out of 12' `
        -Evidence 'build/Testing/Temporary/LastTest.log'
    if ($ctestResult.status -eq 'PASS') {
        $ctestResult.detail = 'All 12 CPU renderer acceptance tests passed.'
    }
    $gates.Add($ctestResult)
}

$releaseImagePath = Join-Path $BuildDirectory 'release_acceptance.ppm'
$releaseHeader = @()
if (Test-Path -LiteralPath $releaseImagePath -PathType Leaf) {
    $releaseHeader = @(Get-Content -LiteralPath $releaseImagePath -Encoding Byte -TotalCount 2)
}
$releaseArtifactPass = $releaseHeader.Count -eq 2 -and
    $releaseHeader[0] -eq [byte][char]'P' -and $releaseHeader[1] -eq [byte][char]'6'
$gates.Add((New-GateResult -Name 'Release PPM Artifact' -Category 'CPU Renderer' `
    -Required $true -Status $(if ($releaseArtifactPass) { 'PASS' } else { 'FAIL' }) `
    -Evidence 'build/release_acceptance.ppm' `
    -Detail $(if ($releaseArtifactPass) {
        'The release acceptance produced a P6 image artifact; its fixed checksum is covered by CTest.'
    } else {
        'The release P6 image artifact is missing or has an invalid header.'
    })))

Add-ScriptGate -Name 'Material Boundary Matrix' -ScriptName 'GenerateBoundaryBoard.ps1' `
    -ExpectedPattern 'Material boundary board:' `
    -Evidence 'UnityMaterialLab/Reports/MaterialBoundaryBoard.png'
Add-ScriptGate -Name 'Material Function Library' -ScriptName 'ValidateMaterialFunctionLibrary.ps1' `
    -ExpectedPattern 'UNITY_MATERIAL_FUNCTION_LIBRARY_V1: PASS' `
    -Evidence 'UnityMaterialLab/Reports/MaterialFunctionLibraryValidation.json' `
    -ReportName 'MaterialFunctionLibraryValidation.json'
Add-ScriptGate -Name 'Texture Compression' -ScriptName 'GenerateTextureCompressionBoard.ps1' `
    -ExpectedPattern 'UNITY_TEXTURE_COMPRESSION_ACCEPTANCE: PASS' `
    -Evidence 'UnityMaterialLab/Reports/TextureCompressionValidation.json' `
    -ReportName 'TextureCompressionValidation.json'
Add-ScriptGate -Name 'LOD Baseline' -ScriptName 'GenerateLodBoard.ps1' `
    -ExpectedPattern 'UNITY_LOD_ACCEPTANCE: PASS' `
    -Evidence 'UnityMaterialLab/Reports/LODValidationReport.json' `
    -ReportName 'LODValidationReport.json'
Add-ScriptGate -Name 'BasePass Lighting Decomposition' `
    -ScriptName 'GenerateBasePassLightingBoard.ps1' `
    -ExpectedPattern 'UNITY_BASEPASS_LIGHTING_ACCEPTANCE: PASS' `
    -Evidence 'UnityMaterialLab/Reports/BasePassLightingValidation.json' `
    -ReportName 'BasePassLightingValidation.json'
Add-ScriptGate -Name 'Direct-light PBR Integration' `
    -ScriptName 'ValidateDirectLightPbrIntegration.ps1' `
    -ExpectedPattern 'UNITY_DIRECT_LIGHT_PBR_INTEGRATION: PASS' `
    -Evidence 'UnityMaterialLab/Reports/DirectLightPbrIntegrationValidation.json' `
    -ReportName 'DirectLightPbrIntegrationValidation.json'
Add-ScriptGate -Name 'PBR Parameter Regression' `
    -ScriptName 'ValidatePbrParameterRegression.ps1' `
    -ExpectedPattern 'UNITY_PBR_PARAMETER_REGRESSION: PASS' `
    -Evidence 'UnityMaterialLab/Reports/PbrParameterRegressionValidation.json' `
    -ReportName 'PbrParameterRegressionValidation.json'
Add-ScriptGate -Name 'Vertex Displacement Basics' `
    -ScriptName 'ValidateVertexDisplacementBasics.ps1' `
    -ExpectedPattern 'UNITY_VERTEX_DISPLACEMENT_BASICS: PASS' `
    -Evidence 'UnityMaterialLab/Reports/VertexDisplacementBasicsValidation.json' `
    -ReportName 'VertexDisplacementBasicsValidation.json'
Add-ScriptGate -Name 'Wave and Wind Animation' `
    -ScriptName 'ValidateWaveWindAnimation.ps1' `
    -ExpectedPattern 'UNITY_WAVE_WIND_ANIMATION: PASS' `
    -Evidence 'UnityMaterialLab/Reports/WaveWindAnimationValidation.json' `
    -ReportName 'WaveWindAnimationValidation.json'
Add-ScriptGate -Name 'Vertex Displacement Modularization' `
    -ScriptName 'ValidateVertexDisplacementModularization.ps1' `
    -ExpectedPattern 'UNITY_VERTEX_DISPLACEMENT_MODULARIZATION: PASS' `
    -Evidence 'UnityMaterialLab/Reports/VertexDisplacementModularizationValidation.json' `
    -ReportName 'VertexDisplacementModularizationValidation.json'
Add-ScriptGate -Name 'Normal Layer Blending' `
    -ScriptName 'ValidateNormalLayerBlending.ps1' `
    -ExpectedPattern 'UNITY_NORMAL_LAYER_BLENDING: PASS' `
    -Evidence 'UnityMaterialLab/Reports/NormalLayerBlendingValidation.json' `
    -ReportName 'NormalLayerBlendingValidation.json'
Add-ScriptGate -Name 'Layered Normal Material' `
    -ScriptName 'ValidateLayeredNormalMaterial.ps1' `
    -ExpectedPattern 'UNITY_LAYERED_NORMAL_MATERIAL: PASS' `
    -Evidence 'UnityMaterialLab/Reports/LayeredNormalMaterialValidation.json' `
    -ReportName 'LayeredNormalMaterialValidation.json'
Add-ScriptGate -Name 'Unity Static Validation' -ScriptName 'StaticValidate.ps1' `
    -ExpectedPattern 'UNITY_PROJECT_STATIC_ACCEPTANCE: PASS' `
    -Evidence 'UnityMaterialLab/Reports/StaticValidation.json' `
    -ReportName 'StaticValidation.json'

$powerShellPath = Join-Path $PSHOME 'powershell.exe'
$renderDocResult = Invoke-ProcessGate -Name 'RenderDoc Capture Readiness' `
    -Category 'External Runtime' -Required $false -Executable $powerShellPath `
    -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
        (Join-Path $unityTools 'RenderDocCaptureCheck.ps1')) `
    -WorkingDirectory $unityRoot -ExpectedPattern 'RENDERDOC_CAPTURE_READINESS:' `
    -Evidence 'UnityMaterialLab/Reports/RenderDocCaptureReadiness.json'
$renderDocReport = Read-JsonReport (Join-Path $unityReports 'RenderDocCaptureReadiness.json')
if ($renderDocResult.status -eq 'PASS' -and $renderDocReport) {
    if ($renderDocReport.status -eq 'READY_TO_CAPTURE') {
        $renderDocResult.detail = 'RenderDoc and Unity are available for the prepared capture workflow.'
    } else {
        $renderDocResult.status = 'BLOCKED'
        $renderDocResult.detail = 'RenderDoc capture remains blocked because RenderDoc is not installed.'
    }
}
$gates.Add($renderDocResult)

$staticReport = Read-JsonReport (Join-Path $unityReports 'StaticValidation.json')
$editorStatus = if ($staticReport) { $staticReport.editorRuntimeValidation } else { '' }
if ($editorStatus -eq 'BLOCKED_LICENSE') {
    $gates.Add((New-GateResult -Name 'Unity Editor Runtime Validation' `
        -Category 'External Runtime' -Required $false -Status 'BLOCKED' `
        -Evidence 'UnityMaterialLab/Reports/EDITOR_VALIDATION_BLOCKED.md' `
        -Detail 'Unity Editor scene generation and shader import remain blocked by the local license entitlement.'))
} else {
    $gates.Add((New-GateResult -Name 'Unity Editor Runtime Validation' `
        -Category 'External Runtime' -Required $false -Status 'PASS' `
        -Evidence 'UnityMaterialLab/Assets/_TA/Documentation/ImportValidation.json' `
        -Detail 'No Unity Editor license blocker is recorded by the static report.'))
}

$requiredFailures = @($gates | Where-Object { $_.required -and $_.status -ne 'PASS' })
$blockers = @($gates | Where-Object { $_.status -eq 'BLOCKED' })
$offlineStatus = if ($requiredFailures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$runtimeStatus = if ($blockers.Count -eq 0) { 'PASS' } else { 'BLOCKED' }
$stageStatus = if ($requiredFailures.Count -gt 0) {
    'FAIL'
} elseif ($blockers.Count -gt 0) {
    'CONDITIONAL_PASS'
} else {
    'PASS'
}

$report = [ordered]@{
    status = $stageStatus
    phase = 'Stage 1'
    offlineAcceptance = $offlineStatus
    externalRuntimeAcceptance = $runtimeStatus
    requiredGateCount = @($gates | Where-Object { $_.required }).Count
    passedRequiredGateCount = @($gates | Where-Object { $_.required -and $_.status -eq 'PASS' }).Count
    blockerCount = $blockers.Count
    configuration = $Configuration
    buildDirectory = $BuildDirectory
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    gates = $gates
    blockers = @($blockers | ForEach-Object {
        [ordered]@{ name = $_.name; evidence = $_.evidence; detail = $_.detail }
    })
    artifacts = @(
        'build/release_acceptance.ppm',
        'UnityMaterialLab/Reports/MaterialBoundaryBoard.png',
        'UnityMaterialLab/Reports/TextureCompressionBoard.png',
        'UnityMaterialLab/Reports/LODComparisonBoard.png',
        'UnityMaterialLab/Reports/BasePassLightingDecompositionBoard.png',
        'UnityMaterialLab/Reports/DirectLightPbrIntegrationValidation.json',
        'UnityMaterialLab/Reports/PbrParameterRegressionValidation.json',
        'UnityMaterialLab/Reports/VertexDisplacementBasicsValidation.json',
        'UnityMaterialLab/Reports/WaveWindAnimationValidation.json',
        'UnityMaterialLab/Reports/VertexDisplacementModularizationValidation.json',
        'UnityMaterialLab/Reports/NormalLayerBlendingValidation.json',
        'UnityMaterialLab/Reports/LayeredNormalMaterialValidation.json',
        'UnityMaterialLab/Reports/StaticValidation.json'
    )
}
$report | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$summaryLines = [System.Collections.Generic.List[string]]::new()
$summaryLines.Add('# Stage 1 Acceptance')
$summaryLines.Add('')
$summaryLines.Add('- Overall status: `' + $stageStatus + '`')
$summaryLines.Add('- Required offline gates: `' + $report.passedRequiredGateCount + '/' + $report.requiredGateCount + '`')
$summaryLines.Add('- External runtime acceptance: `' + $runtimeStatus + '`')
$summaryLines.Add('- Generated at (UTC): `' + $report.generatedAtUtc + '`')
$summaryLines.Add('')
$summaryLines.Add('## Gate Results')
$summaryLines.Add('')
$summaryLines.Add('| Gate | Category | Required | Status | Evidence |')
$summaryLines.Add('| --- | --- | --- | --- | --- |')
foreach ($gate in $gates) {
    $summaryLines.Add('| ' + $gate.name + ' | ' + $gate.category + ' | ' +
        $(if ($gate.required) { 'Yes' } else { 'No' }) + ' | `' + $gate.status + '` | `' +
        $gate.evidence + '` |')
}
$summaryLines.Add('')
$summaryLines.Add('## Conclusion')
$summaryLines.Add('')
if ($stageStatus -eq 'PASS') {
    $summaryLines.Add('All Stage 1 offline and external runtime gates passed.')
} elseif ($stageStatus -eq 'CONDITIONAL_PASS') {
    $summaryLines.Add('All required offline gates passed. External tooling or license blockers remain and must be validated before release.')
} else {
    $summaryLines.Add('At least one required Stage 1 gate failed.')
}
if ($blockers.Count -gt 0) {
    $summaryLines.Add('')
    $summaryLines.Add('## Blockers')
    $summaryLines.Add('')
    foreach ($blocker in $blockers) {
        $summaryLines.Add('- `' + $blocker.name + '`: ' + $blocker.detail + ' Evidence: `' +
            $blocker.evidence + '`')
    }
}
$summaryLines | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if ($stageStatus -eq 'FAIL') {
    Write-Output 'STAGE1_ACCEPTANCE: FAIL'
    Write-Output "Report: $reportPath"
    Write-Output "Summary: $summaryPath"
    exit 1
}

Write-Output ('STAGE1_ACCEPTANCE: ' + $stageStatus)
Write-Output "Report: $reportPath"
Write-Output "Summary: $summaryPath"
