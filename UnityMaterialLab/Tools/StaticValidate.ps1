param(
    [string]$UnityRoot = 'F:\unity\2022.3.62f3c1\Editor'
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$reportsPath = Join-Path $projectPath 'Reports'
$compileOutput = Join-Path $reportsPath 'ProjectBootstrap.Static.dll'
$reportPath = Join-Path $reportsPath 'StaticValidation.json'
New-Item -ItemType Directory -Force -Path $reportsPath | Out-Null

$checks = [System.Collections.Generic.List[string]]::new()
$errors = [System.Collections.Generic.List[string]]::new()

function Add-Check {
    param(
        [bool]$Condition,
        [string]$Description
    )
    if ($Condition) {
        $checks.Add($Description)
    } else {
        $errors.Add($Description)
    }
}

$projectVersionPath = Join-Path $projectPath 'ProjectSettings\ProjectVersion.txt'
$manifestPath = Join-Path $projectPath 'Packages\manifest.json'
$modelPath = Join-Path $projectPath 'Assets\_TA\Art\Models\SM_CC0_DisplayCrate.obj'
$texturePath = Join-Path $projectPath 'Assets\_TA\Art\Textures\T_CC0_Crate_BaseColor.png'
$sourcesPath = Join-Path $projectPath 'Assets\_TA\Documentation\ASSET_SOURCES.md'
$bootstrapPath = Join-Path $projectPath 'Assets\_TA\Editor\ProjectBootstrap.cs'

Add-Check (Test-Path -LiteralPath $projectVersionPath -PathType Leaf) `
    'ProjectVersion.txt exists'
Add-Check (Test-Path -LiteralPath $manifestPath -PathType Leaf) `
    'Packages/manifest.json exists'
Add-Check (Test-Path -LiteralPath $modelPath -PathType Leaf) `
    'CC0 model source exists'
Add-Check (Test-Path -LiteralPath $texturePath -PathType Leaf) `
    'CC0 texture source exists'
Add-Check (Test-Path -LiteralPath $sourcesPath -PathType Leaf) `
    'Asset source ledger exists'
Add-Check (Test-Path -LiteralPath $bootstrapPath -PathType Leaf) `
    'Project bootstrap source exists'

if (Test-Path -LiteralPath $projectVersionPath) {
    $projectVersion = Get-Content -LiteralPath $projectVersionPath -Raw
    Add-Check ($projectVersion -match '2022\.3\.62f3c1') `
        'Project pins Editor 2022.3.62f3c1'
}

if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $urpVersion = $manifest.dependencies.'com.unity.render-pipelines.universal'
    Add-Check ($urpVersion -eq '14.0.12') 'Project pins URP 14.0.12'
}

if (Test-Path -LiteralPath $modelPath) {
    $modelLines = Get-Content -LiteralPath $modelPath
    $positionCount = @($modelLines | Where-Object { $_ -match '^v\s' }).Count
    $uvCount = @($modelLines | Where-Object { $_ -match '^vt\s' }).Count
    $normalCount = @($modelLines | Where-Object { $_ -match '^vn\s' }).Count
    $faceCount = @($modelLines | Where-Object { $_ -match '^f\s' }).Count
    Add-Check ($positionCount -eq 8) 'OBJ contains 8 positions'
    Add-Check ($uvCount -eq 4) 'OBJ contains 4 UV coordinates'
    Add-Check ($normalCount -eq 6) 'OBJ contains 6 face normals'
    Add-Check ($faceCount -eq 12) 'OBJ contains 12 triangles'
}

if (Test-Path -LiteralPath $texturePath) {
    Add-Type -AssemblyName System.Drawing
    $image = [System.Drawing.Image]::FromFile($texturePath)
    try {
        Add-Check ($image.Width -eq 64 -and $image.Height -eq 64) `
            'Base color texture is 64x64'
    } finally {
        $image.Dispose()
    }
}

if (Test-Path -LiteralPath $sourcesPath) {
    $sources = Get-Content -LiteralPath $sourcesPath -Raw
    Add-Check ($sources -match 'CC0 1\.0') 'Asset ledger records CC0 license'
    Add-Check ($sources -match 'no third-party') `
        'Asset ledger excludes untracked third-party content'
}

$dataPath = Join-Path $UnityRoot 'Data'
$dotnetPath = Join-Path $dataPath 'NetCoreRuntime\dotnet.exe'
$compilerPath = Join-Path $dataPath 'DotNetSdkRoslyn\csc.dll'
$netStandardPath = Join-Path $dataPath 'NetStandard\ref\2.1.0\netstandard.dll'
$unityEnginePath = Join-Path $dataPath 'Managed\UnityEngine.dll'
$unityEditorPath = Join-Path $dataPath 'Managed\UnityEditor.dll'
$compilerInputs = @(
    $dotnetPath,
    $compilerPath,
    $netStandardPath,
    $unityEnginePath,
    $unityEditorPath
)
$compilerAvailable = ($compilerInputs | Where-Object {
    -not (Test-Path -LiteralPath $_ -PathType Leaf)
}).Count -eq 0
Add-Check $compilerAvailable 'Installed Unity C# compiler inputs are available'

if ($compilerAvailable -and (Test-Path -LiteralPath $bootstrapPath)) {
    & $dotnetPath $compilerPath /nologo /target:library /langversion:latest `
        /define:UNITY_EDITOR /out:$compileOutput `
        /reference:$netStandardPath `
        /reference:$unityEnginePath `
        /reference:$unityEditorPath `
        $bootstrapPath
    Add-Check ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $compileOutput)) `
        'ProjectBootstrap compiles against installed Unity assemblies'
}

$assetFiles = Get-ChildItem -LiteralPath (Join-Path $projectPath 'Assets\_TA') `
    -Recurse -File | Where-Object { $_.Extension -in '.obj', '.png' }
foreach ($assetFile in $assetFiles) {
    $validName = $assetFile.Name -match '^(SM_|T_)'
    Add-Check $validName ("Imported source uses naming prefix: " + $assetFile.Name)
}

$status = if ($errors.Count -eq 0) { 'PASS' } else { 'FAIL' }
$report = [ordered]@{
    status = $status
    projectPath = $projectPath
    unityRoot = $UnityRoot
    editorRuntimeValidation = 'BLOCKED_LICENSE'
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    errors = $errors
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8

if ($errors.Count -gt 0) {
    throw ('Unity static validation failed: ' + ($errors -join '; '))
}

Write-Output 'UNITY_PROJECT_STATIC_ACCEPTANCE: PASS'
Write-Output "Report: $reportPath"
