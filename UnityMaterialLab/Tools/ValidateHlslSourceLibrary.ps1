param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\HlslSourceLibrary.json'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\HlslSourceLibraryValidation.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[string]]::new()

function Add-ValidationCheck {
    param(
        [string]$Id,
        [bool]$Pass,
        [string]$Detail
    )

    $checks.Add([ordered]@{
        id = $Id
        pass = $Pass
        detail = $Detail
    })
    if (-not $Pass) {
        $failures.Add($Id)
    }
}

function Resolve-ProjectAssetPath {
    param([string]$RelativePath)
    return Join-Path $projectPath ($RelativePath -replace '/', '\')
}

$moduleIds = [System.Collections.Generic.HashSet[string]]::new()
$moduleFileById = @{}
$publicSymbols = [System.Collections.Generic.HashSet[string]]::new()
$moduleFiles = [System.Collections.Generic.List[string]]::new()

foreach ($module in @($manifest.modules)) {
    $modulePath = Resolve-ProjectAssetPath $module.file
    $moduleFileName = Split-Path -Leaf $modulePath
    $moduleFiles.Add($moduleFileName)
    $sourceExists = Test-Path -LiteralPath $modulePath -PathType Leaf
    Add-ValidationCheck -Id ("MODULE_EXISTS_" + $module.id) -Pass $sourceExists `
        -Detail $module.file

    $source = if ($sourceExists) { Get-Content -LiteralPath $modulePath -Raw } else { '' }
    $guardPattern = '(?m)^#ifndef\s+' + [Regex]::Escape([string]$module.includeGuard) +
        '\s*$[\s\S]*^#define\s+' + [Regex]::Escape([string]$module.includeGuard) + '\s*$'
    Add-ValidationCheck -Id ("INCLUDE_GUARD_" + $module.id) `
        -Pass ([Regex]::IsMatch($source, $guardPattern)) -Detail $module.includeGuard
    Add-ValidationCheck -Id ("NO_PACKAGE_INCLUDE_" + $module.id) `
        -Pass ($source -notmatch '(?m)^\s*#include\s+["<]Packages/') -Detail $module.file

    $dependenciesValid = $true
    foreach ($dependencyId in @($module.dependencies)) {
        if (-not $moduleIds.Contains([string]$dependencyId)) {
            $dependenciesValid = $false
        }
    }
    Add-ValidationCheck -Id ("DEPENDENCY_ORDER_" + $module.id) -Pass $dependenciesValid `
        -Detail ((@($module.dependencies) -join ', '))

    $declaredIncludes = @([Regex]::Matches(
        $source,
        '(?m)^\s*#include\s+"([^"]+\.hlsl)"'
    ) | ForEach-Object { $_.Groups[1].Value })
    $expectedIncludes = @($module.dependencies | ForEach-Object {
        $moduleFileById[[string]$_]
    })
    $includesMatchDependencies = $declaredIncludes.Count -eq $expectedIncludes.Count
    if ($includesMatchDependencies) {
        for ($index = 0; $index -lt $expectedIncludes.Count; $index++) {
            if ($declaredIncludes[$index] -ne $expectedIncludes[$index]) {
                $includesMatchDependencies = $false
                break
            }
        }
    }
    Add-ValidationCheck -Id ("DECLARED_INCLUDES_" + $module.id) `
        -Pass $includesMatchDependencies -Detail ($declaredIncludes -join ', ')

    $symbolsValid = $true
    foreach ($symbol in @($module.publicSymbols)) {
        $symbolText = [string]$symbol
        $declared = $source -match ('\b' + [Regex]::Escape($symbolText) + '\b')
        $prefixed = $symbolText.StartsWith([string]$manifest.namespacePrefix)
        $unique = $publicSymbols.Add($symbolText)
        if (-not ($declared -and $prefixed -and $unique)) {
            $symbolsValid = $false
        }
    }
    Add-ValidationCheck -Id ("PUBLIC_SYMBOLS_" + $module.id) -Pass $symbolsValid `
        -Detail ((@($module.publicSymbols) -join ', '))

    [void]$moduleIds.Add([string]$module.id)
    $moduleFileById[[string]$module.id] = $moduleFileName
}

$aggregatePath = Resolve-ProjectAssetPath $manifest.aggregate.file
$aggregateExists = Test-Path -LiteralPath $aggregatePath -PathType Leaf
$aggregateSource = if ($aggregateExists) { Get-Content -LiteralPath $aggregatePath -Raw } else { '' }
Add-ValidationCheck -Id 'AGGREGATE_EXISTS' -Pass $aggregateExists -Detail $manifest.aggregate.file
$aggregateGuardPattern = '(?m)^#ifndef\s+' + [Regex]::Escape([string]$manifest.aggregate.includeGuard) +
    '\s*$[\s\S]*^#define\s+' + [Regex]::Escape([string]$manifest.aggregate.includeGuard) + '\s*$'
Add-ValidationCheck -Id 'AGGREGATE_GUARD' `
    -Pass ([Regex]::IsMatch($aggregateSource, $aggregateGuardPattern)) `
    -Detail $manifest.aggregate.includeGuard

$aggregateIncludes = @([Regex]::Matches(
    $aggregateSource,
    '(?m)^\s*#include\s+"([^"]+\.hlsl)"'
) | ForEach-Object { $_.Groups[1].Value })
$aggregateOrderValid = $aggregateIncludes.Count -eq $moduleFiles.Count
if ($aggregateOrderValid) {
    for ($index = 0; $index -lt $moduleFiles.Count; $index++) {
        if ($aggregateIncludes[$index] -ne $moduleFiles[$index]) {
            $aggregateOrderValid = $false
            break
        }
    }
}
Add-ValidationCheck -Id 'AGGREGATE_ORDER' -Pass $aggregateOrderValid `
    -Detail ($aggregateIncludes -join ' -> ')

$manifestModuleOrder = @($manifest.modules | ForEach-Object { [string]$_.id })
$manifestAggregateOrder = @($manifest.aggregate.modules | ForEach-Object { [string]$_ })
$manifestOrderValid = $manifestModuleOrder.Count -eq $manifestAggregateOrder.Count
if ($manifestOrderValid) {
    for ($index = 0; $index -lt $manifestModuleOrder.Count; $index++) {
        if ($manifestModuleOrder[$index] -ne $manifestAggregateOrder[$index]) {
            $manifestOrderValid = $false
            break
        }
    }
}
Add-ValidationCheck -Id 'MANIFEST_AGGREGATE_ORDER' -Pass $manifestOrderValid `
    -Detail ($manifestAggregateOrder -join ' -> ')

$consumerPath = Resolve-ProjectAssetPath $manifest.consumer.file
$consumerExists = Test-Path -LiteralPath $consumerPath -PathType Leaf
$consumerSource = if ($consumerExists) { Get-Content -LiteralPath $consumerPath -Raw } else { '' }
Add-ValidationCheck -Id 'CONSUMER_EXISTS' -Pass $consumerExists -Detail $manifest.consumer.file
$consumerIncludePattern = '#include\s+"' + [Regex]::Escape([string]$manifest.consumer.include) + '"'
$consumerWiringValid = $consumerSource -match $consumerIncludePattern
foreach ($entryPoint in @($manifest.consumer.entryPoints)) {
    $consumerWiringValid = $consumerWiringValid -and
        ($consumerSource -match ('\b' + [Regex]::Escape([string]$entryPoint) + '\s*\('))
}
Add-ValidationCheck -Id 'CONSUMER_WIRING' -Pass $consumerWiringValid `
    -Detail ((@($manifest.consumer.entryPoints) -join ', '))

$lightingModule = @($manifest.modules | Where-Object { $_.id -eq 'lighting' })[0]
$lightingPath = Resolve-ProjectAssetPath $lightingModule.file
$lightingSource = if (Test-Path -LiteralPath $lightingPath) {
    Get-Content -LiteralPath $lightingPath -Raw
} else {
    ''
}
Add-ValidationCheck -Id 'ADDITIVE_LIGHTING_INVARIANT' `
    -Pass ($lightingSource -match 'result\.finalLit\s*=\s*result\.directDiffuse\s*\+\s*result\.directSpecular\s*\+\s*result\.indirectDiffuse\s*;') `
    -Detail 'FinalLit = DirectDiffuse + DirectSpecular + IndirectDiffuse'

$normalBlendModule = @($manifest.modules | Where-Object { $_.id -eq 'normalBlend' })[0]
if ($null -ne $normalBlendModule) {
    $normalBlendPath = Resolve-ProjectAssetPath $normalBlendModule.file
    $normalBlendSource = if (Test-Path -LiteralPath $normalBlendPath) {
        Get-Content -LiteralPath $normalBlendPath -Raw
    } else { '' }
    Add-ValidationCheck -Id 'NORMAL_BLEND_CONTRACT' `
        -Pass ($normalBlendSource -match 'TA_NormalLayerTS' -and
            $normalBlendSource -match 'TA_BlendNormalRNMTS' -and
            $normalBlendSource -match 'TA_ApplyNormalLayerTS' -and
            $normalBlendSource -match 'TA_ComposeNormalLayersTS' -and
            $normalBlendSource -match 'saturate\(layer\.weight\)' -and
            $normalBlendSource -match 'TA_SafeNormalize\(lerp') `
        -Detail 'Normal layers use RNM, bounded weights and safe renormalization'
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report = [ordered]@{
    status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
    version = $manifest.version
    moduleCount = @($manifest.modules).Count
    publicSymbolCount = $publicSymbols.Count
    aggregate = $manifest.aggregate.file
    consumer = $manifest.consumer.file
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    failures = $failures
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($failures.Count -gt 0) {
    throw ('HLSL source library validation failed: ' + ($failures -join ', '))
}

Write-Output 'UNITY_HLSL_SOURCE_LIBRARY: PASS'
Write-Output "Report: $ReportPath"
