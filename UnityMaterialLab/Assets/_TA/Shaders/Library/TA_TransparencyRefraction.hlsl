//UNITY_SHADER_NO_UPGRADE
#ifndef TA_TRANSPARENCY_REFRACTION_INCLUDED
#define TA_TRANSPARENCY_REFRACTION_INCLUDED

#include "TA_Common.hlsl"
#include "TA_Vector.hlsl"
#include "TA_BRDF.hlsl"

struct TA_TransparencyRefractionConfig
{
    half3 absorptionCoefficient;
    half opacity;
    half indexOfRefraction;
    half thickness;
};

struct TA_TransparencyRefractionData
{
    half3 transmittedColor;
    half3 transmittance;
    half fresnel;
    half surfaceWeight;
    half3 color;
};

half TA_DielectricF0FromIOR(half indexOfRefraction)
{
    half sanitizedIor = clamp(indexOfRefraction, 1.0h, 2.5h);
    half ratio = (sanitizedIor - 1.0h) / (sanitizedIor + 1.0h);
    return ratio * ratio;
}

half3 TA_EvaluateRefractionDirectionWS(
    half3 normalWS,
    half3 viewDirectionWS,
    half indexOfRefraction)
{
    half3 normal = TA_SafeNormalize(normalWS);
    half3 incidentDirectionWS = -TA_SafeNormalize(viewDirectionWS);
    half eta = 1.0h / clamp(indexOfRefraction, 1.0h, 2.5h);
    half incidentDotNormal = dot(incidentDirectionWS, normal);
    half radicand = 1.0h - eta * eta *
        (1.0h - incidentDotNormal * incidentDotNormal);
    half3 refractionDirectionWS = eta * incidentDirectionWS -
        (eta * incidentDotNormal + sqrt(max(radicand, 0.0h))) * normal;
    return TA_SafeNormalize(refractionDirectionWS);
}

float2 TA_EvaluateRefractionUV(
    float2 screenUV,
    half3 incidentDirectionVS,
    half3 refractionDirectionVS,
    half refractionStrength,
    half thickness)
{
    half3 incidentVS = TA_SafeNormalize(incidentDirectionVS);
    half3 directionVS = TA_SafeNormalize(refractionDirectionVS);
    half incidentProjectionDepth = max(abs(incidentVS.z), 0.1h);
    half projectionDepth = max(abs(directionVS.z), 0.1h);
    float2 projectedDirectionDelta = (float2)(
        directionVS.xy / projectionDepth -
        incidentVS.xy / incidentProjectionDepth
    );
    float2 offset = projectedDirectionDelta *
        (float)clamp(refractionStrength, 0.0h, 0.1h) *
        (float)clamp(thickness, 0.0h, 10.0h);
    return saturate(screenUV + offset);
}

half3 TA_EvaluateBeerLambertTransmittance(
    half3 absorptionCoefficient,
    half thickness)
{
    half3 coefficient = max(absorptionCoefficient, 0.0h);
    half opticalDepth = clamp(thickness, 0.0h, 10.0h);
    return exp(-coefficient * opticalDepth);
}

TA_TransparencyRefractionData TA_EvaluateTransparencyRefraction(
    half3 opaqueSceneColor,
    half3 surfaceLighting,
    half normalDotView,
    TA_TransparencyRefractionConfig config)
{
    TA_TransparencyRefractionData result;
    result.transmittance = TA_EvaluateBeerLambertTransmittance(
        config.absorptionCoefficient,
        config.thickness
    );
    result.transmittedColor = max(opaqueSceneColor, 0.0h) * result.transmittance;
    result.fresnel = TA_FresnelSchlickScalar(
        saturate(normalDotView),
        TA_DielectricF0FromIOR(config.indexOfRefraction)
    );
    result.surfaceWeight = saturate(config.opacity) +
        (1.0h - saturate(config.opacity)) * result.fresnel;
    result.color = lerp(
        result.transmittedColor,
        max(surfaceLighting, 0.0h),
        result.surfaceWeight
    );
    return result;
}

#endif
