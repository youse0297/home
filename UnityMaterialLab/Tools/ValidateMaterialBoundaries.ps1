param(
    [string]$UnityPath = 'F:\unity\2022.3.62f3c1\Editor\Unity.exe'
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logsPath = Join-Path $projectPath 'Logs'
$logPath = Join-Path $logsPath 'material-boundary-validation.log'
New-Item -ItemType Directory -Force -Path $logsPath | Out-Null

if (-not (Test-Path -LiteralPath $UnityPath -PathType Leaf)) {
    throw "Unity Editor not found: $UnityPath"
}

& $UnityPath -batchmode -quit -projectPath $projectPath `
    -executeMethod 'TA.MaterialLab.Editor.MaterialBoundaryValidator.Build' `
    -logFile $logPath

if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $logPath -Tail 120
    throw "Unity material boundary validation failed with exit code ${LASTEXITCODE}."
}
if (-not (Select-String -LiteralPath $logPath `
        -Pattern 'UNITY_MATERIAL_BOUNDARY_ACCEPTANCE: PASS' -Quiet)) {
    Get-Content -LiteralPath $logPath -Tail 120
    throw 'Unity material boundary validation did not emit the PASS marker.'
}

Write-Output 'UNITY_MATERIAL_BOUNDARY_ACCEPTANCE: PASS'
Write-Output "Log: $logPath"
