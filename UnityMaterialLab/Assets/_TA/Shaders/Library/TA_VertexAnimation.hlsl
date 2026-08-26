//UNITY_SHADER_NO_UPGRADE
#ifndef TA_VERTEX_ANIMATION_INCLUDED
#define TA_VERTEX_ANIMATION_INCLUDED

#include "TA_Vector.hlsl"

half TA_EvaluateTravelingSineOS(
    float3 positionOS,
    float2 directionXZ,
    half spatialFrequency,
    half speed,
    float timeSeconds,
    half phaseOffset)
{
    float directionLengthSquared = dot(directionXZ, directionXZ);
    float2 normalizedDirectionXZ = directionXZ * rsqrt(max(directionLengthSquared, (float)TA_MIN_DENOMINATOR));
    float sanitizedFrequency = clamp(abs((float)spatialFrequency), 0.0, 32.0);
    float sanitizedSpeed = clamp((float)speed, -16.0, 16.0);
    float phase = dot(positionOS.xz, normalizedDirectionXZ) * sanitizedFrequency
        + timeSeconds * sanitizedSpeed
        + (float)phaseOffset;
    return (half)sin(phase);
}

half TA_EvaluateHeightWeightOS(
    float positionHeightOS,
    float pivotHeightOS,
    float fadeDistanceOS)
{
    float safeFadeDistance = max(abs(fadeDistanceOS), (float)TA_MIN_DENOMINATOR);
    return (half)saturate((positionHeightOS - pivotHeightOS) / safeFadeDistance);
}

float3 TA_ApplyWaveWindAnimationOS(
    float3 positionOS,
    half3 normalOS,
    half waveSignal,
    half waveAmplitude,
    half3 windDirectionOS,
    half windSignal,
    half windAmplitude,
    half windWeight)
{
    half3 waveDirectionOS = TA_SafeNormalize(normalOS);
    half3 normalizedWindDirectionOS = TA_SafeNormalize(windDirectionOS);
    half sanitizedWaveAmplitude = clamp(waveAmplitude, -1.0h, 1.0h);
    half sanitizedWindAmplitude = clamp(windAmplitude, -1.0h, 1.0h);
    half3 waveOffsetOS = waveDirectionOS * waveSignal * sanitizedWaveAmplitude;
    half3 windOffsetOS = normalizedWindDirectionOS
        * windSignal
        * sanitizedWindAmplitude
        * saturate(windWeight);
    return positionOS + (float3)(waveOffsetOS + windOffsetOS);
}

#endif
