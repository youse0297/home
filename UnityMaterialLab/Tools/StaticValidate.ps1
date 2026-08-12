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
$normalPath = Join-Path $projectPath 'Assets\_TA\Art\Textures\T_PBR_Normal.png'
$ormPath = Join-Path $projectPath 'Assets\_TA\Art\Textures\T_PBR_ORM.png'
$sourcesPath = Join-Path $projectPath 'Assets\_TA\Documentation\ASSET_SOURCES.md'
$inputsDocPath = Join-Path $projectPath 'Assets\_TA\Documentation\MATERIAL_INPUTS.md'
$bootstrapPath = Join-Path $projectPath 'Assets\_TA\Editor\ProjectBootstrap.cs'
$profilePath = Join-Path $projectPath 'Assets\_TA\Runtime\MaterialInputProfile.cs'
$profileMetaPath = Join-Path $projectPath 'Assets\_TA\Runtime\MaterialInputProfile.cs.meta'
$boundarySourcePath = Join-Path $projectPath 'Assets\_TA\Runtime\MaterialBoundaryMatrix.cs'
$boundaryEditorPath = Join-Path $projectPath 'Assets\_TA\Editor\MaterialBoundaryValidator.cs'
$boundaryMatrixPath = Join-Path $projectPath 'Assets\_TA\Documentation\MaterialBoundaryMatrix.json'
$boundaryBoardPath = Join-Path $projectPath 'Reports\MaterialBoundaryBoard.svg'
$boundaryBoardPngPath = Join-Path $projectPath 'Reports\MaterialBoundaryBoard.png'
$boundaryBoardScriptPath = Join-Path $projectPath 'Tools\GenerateBoundaryBoard.ps1'
$shaderGraphHlslPath = Join-Path $projectPath 'Assets\_TA\ShaderGraph\TA_CustomFunctions.hlsl'
$shaderGraphHlslMetaPath = Join-Path $projectPath 'Assets\_TA\ShaderGraph\TA_CustomFunctions.hlsl.meta'
$shaderGraphBootstrapPath = Join-Path $projectPath 'Assets\_TA\Editor\ShaderGraphCustomFunctionBootstrap.cs'
$shaderGraphContractPath = Join-Path $projectPath 'Assets\_TA\Documentation\ShaderGraphCustomFunctionContract.json'

Add-Check (Test-Path -LiteralPath $projectVersionPath -PathType Leaf) `
    'ProjectVersion.txt exists'
Add-Check (Test-Path -LiteralPath $manifestPath -PathType Leaf) `
    'Packages/manifest.json exists'
Add-Check (Test-Path -LiteralPath $modelPath -PathType Leaf) `
    'CC0 model source exists'
Add-Check (Test-Path -LiteralPath $texturePath -PathType Leaf) `
    'CC0 texture source exists'
Add-Check (Test-Path -LiteralPath $normalPath -PathType Leaf) `
    'PBR normal input exists'
Add-Check (Test-Path -LiteralPath $ormPath -PathType Leaf) `
    'PBR ORM input exists'
Add-Check (Test-Path -LiteralPath $sourcesPath -PathType Leaf) `
    'Asset source ledger exists'
Add-Check (Test-Path -LiteralPath $inputsDocPath -PathType Leaf) `
    'Material input contract exists'
Add-Check (Test-Path -LiteralPath $bootstrapPath -PathType Leaf) `
    'Project bootstrap source exists'
Add-Check (Test-Path -LiteralPath $profilePath -PathType Leaf) `
    'Material input profile source exists'
Add-Check (Test-Path -LiteralPath $profileMetaPath -PathType Leaf) `
    'Material input profile meta exists'
Add-Check (Test-Path -LiteralPath $boundarySourcePath -PathType Leaf) `
    'Material boundary matrix source exists'
Add-Check (Test-Path -LiteralPath $boundaryEditorPath -PathType Leaf) `
    'Material boundary Editor validator exists'
Add-Check (Test-Path -LiteralPath $boundaryMatrixPath -PathType Leaf) `
    'Material boundary JSON baseline exists'
Add-Check (Test-Path -LiteralPath $boundaryBoardPath -PathType Leaf) `
    'Material boundary comparison board exists'
Add-Check (Test-Path -LiteralPath $boundaryBoardPngPath -PathType Leaf) `
    'Material boundary PNG comparison board exists'
Add-Check (Test-Path -LiteralPath $boundaryBoardScriptPath -PathType Leaf) `
    'Material boundary board generator exists'
Add-Check (Test-Path -LiteralPath $shaderGraphHlslPath -PathType Leaf) `
    'Shader Graph Custom Function HLSL source exists'
Add-Check (Test-Path -LiteralPath $shaderGraphHlslMetaPath -PathType Leaf) `
    'Shader Graph Custom Function HLSL meta exists'
Add-Check (Test-Path -LiteralPath $shaderGraphBootstrapPath -PathType Leaf) `
    'Shader Graph Custom Function example generator exists'
Add-Check (Test-Path -LiteralPath $shaderGraphContractPath -PathType Leaf) `
    'Shader Graph Custom Function contract exists'

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

foreach ($dataTexturePath in @($normalPath, $ormPath)) {
    if (Test-Path -LiteralPath $dataTexturePath) {
        $image = [System.Drawing.Image]::FromFile($dataTexturePath)
        try {
            Add-Check ($image.Width -eq 64 -and $image.Height -eq 64) `
                ((Split-Path $dataTexturePath -Leaf) + ' is 64x64')
        } finally {
            $image.Dispose()
        }
    }
}

if (Test-Path -LiteralPath $sourcesPath) {
    $sources = Get-Content -LiteralPath $sourcesPath -Raw
    Add-Check ($sources -match 'CC0 1\.0') 'Asset ledger records CC0 license'
    Add-Check ($sources -match 'no third-party') `
        'Asset ledger excludes untracked third-party content'
}

if (Test-Path -LiteralPath $inputsDocPath) {
    $inputsDoc = Get-Content -LiteralPath $inputsDocPath -Raw
    Add-Check ($inputsDoc -match 'BaseColor' -and $inputsDoc -match 'Normal' -and $inputsDoc -match 'ORM') `
        'Material input contract names BaseColor, Normal and ORM'
    Add-Check ($inputsDoc -match 'R = AO' -and $inputsDoc -match 'G = roughness' -and $inputsDoc -match 'B = metallic') `
        'Material input contract records ORM channel mapping'
}

if (Test-Path -LiteralPath $bootstrapPath) {
    $bootstrap = Get-Content -LiteralPath $bootstrapPath -Raw
    Add-Check ($bootstrap -match 'PbrMasterMaterialPath' -and
        $bootstrap -match 'PbrDielectricMaterialPath' -and
        $bootstrap -match 'PbrRoughMetalMaterialPath' -and
        $bootstrap -match 'PbrSmoothMetalMaterialPath') `
        'Bootstrap declares one PBR master and three instance materials'
    Add-Check ($bootstrap -match 'NormalTexturePath' -and $bootstrap -match 'OrmTexturePath') `
        'Bootstrap declares Normal and ORM input paths'
}

if (Test-Path -LiteralPath $profilePath) {
    $profileSource = Get-Content -LiteralPath $profilePath -Raw
    Add-Check ($profileSource -match 'OrmChannelContract' -and $profileSource -match 'ApplyTo') `
        'Material input profile exposes ORM contract and material application'
    Add-Check ($profileSource -match 'ClampToValidRanges' -and
        $profileSource -match 'HasValidParameters' -and
        $profileSource -match 'MaximumNormalScale = 2\.0f') `
        'Material input profile sanitizes script-written boundary violations'
}

if (Test-Path -LiteralPath $boundaryMatrixPath) {
    $boundary = Get-Content -LiteralPath $boundaryMatrixPath -Raw | ConvertFrom-Json
    Add-Check ($boundary.caseCount -eq 11 -and @($boundary.cases).Count -eq 11) `
        'Material boundary matrix contains 11 fixed cases'
    Add-Check (@($boundary.cases | Where-Object { $_.parameter -eq 'Metallic' }).Count -eq 3) `
        'Material boundary matrix contains 3 metallic cases'
    Add-Check (@($boundary.cases | Where-Object { $_.parameter -eq 'Roughness' }).Count -eq 5) `
        'Material boundary matrix contains 5 roughness cases'
    Add-Check (@($boundary.cases | Where-Object { $_.parameter -eq 'NormalScale' }).Count -eq 3) `
        'Material boundary matrix contains 3 normal-scale cases'
    Add-Check ($boundary.ranges.metallic[0] -eq 0 -and $boundary.ranges.metallic[1] -eq 1 -and
        $boundary.ranges.roughness[0] -eq 0 -and $boundary.ranges.roughness[1] -eq 1 -and
        $boundary.ranges.normalScale[0] -eq 0 -and $boundary.ranges.normalScale[1] -eq 2) `
        'Material boundary ranges match the public profile contract'
    Add-Check ($boundary.baselines.dielectricF0 -eq 0.04 -and
        $boundary.baselines.minimumGgxAlpha -eq 0.0001) `
        'Material boundary numeric baselines match PBR conventions'
    $boundaryErrors = @()
    foreach ($item in $boundary.cases) {
        $expectedSmoothness = 1.0 - [double]$item.roughness
        $expectedAlpha = [Math]::Max(
            [double]$item.roughness * [double]$item.roughness,
            0.0001
        )
        $expectedWeight = 1.0 - [double]$item.metallic
        $valid = [double]$item.metallic -ge 0 -and [double]$item.metallic -le 1 -and
            [double]$item.roughness -ge 0 -and [double]$item.roughness -le 1 -and
            [double]$item.normalScale -ge 0 -and [double]$item.normalScale -le 2 -and
            [Math]::Abs([double]$item.smoothness - $expectedSmoothness) -lt 0.000001 -and
            [Math]::Abs([double]$item.ggxAlpha - $expectedAlpha) -lt 0.000001 -and
            [Math]::Abs([double]$item.dielectricWeight - $expectedWeight) -lt 0.000001
        if (-not $valid) {
            $boundaryErrors += $item.id
        }
    }
    Add-Check ($boundaryErrors.Count -eq 0) `
        'All material boundary cases are finite and physically valid'
}

if (Test-Path -LiteralPath $boundaryBoardPath) {
    $boundaryBoard = Get-Content -LiteralPath $boundaryBoardPath -Raw
    Add-Check ($boundaryBoard -match 'width="1200"' -and $boundaryBoard -match 'height="720"') `
        'Material boundary comparison board is 1200x720'
    foreach ($caseId in 'M00','M05','M10','R00','R025','R05','R075','R10','N00','N10','N20') {
        Add-Check ($boundaryBoard -match $caseId) `
            ("Material boundary board includes case: " + $caseId)
    }
}

if (Test-Path -LiteralPath $boundaryBoardPngPath) {
    $boundaryImage = [System.Drawing.Image]::FromFile($boundaryBoardPngPath)
    try {
        Add-Check ($boundaryImage.Width -eq 1200 -and $boundaryImage.Height -eq 720) `
            'Material boundary PNG comparison board is 1200x720'
    } finally {
        $boundaryImage.Dispose()
    }
}

if (Test-Path -LiteralPath $shaderGraphHlslPath) {
    $shaderGraphHlsl = Get-Content -LiteralPath $shaderGraphHlslPath -Raw
    Add-Check ($shaderGraphHlsl -match '#ifndef TA_SHADER_GRAPH_CUSTOM_FUNCTIONS_INCLUDED' -and
        $shaderGraphHlsl -match '#define TA_SHADER_GRAPH_CUSTOM_FUNCTIONS_INCLUDED' -and
        $shaderGraphHlsl -match '//UNITY_SHADER_NO_UPGRADE') `
        'Shader Graph HLSL uses a guarded file-mode include'
    Add-Check ($shaderGraphHlsl -match 'void TA_SanitizeMaterial_float' -and
        $shaderGraphHlsl -match 'void TA_SanitizeMaterial_half' -and
        $shaderGraphHlsl -match 'void TA_SampleMaterialInputs_float' -and
        $shaderGraphHlsl -match 'void TA_SampleMaterialInputs_half') `
        'Shader Graph HLSL provides float and half precision variants'
    Add-Check ($shaderGraphHlsl -match 'UnityTexture2D BaseColorTex' -and
        $shaderGraphHlsl -match 'UnityTexture2D NormalTex' -and
        $shaderGraphHlsl -match 'UnityTexture2D OrmTex' -and
        $shaderGraphHlsl -match 'SAMPLE_TEXTURE2D\(BaseColorTex\.tex, BaseColorTex\.samplerstate' -and
        $shaderGraphHlsl -match 'SAMPLE_TEXTURE2D\(NormalTex\.tex, NormalTex\.samplerstate' -and
        $shaderGraphHlsl -match 'SAMPLE_TEXTURE2D\(OrmTex\.tex, OrmTex\.samplerstate') `
        'Shader Graph texture inputs use UnityTexture2D structs and samplers'
    Add-Check ($shaderGraphHlsl -match 'saturate\(Metallic\)' -and
        $shaderGraphHlsl -match 'saturate\(Roughness\)' -and
        $shaderGraphHlsl -match 'clamp\(NormalScale, 0\.0, 2\.0\)' -and
        $shaderGraphHlsl -match 'float3\(0\.0, 0\.0, 1\.0\)') `
        'Shader Graph Custom Function clamps material inputs and handles zero normals'
}

if (Test-Path -LiteralPath $shaderGraphContractPath) {
    $shaderGraphContract = Get-Content -LiteralPath $shaderGraphContractPath -Raw | ConvertFrom-Json
    Add-Check ($shaderGraphContract.sourceType -eq 'File' -and
        $shaderGraphContract.functionName -eq 'TA_SampleMaterialInputs' -and
        @($shaderGraphContract.precisionVariants).Count -eq 2) `
        'Shader Graph contract declares file-mode function and two precisions'
    $inputTypes = @($shaderGraphContract.inputs | ForEach-Object { $_.type })
    $outputNames = @($shaderGraphContract.outputs | ForEach-Object { $_.name })
    Add-Check (($inputTypes -contains 'Texture2D') -and ($inputTypes -contains 'Vector2') -and
        ($inputTypes -contains 'Float') -and ($outputNames -contains 'BaseColor') -and
        ($outputNames -contains 'NormalTS') -and ($outputNames -contains 'ORM') -and
        ($outputNames -contains 'Parameters')) `
        'Shader Graph contract covers texture, vector, scalar inputs and PBR outputs'
    Add-Check ($shaderGraphContract.textureContract.resourceType -eq 'UnityTexture2D' -and
        $shaderGraphContract.textureContract.sampleMacro -eq 'SAMPLE_TEXTURE2D' -and
        @($shaderGraphContract.textureContract.accessors) -contains '.tex' -and
        @($shaderGraphContract.textureContract.accessors) -contains '.samplerstate') `
        'Shader Graph contract records struct texture sampling interface'
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
        $bootstrapPath `
        $profilePath `
        $boundarySourcePath `
        $boundaryEditorPath `
        $shaderGraphBootstrapPath
    Add-Check ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $compileOutput)) `
        'ProjectBootstrap compiles against installed Unity assemblies'
}

$assetFiles = Get-ChildItem -LiteralPath (Join-Path $projectPath 'Assets\_TA') `
    -Recurse -File | Where-Object {
        $_.Extension -in '.obj', '.png' -and $_.DirectoryName -match '\\Art(\\|$)'
    }
foreach ($assetFile in $assetFiles) {
    $validName = $assetFile.Name -match '^(SM_|T_)'
    Add-Check $validName ("Imported source uses naming prefix: " + $assetFile.Name)
}

$profileAssets = Get-ChildItem -LiteralPath (Join-Path $projectPath 'Assets\_TA') `
    -Recurse -File -Filter 'MI_*.asset'
foreach ($profileAsset in $profileAssets) {
    Add-Check ($profileAsset.Name -match '^MI_PBR_(Dielectric|RoughMetal|SmoothMetal)\.asset$') `
        ("Material instance profile uses naming prefix: " + $profileAsset.Name)
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
