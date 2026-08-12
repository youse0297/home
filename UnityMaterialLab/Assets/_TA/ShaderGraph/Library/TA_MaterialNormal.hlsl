//UNITY_SHADER_NO_UPGRADE
#ifndef TA_MATERIAL_NORMAL_INCLUDED
#define TA_MATERIAL_NORMAL_INCLUDED

#define TA_MATERIAL_NORMAL_EPSILON 0.0001

void TA_NormalStrength_float(
    float3 NormalTS,
    float Strength,
    out float3 Out)
{
    float3 scaledNormal = float3(
        NormalTS.xy * clamp(Strength, 0.0, 2.0),
        NormalTS.z);
    float normalLength = length(scaledNormal);
    Out = normalLength > TA_MATERIAL_NORMAL_EPSILON
        ? scaledNormal / normalLength
        : float3(0.0, 0.0, 1.0);
}

void TA_NormalStrength_half(
    half3 NormalTS,
    half Strength,
    out half3 Out)
{
    half3 scaledNormal = half3(
        NormalTS.xy * clamp(Strength, 0.0h, 2.0h),
        NormalTS.z);
    half normalLength = length(scaledNormal);
    Out = normalLength > (half)TA_MATERIAL_NORMAL_EPSILON
        ? scaledNormal / normalLength
        : half3(0.0h, 0.0h, 1.0h);
}

#endif
