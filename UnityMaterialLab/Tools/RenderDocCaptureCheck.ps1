param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\RenderDocCaptureManifest.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\Reports\RenderDocCaptureReadiness.json'),
    [string]$RenderDocPath = ''
)

$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$reportsPath = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $reportsPath | Out-Null

$candidates = @()
if ($RenderDocPath) { $candidates += $RenderDocPath }
$candidates += @(
    (Get-Command renderdoccmd -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    (Get-Command qrenderdoc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    'C:\Program Files\RenderDoc\renderdoccmd.exe',
    'C:\Program Files\RenderDoc\qrenderdoc.exe',
    'C:\Program Files (x86)\RenderDoc\renderdoccmd.exe',
    'C:\Program Files (x86)\RenderDoc\qrenderdoc.exe'
)
$renderDocExecutable = @($candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1)[0]
$unityPath = 'F:\unity\2022.3.62f3c1\Editor\Unity.exe'
$unityAvailable = Test-Path -LiteralPath $unityPath -PathType Leaf
$captureDirectory = Join-Path $projectPath 'Reports\RenderDoc'
New-Item -ItemType Directory -Force -Path $captureDirectory | Out-Null
$capturePath = Join-Path $captureDirectory 'MaterialLab_Frame_0001.rdc'
$status = if ($renderDocExecutable -and $unityAvailable) { 'READY_TO_CAPTURE' } else { 'BLOCKED_TOOLING' }
$report = [ordered]@{
    status = $status
    preparationStatus = $manifest.status
    captureStatus = if ($renderDocExecutable) { 'RENDERDOC_FOUND' } else { 'RENDERDOC_NOT_INSTALLED' }
    unityStatus = if ($unityAvailable) { 'UNITY_EDITOR_FOUND' } else { 'UNITY_EDITOR_NOT_FOUND' }
    renderDocExecutable = $renderDocExecutable
    unityExecutable = $unityPath
    manifest = (Resolve-Path $ManifestPath).Path
    expectedCapture = $capturePath
    markerCount = @($manifest.markers).Count
    bookmarks = $manifest.bookmarks
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
}
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
if ($status -eq 'READY_TO_CAPTURE') {
    Write-Output 'RENDERDOC_CAPTURE_READINESS: READY_TO_CAPTURE'
} else {
    Write-Output 'RENDERDOC_CAPTURE_READINESS: BLOCKED_TOOLING'
}
Write-Output "Report: $OutputPath"
