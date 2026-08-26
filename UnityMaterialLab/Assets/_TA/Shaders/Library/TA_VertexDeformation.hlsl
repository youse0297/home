//UNITY_SHADER_NO_UPGRADE
#ifndef TA_VERTEX_DEFORMATION_INCLUDED
#define TA_VERTEX_DEFORMATION_INCLUDED

#include "TA_VertexDisplacement.hlsl"
#include "TA_VertexAnimation.hlsl"

struct TA_VertexDeformationInput
{
    float3 positionOS;
    half3 normalOS;
    half heightSample;
    float timeSeconds;
};

struct TA_VertexDeformationConfig
{
    half heightAmplitude;
    half heightCenter;
    float2 waveDirectionXZ;
    half waveAmplitude;
    half waveFrequency;
    half waveSpeed;
    half wavePhase;
    half3 windDirectionOS;
    half windAmplitude;
    half windFrequency;
    half windSpeed;
    half windPhase;
    float windPivotHeightOS;
    float windFadeDistanceOS;
};

struct TA_VertexDeformationResult
{
    float3 positionOS;
    half heightDisplacement;
    half waveSignal;
    half windSignal;
    half windWeight;
};

TA_VertexDeformationResult TA_EvaluateVertexDeformationOS(
    TA_VertexDeformationInput inputData,
    TA_VertexDeformationConfig config)
{
    TA_VertexDeformationResult result = (TA_VertexDeformationResult)0;
    result.heightDisplacement = TA_DecodeVertexDisplacement(
        inputData.heightSample,
        config.heightAmplitude,
        config.heightCenter
    );
    float3 heightDisplacedPositionOS = TA_ApplyVertexDisplacementOS(
        inputData.positionOS,
        inputData.normalOS,
        result.heightDisplacement
    );

    result.waveSignal = TA_EvaluateTravelingSineOS(
        inputData.positionOS,
        config.waveDirectionXZ,
        config.waveFrequency,
        config.waveSpeed,
        inputData.timeSeconds,
        config.wavePhase
    );
    result.windSignal = TA_EvaluateTravelingSineOS(
        inputData.positionOS,
        config.windDirectionOS.xz,
        config.windFrequency,
        config.windSpeed,
        inputData.timeSeconds,
        config.windPhase
    );
    result.windWeight = TA_EvaluateHeightWeightOS(
        inputData.positionOS.y,
        config.windPivotHeightOS,
        config.windFadeDistanceOS
    );
    result.positionOS = TA_ApplyWaveWindAnimationOS(
        heightDisplacedPositionOS,
        inputData.normalOS,
        result.waveSignal,
        config.waveAmplitude,
        config.windDirectionOS,
        result.windSignal,
        config.windAmplitude,
        result.windWeight
    );
    return result;
}

#endif
