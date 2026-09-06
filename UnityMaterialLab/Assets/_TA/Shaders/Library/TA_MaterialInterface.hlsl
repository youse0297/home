//UNITY_SHADER_NO_UPGRADE
#ifndef TA_MATERIAL_INTERFACE_INCLUDED
#define TA_MATERIAL_INTERFACE_INCLUDED

#include "TA_PBRInput.hlsl"
#include "TA_Anisotropy.hlsl"
#include "TA_Lighting.hlsl"

struct TA_MaterialConfig
{
    half4 baseColorTint;
    half normalScale;
    half ambientOcclusionStrength;
    half roughnessScale;
    half metallicScale;
    half anisotropy;
    half anisotropyRotation;
};

struct TA_MaterialInputData
{
    half3 baseColor;
    half alpha;
    half3 normalTS;
    half ambientOcclusion;
    half roughness;
    half metallic;
};

struct TA_MaterialEvaluation
{
    TA_SurfaceData surface;
    TA_LightingBreakdown lighting;
    half alpha;
};

TA_MaterialInputData TA_SampleMaterial(
    TEXTURE2D_PARAM(baseMap, baseSampler),
    TEXTURE2D_PARAM(normalMap, normalSampler),
    TEXTURE2D_PARAM(ormMap, ormSampler),
    float2 uv,
    TA_MaterialConfig config)
{
    TA_PBRInputConfig pbrConfig;
    pbrConfig.baseColorTint = config.baseColorTint;
    pbrConfig.normalScale = config.normalScale;
    pbrConfig.ambientOcclusionStrength = config.ambientOcclusionStrength;
    pbrConfig.roughnessScale = config.roughnessScale;
    pbrConfig.metallicScale = config.metallicScale;
    TA_PBRInputData pbrInput = TA_SamplePBRInput(
        TEXTURE2D_ARGS(baseMap, baseSampler),
        TEXTURE2D_ARGS(normalMap, normalSampler),
        TEXTURE2D_ARGS(ormMap, ormSampler),
        uv,
        pbrConfig
    );

    TA_MaterialInputData result;
    result.baseColor = pbrInput.baseColor;
    result.alpha = pbrInput.alpha;
    result.normalTS = pbrInput.normalTS;
    result.ambientOcclusion = pbrInput.ambientOcclusion;
    result.roughness = pbrInput.roughness;
    result.metallic = pbrInput.metallic;
    return result;
}

half3 TA_ResolveMaterialNormalWS(
    TA_MaterialInputData inputData,
    half3 vertexNormalWS,
    half4 vertexTangentWS)
{
    return TA_TransformTangentToWorld(
        inputData.normalTS,
        vertexNormalWS,
        vertexTangentWS
    );
}

TA_MaterialEvaluation TA_EvaluateMaterial(
    TA_MaterialInputData inputData,
    half3 normalWS,
    half4 tangentWS,
    TA_LightingInput lightingInput,
    TA_MaterialConfig config)
{
    TA_PBRInputData pbrInput;
    pbrInput.baseColor = inputData.baseColor;
    pbrInput.alpha = inputData.alpha;
    pbrInput.normalTS = inputData.normalTS;
    pbrInput.ambientOcclusion = inputData.ambientOcclusion;
    pbrInput.roughness = inputData.roughness;
    pbrInput.metallic = inputData.metallic;

    TA_SurfaceData surface = TA_BuildSurfaceData(pbrInput, normalWS);
    TA_ApplyAnisotropyToSurface(
        surface,
        tangentWS,
        config.anisotropy,
        config.anisotropyRotation
    );
    TA_MaterialEvaluation result;
    result.surface = surface;
    result.lighting = TA_EvaluateLighting(surface, lightingInput);
    result.alpha = inputData.alpha;
    return result;
}

#endif
