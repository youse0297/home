param(
    [string]$UnityPath = 'F:\unity\2022.3.62f3c1\Editor\Unity.exe'
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logsPath = Join-Path $projectPath 'Logs'
New-Item -ItemType Directory -Force -Path $logsPath | Out-Null

if (-not (Test-Path -LiteralPath $UnityPath -PathType Leaf)) {
    throw "Unity Editor not found: $UnityPath"
}

function Invoke-UnityMethod {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$LogName,
        [Parameter(Mandatory = $true)][string]$ExpectedMarker
    )

    $logPath = Join-Path $logsPath $LogName
    & $UnityPath -batchmode -quit -projectPath $projectPath `
        -executeMethod $Method -logFile $logPath
    if ($LASTEXITCODE -ne 0) {
        Get-Content -LiteralPath $logPath -Tail 120
        throw "Unity method failed with exit code ${LASTEXITCODE}: $Method"
    }
    if (-not (Select-String -LiteralPath $logPath -Pattern $ExpectedMarker -Quiet)) {
        Get-Content -LiteralPath $logPath -Tail 120
        throw "Unity method did not emit the expected PASS marker: $ExpectedMarker"
    }
    return $logPath
}

$buildLog = Invoke-UnityMethod `
    -Method 'TA.MaterialLab.Editor.ProjectBootstrap.Build' `
    -LogName 'material-lab-build.log' `
    -ExpectedMarker 'UNITY_PROJECT_BOOTSTRAP: PASS'
$validationLog = Invoke-UnityMethod `
    -Method 'TA.MaterialLab.Editor.ProjectBootstrap.Validate' `
    -LogName 'material-lab-validation.log' `
    -ExpectedMarker 'UNITY_ASSET_IMPORT_ACCEPTANCE: PASS'

Write-Output 'Unity project and asset import acceptance: PASS'
Write-Output "Build log: $buildLog"
Write-Output "Validation log: $validationLog"
