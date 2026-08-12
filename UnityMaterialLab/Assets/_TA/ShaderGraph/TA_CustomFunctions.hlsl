//UNITY_SHADER_NO_UPGRADE
#ifndef TA_SHADER_GRAPH_CUSTOM_FUNCTIONS_INCLUDED
#define TA_SHADER_GRAPH_CUSTOM_FUNCTIONS_INCLUDED

#include "Library/TA_MaterialFunctions.hlsl"

void TA_SanitizeMaterial_float(
    float Metallic,
    float Roughness,
    float NormalScale,
    float3 NormalTS,
    out float3 Parameters,
    out float3 NormalizedNormal)
{
    float safeMetallic = saturate(Metallic);
    float safeRoughness = saturate(Roughness);
    float safeNormalScale = clamp(NormalScale, 0.0, 2.0);
    Parameters = float3(safeMetallic, safeRoughness, safeNormalScale * 0.5);
    TA_NormalStrength_float(NormalTS, 1.0, NormalizedNormal);
}

void TA_SanitizeMaterial_half(
    half Metallic,
    half Roughness,
    half NormalScale,
    half3 NormalTS,
    out half3 Parameters,
    out half3 NormalizedNormal)
{
    half safeMetallic = saturate(Metallic);
    half safeRoughness = saturate(Roughness);
    half safeNormalScale = clamp(NormalScale, 0.0h, 2.0h);
    Parameters = half3(safeMetallic, safeRoughness, safeNormalScale * 0.5h);
    TA_NormalStrength_half(NormalTS, 1.0h, NormalizedNormal);
}

void TA_SampleMaterialInputs_float(
    UnityTexture2D BaseColorTex,
    UnityTexture2D NormalTex,
    UnityTexture2D OrmTex,
    float2 UV,
    float Metallic,
    float Roughness,
    float NormalScale,
    out float4 BaseColor,
    out float3 NormalTS,
    out float3 ORM,
    out float3 Parameters)
{
    BaseColor = SAMPLE_TEXTURE2D(BaseColorTex.tex, BaseColorTex.samplerstate, UV);
    float3 tangentNormal = SAMPLE_TEXTURE2D(NormalTex.tex, NormalTex.samplerstate, UV).xyz * 2.0 - 1.0;
    TA_NormalStrength_float(tangentNormal, NormalScale, NormalTS);
    float4 packedOrm = SAMPLE_TEXTURE2D(OrmTex.tex, OrmTex.samplerstate, UV);
    TA_UnpackORM_float(packedOrm, ORM.r, ORM.g, ORM.b);
    float3 ignoredNormal;
    TA_SanitizeMaterial_float(Metallic, Roughness, NormalScale, NormalTS, Parameters, ignoredNormal);
}

void TA_SampleMaterialInputs_half(
    UnityTexture2D BaseColorTex,
    UnityTexture2D NormalTex,
    UnityTexture2D OrmTex,
    half2 UV,
    half Metallic,
    half Roughness,
    half NormalScale,
    out half4 BaseColor,
    out half3 NormalTS,
    out half3 ORM,
    out half3 Parameters)
{
    BaseColor = SAMPLE_TEXTURE2D(BaseColorTex.tex, BaseColorTex.samplerstate, UV);
    half3 tangentNormal = SAMPLE_TEXTURE2D(NormalTex.tex, NormalTex.samplerstate, UV).xyz * 2.0h - 1.0h;
    TA_NormalStrength_half(tangentNormal, NormalScale, NormalTS);
    half4 packedOrm = SAMPLE_TEXTURE2D(OrmTex.tex, OrmTex.samplerstate, UV);
    TA_UnpackORM_half(packedOrm, ORM.r, ORM.g, ORM.b);
    half3 ignoredNormal;
    TA_SanitizeMaterial_half(Metallic, Roughness, NormalScale, NormalTS, Parameters, ignoredNormal);
}

#endif
