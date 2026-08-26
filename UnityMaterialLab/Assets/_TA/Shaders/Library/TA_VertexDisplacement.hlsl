//UNITY_SHADER_NO_UPGRADE
#ifndef TA_VERTEX_DISPLACEMENT_INCLUDED
#define TA_VERTEX_DISPLACEMENT_INCLUDED

#include "TA_Vector.hlsl"

half TA_DecodeVertexDisplacement(
    half heightSample,
    half amplitude,
    half center)
{
    half sanitizedHeight = saturate(heightSample);
    half sanitizedAmplitude = clamp(amplitude, -1.0h, 1.0h);
    half sanitizedCenter = saturate(center);
    return (sanitizedHeight - sanitizedCenter) * sanitizedAmplitude;
}

float3 TA_ApplyVertexDisplacementOS(
    float3 positionOS,
    half3 normalOS,
    half displacement)
{
    half3 normalDirectionOS = TA_SafeNormalize(normalOS);
    return positionOS + (float3)normalDirectionOS * displacement;
}

#endif
