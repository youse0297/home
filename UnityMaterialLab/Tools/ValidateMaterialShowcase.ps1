param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Documentation\MaterialShowcase.json'),
    [string]$BootstrapPath = (Join-Path $PSScriptRoot '..\Assets\_TA\Editor\MaterialShowcaseBootstrap.cs'),
    [string]$LibraryReadmePath = (Join-Path $PSScriptRoot '..\Assets\_TA\Shaders\Library\README.md'),
    [string]$DocumentationPath = (Join-Path $PSScriptRoot '..\..\docs\UNITY_MATERIAL_SHOWCASE.md'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\Reports\MaterialShowcaseReference.png'),
    [string]$ReportPath = (Join-Path $PSScriptRoot '..\Reports\MaterialShowcaseValidation.json')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$checks = [System.Collections.Generic.List[string]]::new()
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Check {
    param([string]$Id, [bool]$Condition, [string]$Detail)
    $entry = $Id + ': ' + $Detail
    if ($Condition) { $checks.Add($entry) } else { $failures.Add($entry) }
}

foreach ($path in @($ManifestPath, $BootstrapPath, $LibraryReadmePath, $DocumentationPath)) {
    Add-Check 'REQUIRED_FILE' (Test-Path -LiteralPath $path -PathType Leaf) $path
}
if ($failures.Count -gt 0) {
    throw ('Material showcase inputs are incomplete: ' + ($failures -join '; '))
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$bootstrap = Get-Content -LiteralPath $BootstrapPath -Raw
$libraryReadme = Get-Content -LiteralPath $LibraryReadmePath -Raw
$documentation = Get-Content -LiteralPath $DocumentationPath -Raw
$showcases = @($manifest.showcases)
$ids = @($showcases | ForEach-Object { $_.id })
$materials = @($showcases | ForEach-Object { $_.material })
$expectedIds = @(
    'BASE_PBR',
    'LAYERED_NORMAL',
    'EDGE_WEAR',
    'SNOW_COVER',
    'ANISOTROPIC_METAL',
    'TRANSPARENT_REFRACTION'
)

Add-Check 'CONTRACT_STATUS' ($manifest.status -in @('STATIC_SCENE_SPEC_VALIDATED', 'EDITOR_SCENE_GENERATED')) 'Scene contract has an accepted status'
Add-Check 'CONTRACT_VERSION' ($manifest.version -eq '1.0.0') 'Scene contract version is 1.0.0'
Add-Check 'SHOWCASE_COUNT' ($showcases.Count -eq 6) 'Exactly six material stands are specified'
Add-Check 'UNIQUE_IDS' (@($ids | Select-Object -Unique).Count -eq 6) 'Showcase IDs are unique'
Add-Check 'EXPECTED_IDS' (@($expectedIds | Where-Object { $ids -notcontains $_ }).Count -eq 0) 'All planned module stands are present'
Add-Check 'UNIQUE_MATERIALS' (@($materials | Select-Object -Unique).Count -eq 6) 'Each stand owns a distinct generated material path'
Add-Check 'INPUTS_OUTPUTS' (@($showcases | Where-Object { @($_.inputs).Count -eq 0 -or [string]::IsNullOrWhiteSpace($_.output) }).Count -eq 0) 'Every stand declares inputs and an observable output'
Add-Check 'CHECKLIST' (@($manifest.validationChecklist).Count -eq 6) 'Six runtime and offline checks are recorded'
Add-Check 'LIMITATIONS' (@($manifest.limitations).Count -eq 3) 'Three explicit limitations prevent overclaiming'
Add-Check 'REFERENCE_DISTINCTION' ($manifest.referenceBoard -match 'MaterialShowcaseReference\.png' -and $manifest.runtimeScreenshot -match 'MaterialShowcaseRuntime\.png') 'Offline reference and runtime screenshot use distinct paths'

Add-Check 'MENU_ENTRY' ($bootstrap -match '\[MenuItem\("TA/Material Lab/Build Material Showcase"\)\]') 'Editor menu builds the showcase'
Add-Check 'SCENE_PATH' ($bootstrap -match 'SCN_MaterialShowcase\.unity') 'Bootstrap writes the fixed scene path'
Add-Check 'SIX_DEFINITIONS' (([Regex]::Matches($bootstrap, 'new ShowcaseDefinition')).Count -eq 6) 'Bootstrap defines six stands'
Add-Check 'UNIQUE_MATERIAL_CREATION' ($bootstrap -match 'MaterialPath\(definition\.Id\)' -and $bootstrap -match 'AssetDatabase\.CreateAsset\(material, materialPath\)') 'Bootstrap creates one material asset per definition'
Add-Check 'FIXED_CAMERA' ($bootstrap -match 'CAM_MaterialShowcase' -and $bootstrap -match 'fieldOfView = 43\.0f') 'Camera name and field of view are fixed'
Add-Check 'FIXED_LIGHTING' ($bootstrap -match 'LGT_Showcase_Key' -and $bootstrap -match 'LGT_Showcase_Rim' -and $bootstrap -match 'AmbientMode\.Flat') 'Ambient, key and rim lighting are fixed'
Add-Check 'BUILD_SETTINGS' ($bootstrap -match 'EditorBuildSettingsScene' -and $bootstrap -match 'EditorBuildSettings\.scenes') 'Generated scene is added to Build Settings'
Add-Check 'SAFE_DEFORMATION_DEFAULTS' ($bootstrap -match '"_DisplacementAmplitude", 0\.0f' -and $bootstrap -match '"_WaveAmplitude", 0\.0f' -and $bootstrap -match '"_WindAmplitude", 0\.0f') 'Unsupported deformation visuals remain disabled'

foreach ($module in @('TA_MaterialInterface', 'TA_NormalBlend', 'TA_EdgeWear', 'TA_SnowCover', 'TA_Anisotropy', 'TA_TransparencyRefraction')) {
    Add-Check ('README_' + $module.ToUpperInvariant()) ($libraryReadme -match [Regex]::Escape($module)) ('Source library README documents ' + $module)
}
Add-Check 'README_IO_TABLE' ($libraryReadme -match 'TA_VertexDeformation' -and $libraryReadme -match 'TA_DebugViews') 'Source library README contains the module input/output table'
Add-Check 'FAILURE_NOTES' ($libraryReadme -match 'Opaque Texture' -and $documentation -match 'MaterialShowcaseRuntime\.png') 'Common failures and runtime boundaries are documented'
Add-Check 'ANALYSIS_NOTES' ($documentation -match 'MaterialShowcaseReference\.png' -and $documentation -match 'Clear Coat') 'Documentation records the planned analysis notes and boundaries'

$width = 1600
$height = 900
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$background = [System.Drawing.Color]::FromArgb(11, 18, 31)
$panel = [System.Drawing.Color]::FromArgb(23, 34, 54)
$border = [System.Drawing.Color]::FromArgb(60, 80, 110)
$textColor = [System.Drawing.Color]::FromArgb(237, 242, 250)
$mutedColor = [System.Drawing.Color]::FromArgb(167, 184, 207)
$accent = [System.Drawing.Color]::FromArgb(82, 207, 170)
$titleFont = New-Object System.Drawing.Font('Segoe UI', 28, [System.Drawing.FontStyle]::Bold)
$subtitleFont = New-Object System.Drawing.Font('Segoe UI', 11)
$headingFont = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$moduleFont = New-Object System.Drawing.Font('Consolas', 10)
$bodyFont = New-Object System.Drawing.Font('Segoe UI', 9)
$badgeFont = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$textBrush = New-Object System.Drawing.SolidBrush($textColor)
$mutedBrush = New-Object System.Drawing.SolidBrush($mutedColor)
$accentBrush = New-Object System.Drawing.SolidBrush($accent)
$panelBrush = New-Object System.Drawing.SolidBrush($panel)
$borderPen = New-Object System.Drawing.Pen($border, 1)
$swatches = @(
    [System.Drawing.Color]::FromArgb(202, 100, 42),
    [System.Drawing.Color]::FromArgb(77, 133, 183),
    [System.Drawing.Color]::FromArgb(52, 92, 164),
    [System.Drawing.Color]::FromArgb(221, 235, 242),
    [System.Drawing.Color]::FromArgb(205, 126, 39),
    [System.Drawing.Color]::FromArgb(70, 171, 201)
)

try {
    $graphics.Clear($background)
    $graphics.DrawString('Material Module Showcase', $titleFont, $textBrush, 54, 28)
    $graphics.DrawString('OFFLINE REFERENCE  |  fixed layout and I/O contract  |  not a Unity runtime capture', $subtitleFont, $mutedBrush, 57, 76)
    $graphics.DrawLine($borderPen, 54, 112, 1546, 112)

    for ($index = 0; $index -lt $showcases.Count; $index++) {
        $showcase = $showcases[$index]
        $column = $index % 3
        $row = [Math]::Floor($index / 3)
        $x = 54 + $column * 505
        $y = 138 + $row * 336
        $graphics.FillRectangle($panelBrush, $x, $y, 474, 302)
        $graphics.DrawRectangle($borderPen, $x, $y, 474, 302)
        $graphics.DrawString(('{0:00}' -f ($index + 1)), $badgeFont, $accentBrush, $x + 20, $y + 18)
        $graphics.DrawString([string]$showcase.label, $headingFont, $textBrush, $x + 60, $y + 14)
        $graphics.DrawString([string]$showcase.module, $moduleFont, $accentBrush, $x + 60, $y + 46)

        $swatchBrush = New-Object System.Drawing.SolidBrush($swatches[$index])
        try {
            $graphics.FillEllipse($swatchBrush, $x + 20, $y + 83, 126, 126)
        }
        finally { $swatchBrush.Dispose() }
        $graphics.DrawEllipse($borderPen, $x + 20, $y + 83, 126, 126)
        $graphics.DrawString(('Mesh: ' + $showcase.primitive), $bodyFont, $mutedBrush, $x + 21, $y + 221)

        $inputText = 'IN  ' + ((@($showcase.inputs) | Select-Object -First 3) -join '; ')
        $outputText = 'OUT ' + [string]$showcase.output
        $inputRectangle = [System.Drawing.RectangleF]::new(($x + 170), ($y + 88), 280, 90)
        $outputRectangle = [System.Drawing.RectangleF]::new(($x + 170), ($y + 190), 280, 70)
        $graphics.DrawString($inputText, $bodyFont, $mutedBrush, $inputRectangle)
        $graphics.DrawString($outputText, $bodyFont, $textBrush, $outputRectangle)
    }

    $graphics.DrawLine($borderPen, 54, 822, 1546, 822)
    $graphics.DrawString('Generate in Unity: TA / Material Lab / Build Material Showcase', $moduleFont, $accentBrush, 54, 840)
    $graphics.DrawString('Runtime proof: Assets/_TA/Documentation/MaterialShowcaseRuntime.png', $moduleFont, $mutedBrush, 825, 840)
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $borderPen.Dispose()
    $textBrush.Dispose(); $mutedBrush.Dispose(); $accentBrush.Dispose(); $panelBrush.Dispose()
    $titleFont.Dispose(); $subtitleFont.Dispose(); $headingFont.Dispose(); $moduleFont.Dispose(); $bodyFont.Dispose(); $badgeFont.Dispose()
    $graphics.Dispose(); $bitmap.Dispose()
}

$image = [System.Drawing.Image]::FromFile($OutputPath)
try {
    Add-Check 'REFERENCE_DIMENSIONS' ($image.Width -eq 1600 -and $image.Height -eq 900) 'Offline reference board is 1600x900'
}
finally { $image.Dispose() }

$status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$report = [ordered]@{
    status = $status
    contractStatus = $manifest.status
    showcaseCount = $showcases.Count
    uniqueMaterialCount = @($materials | Select-Object -Unique).Count
    checklistCount = @($manifest.validationChecklist).Count
    limitationCount = @($manifest.limitations).Count
    referenceBoard = $OutputPath
    runtimeScreenshot = $manifest.runtimeScreenshot
    generatedAtUtc = [DateTime]::UtcNow.ToString('O')
    checks = $checks
    failures = $failures
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

if ($failures.Count -gt 0) {
    throw ('Material showcase validation failed: ' + ($failures -join '; '))
}

Write-Output 'UNITY_MATERIAL_SHOWCASE: PASS'
Write-Output "Board: $OutputPath"
Write-Output "Report: $ReportPath"
