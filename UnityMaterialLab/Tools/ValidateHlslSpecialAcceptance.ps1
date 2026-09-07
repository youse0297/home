param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\HlslSpecialAcceptance.json'),
    [string]$SourceManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\HlslSourceLibrary.json'),
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\Assets\_TA\Shaders\Library'),
    [string]$SmokeShaderPath = (Join-Path $PSScriptRoot 'HlslReleaseSmoke.hlsl'),
    [string]$FxcPath = '',
    [string]$ReleaseDirectory = (Join-Path $PSScriptRoot '..\Releases'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\HlslSpecialAcceptance.json')
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repositoryPath = (Resolve-Path (Join-Path $projectPath '..')).Path
$reportsPath = Split-Path -Parent $ReportPath
$scratchPath = Join-Path $reportsPath 'HlslSpecialAcceptanceScratch'
$releaseName = 'TA_HLSL_MaterialLibrary_v1.0.0'
$archivePath = Join-Path $ReleaseDirectory ($releaseName + '.zip')
$checksumPath = Join-Path $ReleaseDirectory ($releaseName + '.sha256')
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$checks = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[string]]::new()
$validatorResults = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Id, [bool]$Pass, [string]$Detail)
    $checks.Add([ordered]@{ id = $Id; pass = $Pass; detail = $Detail })
    if (-not $Pass) { $failures.Add($Id) }
}

function Resolve-ProjectPath {
    param([string]$RelativePath)
    return Join-Path $projectPath ($RelativePath -replace '/', '\')
}

function Get-PortableRelativePath {
    param([string]$Root, [string]$Path)
    $rootUri = New-Object System.Uri(($Root.TrimEnd('\') + '\'))
    $pathUri = New-Object System.Uri($Path)
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString())
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Resolve-FxcPath {
    param([string]$RequestedPath)
    if ($RequestedPath -and (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }
    $command = Get-Command 'fxc.exe' -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $kitsRoot = Get-ItemPropertyValue `
        -Path 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' `
        -Name 'KitsRoot10' -ErrorAction SilentlyContinue
    if ($kitsRoot) {
        $candidate = Get-ChildItem -Path (Join-Path $kitsRoot 'bin\*\x64\fxc.exe') `
            -File -ErrorAction SilentlyContinue | Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    return $null
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function New-DeterministicArchive {
    param([string]$Root, [string]$OutputPath)
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
    $fileStream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::CreateNew)
    $archive = New-Object System.IO.Compression.ZipArchive(
        $fileStream,
        [System.IO.Compression.ZipArchiveMode]::Create,
        $false
    )
    try {
        $files = Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName
        foreach ($file in $files) {
            $entryName = Get-PortableRelativePath -Root $Root -Path $file.FullName
            $entry = $archive.CreateEntry(
                $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            )
            $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $inputStream = [System.IO.File]::OpenRead($file.FullName)
            $outputStream = $entry.Open()
            try { $inputStream.CopyTo($outputStream) }
            finally { $outputStream.Dispose(); $inputStream.Dispose() }
        }
    }
    finally { $archive.Dispose(); $fileStream.Dispose() }
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$sourceManifest = Get-Content -LiteralPath $SourceManifestPath -Raw | ConvertFrom-Json
$FxcPath = Resolve-FxcPath $FxcPath
New-Item -ItemType Directory -Force -Path $reportsPath | Out-Null
New-Item -ItemType Directory -Force -Path $ReleaseDirectory | Out-Null

Add-Check 'RELEASE_VERSION' ($manifest.releaseVersion -eq '1.0.0') 'Release contract is v1.0.0'
Add-Check 'SOURCE_VERSION' ($manifest.sourceLibraryVersion -eq $sourceManifest.version) 'Release and source-library versions agree'
Add-Check 'MODULE_COUNT' (@($sourceManifest.modules).Count -eq [int]$manifest.expectedModuleCount) 'Source manifest contains eighteen modules'
$symbolCount = @($sourceManifest.modules | ForEach-Object { @($_.publicSymbols) }).Count
Add-Check 'PUBLIC_SYMBOL_COUNT' ($symbolCount -eq [int]$manifest.expectedPublicSymbolCount) 'Source manifest contains seventy-four public symbols'
Add-Check 'FXC_AVAILABLE' ($null -ne $FxcPath) $(if ($FxcPath) { $FxcPath } else { 'fxc.exe was not found' })
Add-Check 'SMOKE_SHADER' (Test-Path -LiteralPath $SmokeShaderPath -PathType Leaf) $SmokeShaderPath

$powerShellPath = Join-Path $PSHOME 'powershell.exe'
foreach ($validator in @($manifest.validators)) {
    $scriptPath = Join-Path $PSScriptRoot ([string]$validator.script)
    $output = @()
    $exitCode = -1
    if (Test-Path -LiteralPath $scriptPath -PathType Leaf) {
        try {
            $output = @(& $powerShellPath -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1 |
                ForEach-Object { $_.ToString() })
            $exitCode = $LASTEXITCODE
        }
        catch {
            $output += $_.Exception.Message
            $exitCode = if ($LASTEXITCODE -is [int]) { $LASTEXITCODE } else { 1 }
        }
    }
    $reportFile = Join-Path $reportsPath ([string]$validator.report)
    $validatorReport = $null
    if (Test-Path -LiteralPath $reportFile -PathType Leaf) {
        try { $validatorReport = Get-Content -LiteralPath $reportFile -Raw | ConvertFrom-Json }
        catch { $validatorReport = $null }
    }
    $markerFound = ($output -join [Environment]::NewLine) -match [Regex]::Escape([string]$validator.marker)
    $reportPassed = $null -ne $validatorReport -and $validatorReport.status -eq 'PASS'
    $passed = $exitCode -eq 0 -and $markerFound -and $reportPassed
    Add-Check ('VALIDATOR_' + ([string]$validator.name -replace '[^A-Za-z0-9]+', '_').ToUpperInvariant()) `
        $passed ([string]$validator.marker)
    $validatorResults.Add([ordered]@{
        name = [string]$validator.name
        script = [string]$validator.script
        report = [string]$validator.report
        status = if ($passed) { 'PASS' } else { 'FAIL' }
        exitCode = $exitCode
        outputTail = @($output | Select-Object -Last 6)
    })
}

$sourceReportPath = Join-Path $reportsPath 'HlslSourceLibraryValidation.json'
$sourceReport = if (Test-Path -LiteralPath $sourceReportPath) {
    Get-Content -LiteralPath $sourceReportPath -Raw | ConvertFrom-Json
} else { $null }
Add-Check 'SOURCE_LIBRARY_CHECK_COUNT' ($null -ne $sourceReport -and
    @($sourceReport.checks).Count -eq [int]$manifest.expectedSourceLibraryCheckCount -and
    @($sourceReport.failures).Count -eq 0) 'Source library completed all 116 structural checks'

$scratchFullPath = [System.IO.Path]::GetFullPath($scratchPath)
$reportsFullPath = [System.IO.Path]::GetFullPath($reportsPath).TrimEnd('\') + '\'
if (-not $scratchFullPath.StartsWith($reportsFullPath, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Scratch path escaped the reports directory.'
}
if (Test-Path -LiteralPath $scratchFullPath) {
    Remove-Item -LiteralPath $scratchFullPath -Recurse -Force
}

$packageRoot = Join-Path $scratchFullPath 'package'
$packageLibrary = Join-Path $packageRoot 'Assets\TA_HLSL\Library'
$migrationRoot = Join-Path $scratchFullPath 'EmptyUnityProject'
$migrationLibrary = Join-Path $migrationRoot 'Assets\TA_HLSL\Library'
$migrationProjectSettings = Join-Path $migrationRoot 'ProjectSettings'
$migrationPackages = Join-Path $migrationRoot 'Packages'
New-Item -ItemType Directory -Force -Path $packageLibrary | Out-Null
New-Item -ItemType Directory -Force -Path $migrationProjectSettings | Out-Null
New-Item -ItemType Directory -Force -Path $migrationPackages | Out-Null

Write-Utf8File -Path (Join-Path $migrationProjectSettings 'ProjectVersion.txt') `
    -Content ("m_EditorVersion: " + [string]$manifest.unityVersion + [Environment]::NewLine)
$packageManifest = [ordered]@{
    dependencies = [ordered]@{
        'com.unity.render-pipelines.universal' = ([string]$manifest.renderPipeline -replace '^.*?([0-9]+\.[0-9]+\.[0-9]+)$', '$1')
    }
}
Write-Utf8File -Path (Join-Path $migrationPackages 'manifest.json') `
    -Content ($packageManifest | ConvertTo-Json -Depth 4)
$initialFiles = @(Get-ChildItem -LiteralPath $migrationRoot -Recurse -File)
Add-Check 'EMPTY_PROJECT_BASELINE' ($initialFiles.Count -eq 2) 'Migration begins from a two-file Unity project skeleton'

$sourceFiles = @(Get-ChildItem -LiteralPath $SourceRoot -Filter '*.hlsl' -File | Sort-Object Name)
foreach ($sourceFile in $sourceFiles) {
    Copy-Item -LiteralPath $sourceFile.FullName -Destination (Join-Path $packageLibrary $sourceFile.Name)
}
Copy-Item -LiteralPath (Join-Path $SourceRoot 'README.md') -Destination (Join-Path $packageRoot 'README.md')
Add-Check 'PACKAGE_SOURCE_COUNT' ($sourceFiles.Count -eq [int]$manifest.expectedHlslFileCount) 'Package stages eighteen modules and one aggregate HLSL header'

$releaseFiles = [System.Collections.Generic.List[object]]::new()
foreach ($file in @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Sort-Object FullName)) {
    $releaseFiles.Add([ordered]@{
        path = Get-PortableRelativePath -Root $packageRoot -Path $file.FullName
        sha256 = Get-Sha256 $file.FullName
        bytes = $file.Length
    })
}
$releaseManifest = [ordered]@{
    releaseVersion = [string]$manifest.releaseVersion
    sourceLibraryVersion = [string]$manifest.sourceLibraryVersion
    unityVersion = [string]$manifest.unityVersion
    renderPipeline = [string]$manifest.renderPipeline
    migrationTarget = [string]$manifest.migrationTarget
    moduleCount = [int]$manifest.expectedModuleCount
    hlslFileCount = [int]$manifest.expectedHlslFileCount
    publicSymbolCount = [int]$manifest.expectedPublicSymbolCount
    aggregate = 'Assets/TA_HLSL/Library/TA_ShaderLibrary.hlsl'
    files = $releaseFiles
}
Write-Utf8File -Path (Join-Path $packageRoot 'release-manifest.json') `
    -Content ($releaseManifest | ConvertTo-Json -Depth 6)

New-DeterministicArchive -Root $packageRoot -OutputPath $archivePath
$archiveHash = Get-Sha256 $archivePath
Write-Utf8File -Path $checksumPath -Content ($archiveHash + '  ' + (Split-Path -Leaf $archivePath) + [Environment]::NewLine)
Add-Check 'ARCHIVE_CREATED' ((Test-Path -LiteralPath $archivePath -PathType Leaf) -and
    (Get-Item -LiteralPath $archivePath).Length -gt 0) $archivePath
Add-Check 'CHECKSUM_CREATED' ((Get-Content -LiteralPath $checksumPath -Raw).Trim().StartsWith($archiveHash)) $checksumPath

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $migrationRoot)
$migrationSmoke = Join-Path $migrationRoot 'Assets\TA_HLSL\HlslReleaseSmoke.hlsl'
Copy-Item -LiteralPath $SmokeShaderPath -Destination $migrationSmoke
$migratedHlsl = @(Get-ChildItem -LiteralPath $migrationLibrary -Filter '*.hlsl' -File | Sort-Object Name)
Add-Check 'MIGRATED_HLSL_FILE_COUNT' ($migratedHlsl.Count -eq [int]$manifest.expectedHlslFileCount) 'The archive migrates eighteen modules and the aggregate header into the empty project'

$extractedManifestPath = Join-Path $migrationRoot 'release-manifest.json'
$extractedManifest = Get-Content -LiteralPath $extractedManifestPath -Raw | ConvertFrom-Json
$hashesMatch = $true
foreach ($fileRecord in @($extractedManifest.files)) {
    $migratedPath = Join-Path $migrationRoot (([string]$fileRecord.path) -replace '/', '\')
    if (-not (Test-Path -LiteralPath $migratedPath -PathType Leaf) -or
        (Get-Sha256 $migratedPath) -ne [string]$fileRecord.sha256) {
        $hashesMatch = $false
    }
}
Add-Check 'MIGRATED_HASHES' $hashesMatch 'Every extracted release file matches its recorded SHA-256'

$includeClosure = $true
$includeCount = 0
foreach ($file in $migratedHlsl) {
    $source = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($match in [Regex]::Matches($source, '(?m)^\s*#include\s+"([^"]+)"')) {
        $includeCount++
        $dependencyPath = Join-Path $file.DirectoryName $match.Groups[1].Value
        if (-not (Test-Path -LiteralPath $dependencyPath -PathType Leaf)) {
            $includeClosure = $false
        }
    }
}
Add-Check 'INCLUDE_CLOSURE' ($includeClosure -and $includeCount -gt 0) 'All quoted includes resolve inside the migrated library'

$archiveEntries = [System.Collections.Generic.List[string]]::new()
$archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    foreach ($entry in $archive.Entries) { $archiveEntries.Add($entry.FullName) }
}
finally { $archive.Dispose() }
$packageIsClean = @($archiveEntries | Where-Object {
    $_ -match '\.meta$|^(Library|Temp|Reports)/|(^|/)\.git/'
}).Count -eq 0
Add-Check 'PACKAGE_CLEAN' $packageIsClean 'Release archive excludes Unity metadata, caches and reports'
Add-Check 'PACKAGE_ENTRY_COUNT' ($archiveEntries.Count -eq [int]$manifest.expectedArchiveEntryCount) 'Archive contains nineteen HLSL files, README and release manifest'

$compileOutputPath = Join-Path $scratchFullPath 'HlslReleaseSmoke.dxbc'
$compilerOutput = @()
$compilerExitCode = -1
if ($FxcPath) {
    try {
        $compilerOutput = @(& $FxcPath /nologo /T ps_5_0 /E PSMain /WX /Ges /I $migrationLibrary `
            /Fo $compileOutputPath $migrationSmoke 2>&1 | ForEach-Object { $_.ToString() })
        $compilerExitCode = $LASTEXITCODE
    }
    catch {
        $compilerOutput += $_.Exception.Message
        $compilerExitCode = if ($LASTEXITCODE -is [int]) { $LASTEXITCODE } else { 1 }
    }
}
$compilerWarnings = @($compilerOutput | Where-Object { $_ -match '(?i)warning\s+[A-Z]*[0-9]+' })
$compilerPassed = $compilerExitCode -eq 0 -and
    (Test-Path -LiteralPath $compileOutputPath -PathType Leaf) -and
    $compilerWarnings.Count -eq 0
Add-Check 'WARNING_FREE_COMPILE' $compilerPassed 'Migrated aggregate compiles as ps_5_0 with /WX and /Ges'

$report = [ordered]@{
    status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
    releaseVersion = [string]$manifest.releaseVersion
    sourceLibraryVersion = [string]$manifest.sourceLibraryVersion
    moduleCount = @($sourceManifest.modules).Count
    hlslFileCount = $migratedHlsl.Count
    publicSymbolCount = $symbolCount
    validatorCount = @($manifest.validators).Count
    passedValidatorCount = @($validatorResults | Where-Object { $_.status -eq 'PASS' }).Count
    sourceLibraryCheckCount = if ($null -ne $sourceReport) { @($sourceReport.checks).Count } else { 0 }
    compiler = [ordered]@{
        tool = if ($FxcPath) { $FxcPath } else { 'UNAVAILABLE' }
        profile = 'ps_5_0'
        entryPoint = 'PSMain'
        warningsAsErrors = $true
        exitCode = $compilerExitCode
        warningCount = $compilerWarnings.Count
        output = $compilerOutput
    }
    migration = [ordered]@{
        projectSkeletonFileCount = $initialFiles.Count
        target = [string]$manifest.migrationTarget
        migratedModuleCount = @($sourceManifest.modules).Count
        migratedHlslFileCount = $migratedHlsl.Count
        resolvedIncludeCount = $includeCount
        hashesMatch = $hashesMatch
    }
    release = [ordered]@{
        archive = Get-PortableRelativePath -Root $repositoryPath -Path $archivePath
        sha256File = Get-PortableRelativePath -Root $repositoryPath -Path $checksumPath
        sha256 = $archiveHash
        bytes = (Get-Item -LiteralPath $archivePath).Length
        entryCount = $archiveEntries.Count
    }
    editorShaderValidation = 'BLOCKED_LICENSE'
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    validators = $validatorResults
    checks = $checks
    failures = $failures
    limitations = @($manifest.limitations)
}
$report | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Remove-Item -LiteralPath $scratchFullPath -Recurse -Force

if ($failures.Count -gt 0) {
    throw ('HLSL special acceptance failed: ' + ($failures -join ', '))
}

Write-Output 'UNITY_HLSL_SPECIAL_ACCEPTANCE: PASS'
Write-Output "Archive: $archivePath"
Write-Output "SHA256: $archiveHash"
Write-Output "Report: $ReportPath"
