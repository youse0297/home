//UNITY_SHADER_NO_UPGRADE
#ifndef TA_BRDF_INCLUDED
#define TA_BRDF_INCLUDED

#include "TA_Common.hlsl"

half3 TA_FresnelSchlick(half cosineTheta, half3 reflectanceAtNormal)
{
    half oneMinusCosine = 1.0h - saturate(cosineTheta);
    half factorSquared = oneMinusCosine * oneMinusCosine;
    half factor = factorSquared * factorSquared * oneMinusCosine;
    return reflectanceAtNormal + (1.0h - reflectanceAtNormal) * factor;
}

half TA_DistributionGGX(half normalDotHalf, half roughness)
{
    half alpha = max(roughness * roughness, TA_MIN_GGX_ALPHA);
    half alphaSquared = alpha * alpha;
    half denominator = normalDotHalf * normalDotHalf * (alphaSquared - 1.0h) + 1.0h;
    return alphaSquared / max(TA_PI * denominator * denominator, TA_MIN_DENOMINATOR);
}

half TA_VisibilitySmithGGXCorrelated(
    half normalDotView,
    half normalDotLight,
    half roughness)
{
    half alpha = max(roughness * roughness, TA_MIN_GGX_ALPHA);
    half alphaSquared = alpha * alpha;
    half viewLambda = normalDotLight * sqrt(
        max((-normalDotView * alphaSquared + normalDotView) * normalDotView + alphaSquared, 0.0h)
    );
    half lightLambda = normalDotView * sqrt(
        max((-normalDotLight * alphaSquared + normalDotLight) * normalDotLight + alphaSquared, 0.0h)
    );
    return 0.5h / max(viewLambda + lightLambda, TA_MIN_DENOMINATOR);
}

#endif
