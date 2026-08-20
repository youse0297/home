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
$materialFunctionRootPath = Join-Path $projectPath 'Assets\_TA\ShaderGraph\Library'
$materialFunctionAggregatePath = Join-Path $materialFunctionRootPath 'TA_MaterialFunctions.hlsl'
$materialFunctionUvPath = Join-Path $materialFunctionRootPath 'TA_MaterialUV.hlsl'
$materialFunctionNormalPath = Join-Path $materialFunctionRootPath 'TA_MaterialNormal.hlsl'
$materialFunctionChannelsPath = Join-Path $materialFunctionRootPath 'TA_MaterialChannels.hlsl'
$materialFunctionColorPath = Join-Path $materialFunctionRootPath 'TA_MaterialColor.hlsl'
$materialFunctionManifestPath = Join-Path $projectPath 'Assets\_TA\Documentation\MaterialFunctionLibraryV1.json'
$materialFunctionExamplePath = Join-Path $projectPath 'Assets\_TA\Documentation\MaterialFunctionLibraryExample.json'
$materialFunctionValidationPath = Join-Path $projectPath 'Tools\ValidateMaterialFunctionLibrary.ps1'
$textureCompressionPolicyPath = Join-Path $projectPath 'Assets\_TA\Editor\TextureCompressionPolicy.cs'
$textureCompressionMatrixPath = Join-Path $projectPath 'Assets\_TA\Documentation\TextureCompressionMatrix.json'
$textureCompressionBoardPath = Join-Path $projectPath 'Reports\TextureCompressionBoard.png'
$textureCompressionReportPath = Join-Path $projectPath 'Reports\TextureCompressionValidation.json'
$textureCompressionBoardScriptPath = Join-Path $projectPath 'Tools\GenerateTextureCompressionBoard.ps1'
$lodPolicyPath = Join-Path $projectPath 'Assets\_TA\Runtime\LodPolicy.cs'
$lodPolicyMetaPath = Join-Path $projectPath 'Assets\_TA\Runtime\LodPolicy.cs.meta'
$lodBootstrapPath = Join-Path $projectPath 'Assets\_TA\Editor\LodTestBootstrap.cs'
$lodMatrixPath = Join-Path $projectPath 'Assets\_TA\Documentation\LODValidation.json'
$lodBoardPath = Join-Path $projectPath 'Reports\LODComparisonBoard.png'
$lodReportPath = Join-Path $projectPath 'Reports\LODValidationReport.json'
$lodBoardScriptPath = Join-Path $projectPath 'Tools\GenerateLodBoard.ps1'
$renderDocFeaturePath = Join-Path $projectPath 'Assets\_TA\Runtime\RenderDocCaptureFeature.cs'
$renderDocFeatureMetaPath = Join-Path $projectPath 'Assets\_TA\Runtime\RenderDocCaptureFeature.cs.meta'
$renderDocBootstrapPath = Join-Path $projectPath 'Assets\_TA\Editor\RenderDocCaptureBootstrap.cs'
$renderDocBootstrapMetaPath = Join-Path $projectPath 'Assets\_TA\Editor\RenderDocCaptureBootstrap.cs.meta'
$renderDocManifestPath = Join-Path $projectPath 'Assets\_TA\Documentation\RenderDocCaptureManifest.json'
$renderDocReadinessPath = Join-Path $projectPath 'Reports\RenderDocCaptureReadiness.json'
$renderDocCheckScriptPath = Join-Path $projectPath 'Tools\RenderDocCaptureCheck.ps1'
$renderDocDropReadmePath = Join-Path $projectPath 'Reports\RenderDoc\README.md'
$basePassShaderPath = Join-Path $projectPath 'Assets\_TA\Shaders\TA_BasePassLightingDecomposition.shader'
$basePassShaderMetaPath = Join-Path $projectPath 'Assets\_TA\Shaders\TA_BasePassLightingDecomposition.shader.meta'
$basePassControllerPath = Join-Path $projectPath 'Assets\_TA\Runtime\BasePassLightingDebugController.cs'
$basePassControllerMetaPath = Join-Path $projectPath 'Assets\_TA\Runtime\BasePassLightingDebugController.cs.meta'
$basePassBootstrapPath = Join-Path $projectPath 'Assets\_TA\Editor\BasePassLightingBootstrap.cs'
$basePassBootstrapMetaPath = Join-Path $projectPath 'Assets\_TA\Editor\BasePassLightingBootstrap.cs.meta'
$basePassManifestPath = Join-Path $projectPath 'Assets\_TA\Documentation\BasePassLightingDecomposition.json'
$basePassBoardScriptPath = Join-Path $projectPath 'Tools\GenerateBasePassLightingBoard.ps1'
$basePassBoardPath = Join-Path $projectPath 'Reports\BasePassLightingDecompositionBoard.png'
$basePassReportPath = Join-Path $projectPath 'Reports\BasePassLightingValidation.json'
$hlslLibraryRootPath = Join-Path $projectPath 'Assets\_TA\Shaders\Library'
$hlslLibraryAggregatePath = Join-Path $hlslLibraryRootPath 'TA_ShaderLibrary.hlsl'
$hlslLibraryTypesPath = Join-Path $hlslLibraryRootPath 'TA_ShaderTypes.hlsl'
$hlslLibraryCommonPath = Join-Path $hlslLibraryRootPath 'TA_Common.hlsl'
$hlslLibraryVectorPath = Join-Path $hlslLibraryRootPath 'TA_Vector.hlsl'
$hlslLibrarySamplingPath = Join-Path $hlslLibraryRootPath 'TA_Sampling.hlsl'
$hlslLibraryPbrInputPath = Join-Path $hlslLibraryRootPath 'TA_PBRInput.hlsl'
$hlslLibraryBrdfPath = Join-Path $hlslLibraryRootPath 'TA_BRDF.hlsl'
$hlslLibraryLightingPath = Join-Path $hlslLibraryRootPath 'TA_Lighting.hlsl'
$hlslLibraryDebugPath = Join-Path $hlslLibraryRootPath 'TA_DebugViews.hlsl'
$hlslLibraryManifestPath = Join-Path $projectPath 'Assets\_TA\Documentation\HlslSourceLibrary.json'
$hlslLibraryValidationPath = Join-Path $projectPath 'Tools\ValidateHlslSourceLibrary.ps1'
$hlslLibraryReportPath = Join-Path $projectPath 'Reports\HlslSourceLibraryValidation.json'
$vectorSamplingManifestPath = Join-Path $projectPath 'Assets\_TA\Documentation\VectorSamplingUtilities.json'
$vectorSamplingValidationPath = Join-Path $projectPath 'Tools\ValidateVectorSamplingUtilities.ps1'
$vectorSamplingReportPath = Join-Path $projectPath 'Reports\VectorSamplingUtilitiesValidation.json'
$pbrInputManifestPath = Join-Path $projectPath 'Assets\_TA\Documentation\PbrInputLayer.json'
$pbrInputValidationPath = Join-Path $projectPath 'Tools\ValidatePbrInputLayer.ps1'
$pbrInputReportPath = Join-Path $projectPath 'Reports\PbrInputLayerValidation.json'
$ggxNdfSourcePath = Join-Path $hlslLibraryRootPath 'TA_BRDF.hlsl'
$ggxNdfManifestPath = Join-Path $projectPath 'Assets\_TA\Documentation\GgxNormalDistribution.json'
$ggxNdfValidationPath = Join-Path $projectPath 'Tools\ValidateGgxNormalDistribution.ps1'
$ggxNdfReportPath = Join-Path $projectPath 'Reports\GgxNormalDistributionValidation.json'
$ggxGeometryFresnelManifestPath = Join-Path $projectPath 'Assets\_TA\Documentation\GgxGeometryFresnel.json'
$ggxGeometryFresnelValidationPath = Join-Path $projectPath 'Tools\ValidateGgxGeometryFresnel.ps1'
$ggxGeometryFresnelReportPath = Join-Path $projectPath 'Reports\GgxGeometryFresnelValidation.json'

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
Add-Check (Test-Path -LiteralPath $basePassShaderPath -PathType Leaf) `
    'BasePass lighting decomposition shader exists'
Add-Check (Test-Path -LiteralPath $basePassShaderMetaPath -PathType Leaf) `
    'BasePass lighting decomposition shader meta exists'
Add-Check (Test-Path -LiteralPath $basePassControllerPath -PathType Leaf) `
    'BasePass debug controller exists'
Add-Check (Test-Path -LiteralPath $basePassControllerMetaPath -PathType Leaf) `
    'BasePass debug controller meta exists'
Add-Check (Test-Path -LiteralPath $basePassBootstrapPath -PathType Leaf) `
    'BasePass decomposition scene bootstrap exists'
Add-Check (Test-Path -LiteralPath $basePassBootstrapMetaPath -PathType Leaf) `
    'BasePass decomposition scene bootstrap meta exists'
Add-Check (Test-Path -LiteralPath $basePassManifestPath -PathType Leaf) `
    'BasePass lighting decomposition contract exists'
Add-Check (Test-Path -LiteralPath $basePassBoardScriptPath -PathType Leaf) `
    'BasePass lighting board generator exists'
Add-Check (Test-Path -LiteralPath $basePassBoardPath -PathType Leaf) `
    'BasePass lighting decomposition board exists'
Add-Check (Test-Path -LiteralPath $basePassReportPath -PathType Leaf) `
    'BasePass lighting validation report exists'
Add-Check (Test-Path -LiteralPath $hlslLibraryAggregatePath -PathType Leaf) `
    'HLSL source library aggregate exists'
Add-Check ((@(
    $hlslLibraryTypesPath,
    $hlslLibraryCommonPath,
    $hlslLibraryVectorPath,
    $hlslLibrarySamplingPath,
    $hlslLibraryPbrInputPath,
    $hlslLibraryBrdfPath,
    $hlslLibraryLightingPath,
    $hlslLibraryDebugPath
) | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }).Count -eq 0) `
    'HLSL source library contains all eight modules'
Add-Check (Test-Path -LiteralPath $hlslLibraryManifestPath -PathType Leaf) `
    'HLSL source library contract exists'
Add-Check (Test-Path -LiteralPath $hlslLibraryValidationPath -PathType Leaf) `
    'HLSL source library validator exists'
Add-Check (Test-Path -LiteralPath $hlslLibraryReportPath -PathType Leaf) `
    'HLSL source library validation report exists'
Add-Check (Test-Path -LiteralPath $vectorSamplingManifestPath -PathType Leaf) `
    'Vector and sampling utility contract exists'
Add-Check (Test-Path -LiteralPath $vectorSamplingValidationPath -PathType Leaf) `
    'Vector and sampling utility validator exists'
Add-Check (Test-Path -LiteralPath $vectorSamplingReportPath -PathType Leaf) `
    'Vector and sampling utility validation report exists'
Add-Check (Test-Path -LiteralPath $pbrInputManifestPath -PathType Leaf) `
    'Simplified PBR input contract exists'
Add-Check (Test-Path -LiteralPath $pbrInputValidationPath -PathType Leaf) `
    'Simplified PBR input validator exists'
Add-Check (Test-Path -LiteralPath $pbrInputReportPath -PathType Leaf) `
    'Simplified PBR input validation report exists'
Add-Check (Test-Path -LiteralPath $ggxNdfManifestPath -PathType Leaf) `
    'GGX normal distribution contract exists'
Add-Check (Test-Path -LiteralPath $ggxNdfValidationPath -PathType Leaf) `
    'GGX normal distribution validator exists'
Add-Check (Test-Path -LiteralPath $ggxNdfReportPath -PathType Leaf) `
    'GGX normal distribution validation report exists'
Add-Check (Test-Path -LiteralPath $ggxGeometryFresnelManifestPath -PathType Leaf) `
    'GGX geometry and Fresnel contract exists'
Add-Check (Test-Path -LiteralPath $ggxGeometryFresnelValidationPath -PathType Leaf) `
    'GGX geometry and Fresnel validator exists'
Add-Check (Test-Path -LiteralPath $ggxGeometryFresnelReportPath -PathType Leaf) `
    'GGX geometry and Fresnel validation report exists'
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
Add-Check (Test-Path -LiteralPath $materialFunctionAggregatePath -PathType Leaf) `
    'Material function library aggregate include exists'
foreach ($materialFunctionSourcePath in @(
    $materialFunctionUvPath,
    $materialFunctionNormalPath,
    $materialFunctionChannelsPath,
    $materialFunctionColorPath
)) {
    Add-Check (Test-Path -LiteralPath $materialFunctionSourcePath -PathType Leaf) `
        ('Material function library source exists: ' + (Split-Path $materialFunctionSourcePath -Leaf))
}
Add-Check (Test-Path -LiteralPath $materialFunctionManifestPath -PathType Leaf) `
    'Material function library manifest exists'
Add-Check (Test-Path -LiteralPath $materialFunctionExamplePath -PathType Leaf) `
    'Material function library fixed-baseline example exists'
Add-Check (Test-Path -LiteralPath $materialFunctionValidationPath -PathType Leaf) `
    'Material function library numeric validator exists'
Add-Check (Test-Path -LiteralPath $textureCompressionPolicyPath -PathType Leaf) `
    'Texture compression policy source exists'
Add-Check (Test-Path -LiteralPath $textureCompressionMatrixPath -PathType Leaf) `
    'Texture compression matrix exists'
Add-Check (Test-Path -LiteralPath $textureCompressionBoardPath -PathType Leaf) `
    'Texture compression comparison board exists'
Add-Check (Test-Path -LiteralPath $textureCompressionReportPath -PathType Leaf) `
    'Texture compression validation report exists'
Add-Check (Test-Path -LiteralPath $textureCompressionBoardScriptPath -PathType Leaf) `
    'Texture compression board generator exists'
Add-Check (Test-Path -LiteralPath $lodPolicyPath -PathType Leaf) `
    'LOD policy source exists'
Add-Check (Test-Path -LiteralPath $lodPolicyMetaPath -PathType Leaf) `
    'LOD policy meta exists'
Add-Check (Test-Path -LiteralPath $lodBootstrapPath -PathType Leaf) `
    'LOD test scene generator exists'
Add-Check (Test-Path -LiteralPath $lodMatrixPath -PathType Leaf) `
    'LOD validation baseline exists'
Add-Check (Test-Path -LiteralPath $lodBoardPath -PathType Leaf) `
    'LOD comparison board exists'
Add-Check (Test-Path -LiteralPath $lodReportPath -PathType Leaf) `
    'LOD validation report exists'
Add-Check (Test-Path -LiteralPath $lodBoardScriptPath -PathType Leaf) `
    'LOD board generator exists'
Add-Check (Test-Path -LiteralPath $renderDocFeaturePath -PathType Leaf) `
    'RenderDoc marker Renderer Feature source exists'
Add-Check (Test-Path -LiteralPath $renderDocFeatureMetaPath -PathType Leaf) `
    'RenderDoc marker Renderer Feature meta exists'
Add-Check (Test-Path -LiteralPath $renderDocBootstrapPath -PathType Leaf) `
    'RenderDoc capture preparation menu source exists'
Add-Check (Test-Path -LiteralPath $renderDocBootstrapMetaPath -PathType Leaf) `
    'RenderDoc capture preparation menu meta exists'
Add-Check (Test-Path -LiteralPath $renderDocManifestPath -PathType Leaf) `
    'RenderDoc capture manifest exists'
Add-Check (Test-Path -LiteralPath $renderDocReadinessPath -PathType Leaf) `
    'RenderDoc readiness report exists'
Add-Check (Test-Path -LiteralPath $renderDocCheckScriptPath -PathType Leaf) `
    'RenderDoc readiness checker exists'
Add-Check (Test-Path -LiteralPath $renderDocDropReadmePath -PathType Leaf) `
    'RenderDoc capture drop instructions exist'

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
        $shaderGraphHlsl -match 'TA_NormalStrength_float' -and
        $shaderGraphHlsl -match 'TA_UnpackORM_float') `
        'Shader Graph Custom Function clamps parameters and reuses library safety functions'
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

if (Test-Path -LiteralPath $materialFunctionAggregatePath) {
    $materialFunctionAggregate = Get-Content -LiteralPath $materialFunctionAggregatePath -Raw
    Add-Check ($materialFunctionAggregate -match '#include "TA_MaterialUV\.hlsl"' -and
        $materialFunctionAggregate -match '#include "TA_MaterialNormal\.hlsl"' -and
        $materialFunctionAggregate -match '#include "TA_MaterialChannels\.hlsl"' -and
        $materialFunctionAggregate -match '#include "TA_MaterialColor\.hlsl"') `
        'Material function aggregate includes UV, normal, channel and color modules'
}

if ((Test-Path -LiteralPath $materialFunctionUvPath) -and
    (Test-Path -LiteralPath $materialFunctionNormalPath) -and
    (Test-Path -LiteralPath $materialFunctionChannelsPath) -and
    (Test-Path -LiteralPath $materialFunctionColorPath)) {
    $materialFunctionSources = @(
        (Get-Content -LiteralPath $materialFunctionUvPath -Raw),
        (Get-Content -LiteralPath $materialFunctionNormalPath -Raw),
        (Get-Content -LiteralPath $materialFunctionChannelsPath -Raw),
        (Get-Content -LiteralPath $materialFunctionColorPath -Raw)
    ) -join [Environment]::NewLine
    foreach ($functionName in @(
        'TA_TransformUV',
        'TA_RotateUV',
        'TA_NormalStrength',
        'TA_UnpackORM',
        'TA_UnpackRGBA',
        'TA_AdjustColor'
    )) {
        Add-Check ($materialFunctionSources -match ('void ' + $functionName + '_float') -and
            $materialFunctionSources -match ('void ' + $functionName + '_half')) `
            ('Material function provides float and half variants: ' + $functionName)
    }
    Add-Check ($materialFunctionSources -match 'clamp\(Strength, 0\.0, 2\.0\)' -and
        $materialFunctionSources -match 'saturate\(Packed\.rgb\)' -and
        $materialFunctionSources -match 'dot\(Color, float3\(0\.2126, 0\.7152, 0\.0722\)\)') `
        'Material function library applies normal, channel and color safety rules'
}

if (Test-Path -LiteralPath $materialFunctionManifestPath) {
    $materialFunctionManifest = Get-Content -LiteralPath $materialFunctionManifestPath -Raw | ConvertFrom-Json
    Add-Check ($materialFunctionManifest.version -eq '1.0.0' -and
        @($materialFunctionManifest.functions).Count -eq 6 -and
        @($materialFunctionManifest.fixtures).Count -eq 6) `
        'Material function library v1 declares six functions and fixed fixtures'
    $categories = @($materialFunctionManifest.functions | ForEach-Object { $_.category } | Select-Object -Unique)
    Add-Check (($categories -contains 'UV') -and ($categories -contains 'Normal') -and
        ($categories -contains 'Channels') -and ($categories -contains 'Color')) `
        'Material function library covers required UV, normal, channel and color categories'
}

if (Test-Path -LiteralPath $materialFunctionExamplePath) {
    $materialFunctionExample = Get-Content -LiteralPath $materialFunctionExamplePath -Raw | ConvertFrom-Json
    $exampleFunctions = @($materialFunctionExample.nodes | ForEach-Object { $_.function })
    Add-Check ($materialFunctionExample.status -eq 'FIXED_BASELINE_VALIDATED' -and
        @($materialFunctionExample.nodes).Count -eq 6 -and
        @($exampleFunctions | Select-Object -Unique).Count -eq 6) `
        'Material function library example covers six fixed node baselines'
    Add-Check (($exampleFunctions -contains 'TA_TransformUV') -and
        ($exampleFunctions -contains 'TA_NormalStrength') -and
        ($exampleFunctions -contains 'TA_UnpackORM') -and
        ($exampleFunctions -contains 'TA_AdjustColor')) `
        'Material function library example connects required function categories'
}

if (Test-Path -LiteralPath $textureCompressionPolicyPath) {
    $textureCompressionPolicy = Get-Content -LiteralPath $textureCompressionPolicyPath -Raw
    Add-Check ($textureCompressionPolicy -match 'TextureImporterFormat\.BC7' -and
        $textureCompressionPolicy -match 'TextureImporterFormat\.BC5' -and
        $textureCompressionPolicy -match 'TextureImporterFormat\.DXT1' -and
        $textureCompressionPolicy -match 'crunchedCompression = false') `
        'Texture compression policy selects BC7, BC5 and BC1 without Crunch'
}

if (Test-Path -LiteralPath $textureCompressionMatrixPath) {
    $textureCompressionMatrix = Get-Content -LiteralPath $textureCompressionMatrixPath -Raw | ConvertFrom-Json
    Add-Check ($textureCompressionMatrix.platform -eq 'Standalone' -and
        $textureCompressionMatrix.benchmark.width -eq 64 -and
        $textureCompressionMatrix.benchmark.height -eq 64 -and
        @($textureCompressionMatrix.assets).Count -eq 3) `
        'Texture compression matrix fixes Standalone 64x64 benchmark and three assets'
    $baseColor = @($textureCompressionMatrix.assets | Where-Object { $_.usage -eq 'BaseColor' })[0]
    $normal = @($textureCompressionMatrix.assets | Where-Object { $_.usage -eq 'Normal' })[0]
    $packedData = @($textureCompressionMatrix.assets | Where-Object { $_.usage -eq 'PackedData' })[0]
    Add-Check ($baseColor.standaloneFormat -eq 'BC7' -and $baseColor.sRGB -eq $true -and
        $normal.standaloneFormat -eq 'BC5' -and $normal.sRGB -eq $false -and
        $packedData.standaloneFormat -eq 'BC1' -and $packedData.sRGB -eq $false) `
        'Texture compression matrix preserves sRGB/linear semantics per asset'
    $expectedRgbaBytes = 21844
    $expectedBc1Bytes = 2744
    $expectedBc5Bytes = 5488
    Add-Check ($textureCompressionMatrix.formatComparison | Where-Object { $_.format -eq 'RGBA32' }).fullMipBytes -eq $expectedRgbaBytes `
        'RGBA32 full mip footprint matches block benchmark'
    Add-Check ($textureCompressionMatrix.formatComparison | Where-Object { $_.format -eq 'BC1' }).fullMipBytes -eq $expectedBc1Bytes `
        'BC1 full mip footprint matches block benchmark'
    Add-Check ($textureCompressionMatrix.formatComparison | Where-Object { $_.format -eq 'BC5' }).fullMipBytes -eq $expectedBc5Bytes `
        'BC5 full mip footprint matches block benchmark'
    Add-Check ($textureCompressionMatrix.formatComparison | Where-Object { $_.format -eq 'BC7' }).fullMipBytes -eq $expectedBc5Bytes `
        'BC7 full mip footprint matches block benchmark'
}

if (Test-Path -LiteralPath $textureCompressionReportPath) {
    $textureCompressionReport = Get-Content -LiteralPath $textureCompressionReportPath -Raw | ConvertFrom-Json
    Add-Check ($textureCompressionReport.status -eq 'PASS' -and
        $textureCompressionReport.codecStatus -eq 'BC1_REFERENCE_PASS') `
        'Texture compression report contains a passing BC1 reference round-trip'
}

if (Test-Path -LiteralPath $textureCompressionBoardPath) {
    $textureCompressionImage = [System.Drawing.Image]::FromFile($textureCompressionBoardPath)
    try {
        Add-Check ($textureCompressionImage.Width -eq 1440 -and $textureCompressionImage.Height -eq 900) `
            'Texture compression comparison board is 1440x900'
    } finally {
        $textureCompressionImage.Dispose()
    }
}

if (Test-Path -LiteralPath $lodPolicyPath) {
    $lodPolicy = Get-Content -LiteralPath $lodPolicyPath -Raw
    Add-Check ($lodPolicy -match 'HighScreenHeight = 0\.60f' -and
        $lodPolicy -match 'MediumScreenHeight = 0\.25f' -and
        $lodPolicy -match 'LowScreenHeight = 0\.05f' -and
        $lodPolicy -match 'CrossFadeDuration = 0\.15f' -and
        $lodPolicy -match 'ResolveLevel' -and
        $lodPolicy -match 'HasMonotonicThresholds') `
        'LOD policy fixes thresholds, cross-fade duration and resolver'
}

if (Test-Path -LiteralPath $lodBootstrapPath) {
    $lodBootstrap = Get-Content -LiteralPath $lodBootstrapPath -Raw
    Add-Check ($lodBootstrap -match 'LODGroup' -and
        $lodBootstrap -match 'SetLODs' -and
        $lodBootstrap -match 'LODFadeMode\.CrossFade' -and
        $lodBootstrap -match 'QualitySettings\.lodBias' -and
        $lodBootstrap -match 'SCN_LOD_Baseline') `
        'LOD bootstrap creates a three-level cross-fade comparison scene'
}

if (Test-Path -LiteralPath $lodMatrixPath) {
    $lodMatrix = Get-Content -LiteralPath $lodMatrixPath -Raw | ConvertFrom-Json
    Add-Check ($lodMatrix.status -eq 'STATIC_BASELINE_VALIDATED' -and
        $lodMatrix.lodBias -eq 1.0 -and $lodMatrix.crossFadeDuration -eq 0.15 -and
        @($lodMatrix.levels).Count -eq 3 -and @($lodMatrix.switches).Count -eq 4) `
        'LOD baseline records three levels, four switch samples and fixed runtime settings'
    Add-Check ($lodMatrix.levels[0].screenHeight -gt $lodMatrix.levels[1].screenHeight -and
        $lodMatrix.levels[1].screenHeight -gt $lodMatrix.levels[2].screenHeight -and
        $lodMatrix.levels[2].screenHeight -gt 0.0) `
        'LOD baseline thresholds are strictly monotonic'
    $expectedSwitches = @(
        @{ id = 'LOD0'; level = 0; name = 'High' },
        @{ id = 'LOD1'; level = 1; name = 'Medium' },
        @{ id = 'LOD2'; level = 2; name = 'Low' },
        @{ id = 'CULLED'; level = 3; name = 'Culled' }
    )
    foreach ($expected in $expectedSwitches) {
        $actual = @($lodMatrix.switches | Where-Object { $_.id -eq $expected.id })[0]
        Add-Check ($null -ne $actual -and $actual.expectedLevel -eq $expected.level -and
            $actual.expectedName -eq $expected.name) `
            ('LOD switch sample resolves as expected: ' + $expected.id)
    }
}

if (Test-Path -LiteralPath $lodReportPath) {
    $lodReport = Get-Content -LiteralPath $lodReportPath -Raw | ConvertFrom-Json
    Add-Check ($lodReport.status -eq 'PASS' -and $lodReport.policyStatus -eq 'STATIC_BASELINE_VALIDATED' -and
        $lodReport.thresholdsMonotonic -eq $true) `
        'LOD report confirms passing static baseline and monotonic thresholds'
}

if (Test-Path -LiteralPath $lodBoardPath) {
    $lodImage = [System.Drawing.Image]::FromFile($lodBoardPath)
    try {
        Add-Check ($lodImage.Width -eq 1440 -and $lodImage.Height -eq 900) `
            'LOD comparison board is 1440x900'
    } finally {
        $lodImage.Dispose()
    }
}

if (Test-Path -LiteralPath $renderDocFeaturePath) {
    $renderDocFeature = Get-Content -LiteralPath $renderDocFeaturePath -Raw
    Add-Check ($renderDocFeature -match 'ScriptableRendererFeature' -and
        $renderDocFeature -match 'ScriptableRenderPass' -and
        $renderDocFeature -match 'RD/Opaque/Boundary' -and
        $renderDocFeature -match 'RD/Lighting/Forward' -and
        $renderDocFeature -match 'RD/PostFX/Boundary' -and
        $renderDocFeature -match 'ProfilingScope') `
        'RenderDoc feature exposes GPU bookmarks for frame, opaque, lighting, transparent and post FX boundaries'
}

if (Test-Path -LiteralPath $renderDocBootstrapPath) {
    $renderDocBootstrap = Get-Content -LiteralPath $renderDocBootstrapPath -Raw
    Add-Check ($renderDocBootstrap -match 'Prepare RenderDoc Capture' -and
        $renderDocBootstrap -match 'defaultScreenWidth = 1280' -and
        $renderDocBootstrap -match 'defaultScreenHeight = 720' -and
        $renderDocBootstrap -match 'vSyncCount = 0' -and
        $renderDocBootstrap -match 'AttachMarkerFeature' -and
        $renderDocBootstrap -match 'EditorBuildSettings\.scenes') `
        'RenderDoc preparation fixes resolution, VSync, marker attachment and scene selection'
}

if (Test-Path -LiteralPath $renderDocManifestPath) {
    $renderDocManifest = Get-Content -LiteralPath $renderDocManifestPath -Raw | ConvertFrom-Json
    Add-Check ($renderDocManifest.status -eq 'PREPARED' -and
        $renderDocManifest.captureStatus -eq 'PENDING_CAPTURE' -and
        $renderDocManifest.width -eq 1280 -and $renderDocManifest.height -eq 720 -and
        $renderDocManifest.targetFrameRate -eq 30 -and $renderDocManifest.vSyncCount -eq 0 -and
        $renderDocManifest.renderScale -eq 1.0 -and $renderDocManifest.msaaSamples -eq 1 -and
        @($renderDocManifest.markers).Count -eq 6 -and @($renderDocManifest.bookmarks).Count -eq 6) `
        'RenderDoc manifest fixes a stable 1280x720 capture and six event bookmarks'
    Add-Check (($renderDocManifest.bookmarks -contains 'RD/Opaque/Boundary') -and
        ($renderDocManifest.bookmarks -contains 'RD/Lighting/Forward') -and
        ($renderDocManifest.bookmarks -contains 'RD/Transparent/Boundary') -and
        ($renderDocManifest.bookmarks -contains 'RD/PostFX/Boundary')) `
        'RenderDoc manifest records Opaque, Lighting, Transparent and PostFX bookmark names'
}

if (Test-Path -LiteralPath $renderDocReadinessPath) {
    $renderDocReadiness = Get-Content -LiteralPath $renderDocReadinessPath -Raw | ConvertFrom-Json
    Add-Check ($renderDocReadiness.preparationStatus -eq 'PREPARED' -and
        $renderDocReadiness.markerCount -eq 6 -and
        $renderDocReadiness.captureStatus -in @('RENDERDOC_FOUND', 'RENDERDOC_NOT_INSTALLED')) `
        'RenderDoc readiness report matches the six-marker preparation manifest'
}

if (Test-Path -LiteralPath $basePassShaderPath) {
    $basePassShader = Get-Content -LiteralPath $basePassShaderPath -Raw
    Add-Check ($basePassShader -match 'Name "BasePassLightingDecomposition"' -and
        $basePassShader -match '"LightMode" = "UniversalForward"' -and
        $basePassShader -match 'GetMainLight\(input\.shadowCoord\)' -and
        $basePassShader -match 'SampleSH\(surface\.normalWS\)') `
        'BasePass shader uses the URP forward pass, main light shadows and SH ambient light'
    Add-Check ($basePassShader -match '#include "Library/TA_ShaderLibrary\.hlsl"' -and
        $basePassShader -match 'TA_TransformUV\(' -and
        $basePassShader -match 'TA_TransformTangentToWorld\(' -and
        $basePassShader -match 'TA_PBRInputConfig\s+pbrConfig' -and
        $basePassShader -match 'TA_SamplePBRInput\(' -and
        $basePassShader -match 'TA_BuildSurfaceData\(' -and
        $basePassShader -match 'TA_SurfaceData\s+surface' -and
        $basePassShader -match 'TA_LightingInput\s+lightingInput' -and
        $basePassShader -match 'TA_EvaluateLighting\(surface, lightingInput\)' -and
        $basePassShader -match 'TA_SelectDebugView\(') `
        'BasePass shader consumes the HLSL source library through its aggregate entry point'
    Add-Check ($basePassShader -match '_BaseMap' -and
        $basePassShader -match '_BumpMap' -and
        $basePassShader -match '_ORMMap' -and
        $basePassShader -match 'pbrConfig\.baseColorTint' -and
        $basePassShader -match 'pbrConfig\.normalScale' -and
        $basePassShader -match 'pbrConfig\.ambientOcclusionStrength' -and
        $basePassShader -match 'pbrConfig\.roughnessScale' -and
        $basePassShader -match 'pbrConfig\.metallicScale' -and
        $basePassShader -match 'pbrInput\.alpha') `
        'BasePass binds the three PBR maps through the simplified input configuration'
    Add-Check ($basePassShader -match 'Direct Diffuse,6' -and
        $basePassShader -match 'Direct Specular,7' -and
        $basePassShader -match 'Indirect Diffuse,8' -and
        $basePassShader -match 'Shadow Attenuation,9' -and
        $basePassShader -match 'UsePass "Universal Render Pipeline/Lit/ShadowCaster"') `
        'BasePass shader declares all lighting views and supporting depth/shadow passes'
}

if (Test-Path -LiteralPath $hlslLibraryAggregatePath) {
    $hlslLibraryAggregate = Get-Content -LiteralPath $hlslLibraryAggregatePath -Raw
    Add-Check ($hlslLibraryAggregate -match '#include "TA_ShaderTypes\.hlsl"' -and
        $hlslLibraryAggregate -match '#include "TA_Common\.hlsl"' -and
        $hlslLibraryAggregate -match '#include "TA_Vector\.hlsl"' -and
        $hlslLibraryAggregate -match '#include "TA_Sampling\.hlsl"' -and
        $hlslLibraryAggregate -match '#include "TA_PBRInput\.hlsl"' -and
        $hlslLibraryAggregate -match '#include "TA_BRDF\.hlsl"' -and
        $hlslLibraryAggregate -match '#include "TA_Lighting\.hlsl"' -and
        $hlslLibraryAggregate -match '#include "TA_DebugViews\.hlsl"') `
        'HLSL source library aggregate exposes all modules'
}

if (Test-Path -LiteralPath $hlslLibraryPbrInputPath) {
    $hlslLibraryPbrInput = Get-Content -LiteralPath $hlslLibraryPbrInputPath -Raw
    Add-Check ($hlslLibraryPbrInput -match 'TA_PBRInputConfig' -and
        $hlslLibraryPbrInput -match 'TA_PBRInputData' -and
        $hlslLibraryPbrInput -match 'TA_SamplePBRInput' -and
        $hlslLibraryPbrInput -match 'TA_BuildSurfaceData') `
        'HLSL PBR input module exposes configuration, sampled data and surface assembly'
    Add-Check ($hlslLibraryPbrInput -match 'TA_SampleTexture2D' -and
        $hlslLibraryPbrInput -match 'TA_SampleNormalTS' -and
        $hlslLibraryPbrInput -match 'TA_SampleORM' -and
        $hlslLibraryPbrInput -match 'TA_SanitizePerceptualRoughness') `
        'HLSL PBR input module composes the shared sampling and scalar policies'
}

if ((Test-Path -LiteralPath $hlslLibraryVectorPath) -and
    (Test-Path -LiteralPath $hlslLibrarySamplingPath)) {
    $hlslLibraryVector = Get-Content -LiteralPath $hlslLibraryVectorPath -Raw
    $hlslLibrarySampling = Get-Content -LiteralPath $hlslLibrarySamplingPath -Raw
    Add-Check ($hlslLibraryVector -match 'TA_SafeNormalize' -and
        $hlslLibraryVector -match 'TA_BuildBitangentWS' -and
        $hlslLibraryVector -match 'TA_BuildTangentToWorld' -and
        $hlslLibraryVector -match 'TA_TransformTangentToWorld') `
        'HLSL vector module exposes safe normalization and tangent basis transforms'
    Add-Check ($hlslLibrarySampling -match 'TA_TransformUV' -and
        $hlslLibrarySampling -match 'TEXTURE2D_PARAM' -and
        $hlslLibrarySampling -match 'TEXTURE2D_ARGS' -and
        $hlslLibrarySampling -match 'SAMPLE_TEXTURE2D\(' -and
        $hlslLibrarySampling -match 'SAMPLE_TEXTURE2D_LOD\(' -and
        $hlslLibrarySampling -match 'UnpackNormalScale\(packedNormal, normalScale\)' -and
        $hlslLibrarySampling -match 'TA_SampleORM') `
        'HLSL sampling module preserves Unity texture macros, normal unpacking and ORM decode'
}

if ((Test-Path -LiteralPath $hlslLibraryBrdfPath) -and
    (Test-Path -LiteralPath $hlslLibraryLightingPath) -and
    (Test-Path -LiteralPath $hlslLibraryDebugPath)) {
    $hlslLibraryBrdf = Get-Content -LiteralPath $hlslLibraryBrdfPath -Raw
    $hlslLibraryLighting = Get-Content -LiteralPath $hlslLibraryLightingPath -Raw
    $hlslLibraryDebug = Get-Content -LiteralPath $hlslLibraryDebugPath -Raw
    Add-Check ($hlslLibraryBrdf -match 'TA_FresnelSchlickScalar' -and
        $hlslLibraryBrdf -match 'TA_FresnelSchlick' -and
        $hlslLibraryBrdf -match 'TA_DistributionGGX' -and
        $hlslLibraryBrdf -match 'TA_SmithGGXLambdaTerm' -and
        $hlslLibraryBrdf -match 'TA_VisibilitySmithGGXCorrelated') `
        'HLSL BRDF module exposes Fresnel, GGX distribution, Smith lambda and visibility'
    Add-Check ($hlslLibraryLighting -match 'TA_EvaluateLighting' -and
        $hlslLibraryLighting -match 'result\.finalLit = result\.directDiffuse \+ result\.directSpecular \+ result\.indirectDiffuse') `
        'HLSL lighting module preserves the additive lighting invariant'
    Add-Check ($hlslLibraryDebug -match 'TA_SelectDebugView' -and
        $hlslLibraryDebug -match 'TA_DEBUG_FINAL_LIT' -and
        $hlslLibraryDebug -match 'TA_DEBUG_SHADOW_ATTENUATION') `
        'HLSL debug module fixes the complete debug view range'
}

if (Test-Path -LiteralPath $hlslLibraryManifestPath) {
    $hlslLibraryManifest = Get-Content -LiteralPath $hlslLibraryManifestPath -Raw | ConvertFrom-Json
    Add-Check ($hlslLibraryManifest.status -eq 'STATIC_LIBRARY_VALIDATED' -and
        $hlslLibraryManifest.version -eq '1.4.0' -and
        $hlslLibraryManifest.namespacePrefix -eq 'TA_' -and
        @($hlslLibraryManifest.modules).Count -eq 8 -and
        @($hlslLibraryManifest.invariants).Count -eq 8) `
        'HLSL source library contract fixes version, namespace, modules and invariants'
}

if (Test-Path -LiteralPath $hlslLibraryReportPath) {
    $hlslLibraryReport = Get-Content -LiteralPath $hlslLibraryReportPath -Raw | ConvertFrom-Json
    Add-Check ($hlslLibraryReport.status -eq 'PASS' -and
        $hlslLibraryReport.moduleCount -eq 8 -and
        $hlslLibraryReport.publicSymbolCount -eq 27 -and
        @($hlslLibraryReport.failures).Count -eq 0) `
        'HLSL source library report validates eight modules and twenty-seven public symbols'
}

if (Test-Path -LiteralPath $vectorSamplingManifestPath) {
    $vectorSamplingManifest = Get-Content -LiteralPath $vectorSamplingManifestPath -Raw | ConvertFrom-Json
    Add-Check ($vectorSamplingManifest.status -eq 'STATIC_NUMERIC_VALIDATED' -and
        $vectorSamplingManifest.version -eq '1.1.0' -and
        $vectorSamplingManifest.sourceLibraryVersion -eq '1.4.0' -and
        @($vectorSamplingManifest.functions).Count -eq 10 -and
        @($vectorSamplingManifest.fixtures).Count -eq 9) `
        'Vector and sampling contract fixes ten functions and nine numeric fixtures'
}

if (Test-Path -LiteralPath $vectorSamplingReportPath) {
    $vectorSamplingReport = Get-Content -LiteralPath $vectorSamplingReportPath -Raw | ConvertFrom-Json
    Add-Check ($vectorSamplingReport.status -eq 'PASS' -and
        $vectorSamplingReport.sourceLibraryVersion -eq '1.4.0' -and
        $vectorSamplingReport.functionCount -eq 10 -and
        $vectorSamplingReport.fixtureCount -eq 9 -and
        $vectorSamplingReport.maximumError -le 0.000001 -and
        @($vectorSamplingReport.failures).Count -eq 0) `
        'Vector and sampling report validates numeric fixtures and Unity macro delegation'
}

if (Test-Path -LiteralPath $pbrInputManifestPath) {
    $pbrInputManifest = Get-Content -LiteralPath $pbrInputManifestPath -Raw | ConvertFrom-Json
    Add-Check ($pbrInputManifest.status -eq 'STATIC_NUMERIC_VALIDATED' -and
        $pbrInputManifest.version -eq '1.0.0' -and
        $pbrInputManifest.sourceLibraryVersion -eq '1.4.0' -and
        @($pbrInputManifest.publicSymbols).Count -eq 4 -and
        @($pbrInputManifest.fixtures).Count -eq 3) `
        'Simplified PBR input contract fixes four public symbols and three boundary fixtures'
}

if (Test-Path -LiteralPath $pbrInputReportPath) {
    $pbrInputReport = Get-Content -LiteralPath $pbrInputReportPath -Raw | ConvertFrom-Json
    Add-Check ($pbrInputReport.status -eq 'PASS' -and
        $pbrInputReport.sourceLibraryVersion -eq '1.4.0' -and
        $pbrInputReport.functionCount -eq 4 -and
        $pbrInputReport.fixtureCount -eq 3 -and
        $pbrInputReport.maximumError -le 0.000001 -and
        @($pbrInputReport.failures).Count -eq 0) `
        'Simplified PBR input report validates parameter policies and surface assembly'
}

if (Test-Path -LiteralPath $ggxNdfSourcePath) {
    $ggxNdfSource = Get-Content -LiteralPath $ggxNdfSourcePath -Raw
    Add-Check ($ggxNdfSource -match 'TA_GGXAlphaFromRoughness' -and
        $ggxNdfSource -match 'TA_DistributionGGXFromAlpha' -and
        $ggxNdfSource -match 'TA_DistributionGGX\(' -and
        $ggxNdfSource -match 'TA_MIN_DENOMINATOR') `
        'HLSL BRDF module exposes the explicit GGX alpha and NDF entry points'
}

if (Test-Path -LiteralPath $ggxNdfManifestPath) {
    $ggxNdfManifest = Get-Content -LiteralPath $ggxNdfManifestPath -Raw | ConvertFrom-Json
    Add-Check ($ggxNdfManifest.status -eq 'STATIC_NUMERIC_VALIDATED' -and
        $ggxNdfManifest.version -eq '1.0.0' -and
        $ggxNdfManifest.sourceLibraryVersion -eq '1.4.0' -and
        @($ggxNdfManifest.publicSymbols).Count -eq 3 -and
        @($ggxNdfManifest.fixtures).Count -eq 8) `
        'GGX NDF contract fixes the alpha policy, three entry points and eight fixtures'
}

if (Test-Path -LiteralPath $ggxNdfValidationPath) {
    Add-Check (Test-Path -LiteralPath $ggxNdfReportPath -PathType Leaf) `
        'GGX NDF validator writes a machine-readable report'
}

if (Test-Path -LiteralPath $ggxNdfReportPath) {
    $ggxNdfReport = Get-Content -LiteralPath $ggxNdfReportPath -Raw | ConvertFrom-Json
    Add-Check ($ggxNdfReport.status -eq 'PASS' -and
        $ggxNdfReport.sourceLibraryVersion -eq '1.4.0' -and
        $ggxNdfReport.functionCount -eq 3 -and
        $ggxNdfReport.fixtureCount -eq 8 -and
        $ggxNdfReport.maximumError -le 0.000001 -and
        @($ggxNdfReport.failures).Count -eq 0) `
        'GGX NDF report validates alpha conversion, endpoint values and delegation'
}

if (Test-Path -LiteralPath $ggxGeometryFresnelManifestPath) {
    $ggxGeometryFresnelManifest = Get-Content -LiteralPath $ggxGeometryFresnelManifestPath -Raw | ConvertFrom-Json
    Add-Check ($ggxGeometryFresnelManifest.status -eq 'STATIC_NUMERIC_VALIDATED' -and
        $ggxGeometryFresnelManifest.version -eq '1.0.0' -and
        $ggxGeometryFresnelManifest.sourceLibraryVersion -eq '1.4.0' -and
        @($ggxGeometryFresnelManifest.publicSymbols).Count -eq 4 -and
        @($ggxGeometryFresnelManifest.fixtures).Count -eq 10) `
        'GGX geometry and Fresnel contract fixes four entry points and ten fixtures'
}

if (Test-Path -LiteralPath $ggxGeometryFresnelReportPath) {
    $ggxGeometryFresnelReport = Get-Content -LiteralPath $ggxGeometryFresnelReportPath -Raw | ConvertFrom-Json
    Add-Check ($ggxGeometryFresnelReport.status -eq 'PASS' -and
        $ggxGeometryFresnelReport.sourceLibraryVersion -eq '1.4.0' -and
        $ggxGeometryFresnelReport.functionCount -eq 4 -and
        $ggxGeometryFresnelReport.fixtureCount -eq 10 -and
        $ggxGeometryFresnelReport.maximumError -le 0.000001 -and
        @($ggxGeometryFresnelReport.failures).Count -eq 0) `
        'GGX geometry and Fresnel report validates Schlick and correlated Smith baselines'
}

if (Test-Path -LiteralPath $basePassControllerPath) {
    $basePassController = Get-Content -LiteralPath $basePassControllerPath -Raw
    Add-Check ($basePassController -match 'enum BasePassDebugView' -and
        $basePassController -match 'FinalLit = 0' -and
        $basePassController -match 'ShadowAttenuation = 9' -and
        $basePassController -match 'MaterialPropertyBlock' -and
        $basePassController -match 'SetPropertyBlock' -and
        $basePassController -notmatch '\.material\b') `
        'BasePass controller maps ten views through MaterialPropertyBlock without cloning materials'
}

if (Test-Path -LiteralPath $basePassBootstrapPath) {
    $basePassBootstrap = Get-Content -LiteralPath $basePassBootstrapPath -Raw
    Add-Check ($basePassBootstrap -match 'Build BasePass Lighting Decomposition' -and
        $basePassBootstrap -match 'SCN_BasePassLightingDecomposition' -and
        $basePassBootstrap -match 'Enum\.GetValues' -and
        $basePassBootstrap -match 'BasePassLightingDebugController' -and
        $basePassBootstrap -match 'EDITOR_SCENE_GENERATED') `
        'BasePass bootstrap creates the ten-view scene, material and Editor report'
}

if (Test-Path -LiteralPath $basePassManifestPath) {
    $basePassManifest = Get-Content -LiteralPath $basePassManifestPath -Raw | ConvertFrom-Json
    $basePassViewIds = @($basePassManifest.debugViews | ForEach-Object { $_.id })
    $basePassViewNames = @($basePassManifest.debugViews | ForEach-Object { $_.name })
    Add-Check ($basePassManifest.status -in @('STATIC_BASELINE_VALIDATED', 'EDITOR_SCENE_GENERATED') -and
        $basePassManifest.version -eq '1.0.0' -and
        $basePassManifest.renderPath -eq 'URP Forward / UniversalForward' -and
        @($basePassManifest.debugViews).Count -eq 10) `
        'BasePass contract fixes the URP forward path and ten debug views'
    Add-Check ((0..9 | Where-Object { $basePassViewIds -notcontains $_ }).Count -eq 0 -and
        ($basePassViewNames -contains 'FinalLit') -and
        ($basePassViewNames -contains 'BaseColor') -and
        ($basePassViewNames -contains 'WorldNormal') -and
        ($basePassViewNames -contains 'DirectDiffuse') -and
        ($basePassViewNames -contains 'DirectSpecular') -and
        ($basePassViewNames -contains 'IndirectDiffuse') -and
        ($basePassViewNames -contains 'ShadowAttenuation')) `
        'BasePass contract assigns unique IDs 0 through 9 to required surface and lighting views'
    Add-Check (@($basePassManifest.debugViews | Where-Object { $_.category -eq 'Surface' }).Count -eq 5 -and
        @($basePassManifest.debugViews | Where-Object { $_.category -eq 'Lighting' }).Count -eq 4 -and
        @($basePassManifest.debugViews | Where-Object { $_.category -eq 'Composite' }).Count -eq 1 -and
        @($basePassManifest.invariants).Count -eq 4) `
        'BasePass contract separates surface, lighting and composite outputs with fixed invariants'
}

if (Test-Path -LiteralPath $basePassReportPath) {
    $basePassReport = Get-Content -LiteralPath $basePassReportPath -Raw | ConvertFrom-Json
    Add-Check ($basePassReport.status -eq 'PASS' -and
        $basePassReport.viewCount -eq 10 -and
        $basePassReport.additiveInvariantDelta -le 0.000001 -and
        $null -ne $basePassReport.outputs.FinalLit -and
        $null -ne $basePassReport.outputs.DirectDiffuse -and
        $null -ne $basePassReport.outputs.DirectSpecular -and
        $null -ne $basePassReport.outputs.IndirectDiffuse) `
        'BasePass analytic report validates all views and the final-light additive invariant'
}

if (Test-Path -LiteralPath $basePassBoardPath) {
    $basePassImage = [System.Drawing.Image]::FromFile($basePassBoardPath)
    try {
        Add-Check ($basePassImage.Width -eq 1440 -and $basePassImage.Height -eq 900) `
            'BasePass lighting decomposition board is 1440x900'
    } finally {
        $basePassImage.Dispose()
    }
}

$dataPath = Join-Path $UnityRoot 'Data'
$dotnetPath = Join-Path $dataPath 'NetCoreRuntime\dotnet.exe'
$compilerPath = Join-Path $dataPath 'DotNetSdkRoslyn\csc.dll'
$netStandardPath = Join-Path $dataPath 'NetStandard\ref\2.1.0\netstandard.dll'
$unityEnginePath = Join-Path $dataPath 'Managed\UnityEngine.dll'
$unityEditorPath = Join-Path $dataPath 'Managed\UnityEditor.dll'
$urpRuntimePath = Join-Path $projectPath 'Library\ScriptAssemblies\Unity.RenderPipelines.Universal.Runtime.dll'
$coreRuntimePath = Join-Path $projectPath 'Library\ScriptAssemblies\Unity.RenderPipelines.Core.Runtime.dll'
$unityCorePath = Join-Path $dataPath 'Managed\UnityEngine\UnityEngine.CoreModule.dll'
$compilerInputs = @(
    $dotnetPath,
    $compilerPath,
    $netStandardPath,
    $unityEnginePath,
    $unityEditorPath,
    $urpRuntimePath,
    $coreRuntimePath
)
$compilerAvailable = ($compilerInputs | Where-Object {
    -not (Test-Path -LiteralPath $_ -PathType Leaf)
}).Count -eq 0
Add-Check $compilerAvailable 'Installed Unity C# compiler inputs are available'

$urpFeatureCompilerAvailable = $compilerAvailable -and
    (Test-Path -LiteralPath $unityCorePath -PathType Leaf)
if ($urpFeatureCompilerAvailable) {
    $checks.Add('Unity CoreModule is available for URP RenderDoc feature compilation')
} else {
    $checks.Add('Unity CoreModule unavailable; RenderDoc URP feature compilation deferred to licensed Editor')
}

if ($compilerAvailable -and (Test-Path -LiteralPath $bootstrapPath)) {
    & $dotnetPath $compilerPath /nologo /target:library /langversion:latest `
        /define:UNITY_EDITOR /out:$compileOutput `
        /reference:$netStandardPath `
        /reference:$unityEnginePath `
        /reference:$unityEditorPath `
        /reference:$urpRuntimePath `
        /reference:$coreRuntimePath `
        $bootstrapPath `
        $profilePath `
        $boundarySourcePath `
        $boundaryEditorPath `
        $shaderGraphBootstrapPath `
        $textureCompressionPolicyPath `
        $lodPolicyPath `
        $lodBootstrapPath `
        $basePassControllerPath `
        $basePassBootstrapPath
    Add-Check ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $compileOutput)) `
        'ProjectBootstrap compiles against installed Unity assemblies'
}

if ($urpFeatureCompilerAvailable) {
    $renderDocCompileOutput = Join-Path $reportsPath 'RenderDocCapture.Static.dll'
    & $dotnetPath $compilerPath /nologo /target:library /langversion:latest `
        /define:UNITY_EDITOR /out:$renderDocCompileOutput `
        /reference:$netStandardPath `
        /reference:$unityCorePath `
        /reference:$unityEditorPath `
        /reference:$urpRuntimePath `
        /reference:$coreRuntimePath `
        $renderDocFeaturePath
    Add-Check ($LASTEXITCODE -eq 0 -and
        (Test-Path -LiteralPath $renderDocCompileOutput)) `
        'RenderDoc capture preparation compiles against Unity and URP assemblies'
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
