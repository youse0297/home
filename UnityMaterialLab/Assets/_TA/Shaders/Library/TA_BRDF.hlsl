//UNITY_SHADER_NO_UPGRADE
#ifndef TA_BRDF_INCLUDED
#define TA_BRDF_INCLUDED

#include "TA_Common.hlsl"

half TA_FresnelSchlickScalar(half cosineTheta, half reflectanceAtNormal)
{
    half oneMinusCosine = 1.0h - saturate(cosineTheta);
    half reflectance = saturate(reflectanceAtNormal);
    half factorSquared = oneMinusCosine * oneMinusCosine;
    half factor = factorSquared * factorSquared * oneMinusCosine;
    return reflectance + (1.0h - reflectance) * factor;
}

half3 TA_FresnelSchlick(half cosineTheta, half3 reflectanceAtNormal)
{
    return half3(
        TA_FresnelSchlickScalar(cosineTheta, reflectanceAtNormal.r),
        TA_FresnelSchlickScalar(cosineTheta, reflectanceAtNormal.g),
        TA_FresnelSchlickScalar(cosineTheta, reflectanceAtNormal.b)
    );
}

half TA_GGXAlphaFromRoughness(half roughness)
{
    half perceptualRoughness = TA_SanitizePerceptualRoughness(roughness);
    return max(
        perceptualRoughness * perceptualRoughness,
        TA_MIN_GGX_ALPHA
    );
}

half TA_DistributionGGXFromAlpha(half normalDotHalf, half alpha)
{
    half cosine = saturate(normalDotHalf);
    half sanitizedAlpha = max(saturate(alpha), TA_MIN_GGX_ALPHA);
    half alphaSquared = sanitizedAlpha * sanitizedAlpha;
    half denominator = cosine * cosine * (alphaSquared - 1.0h) + 1.0h;
    return alphaSquared / max(
        TA_PI * denominator * denominator,
        TA_MIN_DENOMINATOR
    );
}

half TA_DistributionGGX(half normalDotHalf, half roughness)
{
    return TA_DistributionGGXFromAlpha(
        normalDotHalf,
        TA_GGXAlphaFromRoughness(roughness)
    );
}

half TA_SmithGGXLambdaTerm(
    half normalDotDirection,
    half otherDotDirection,
    half alpha)
{
    half cosine = saturate(normalDotDirection);
    half otherCosine = saturate(otherDotDirection);
    half sanitizedAlpha = max(saturate(alpha), TA_MIN_GGX_ALPHA);
    half alphaSquared = sanitizedAlpha * sanitizedAlpha;
    half radicand = (-cosine * alphaSquared + cosine) * cosine +
        alphaSquared;
    return otherCosine * sqrt(max(radicand, 0.0h));
}

half TA_VisibilitySmithGGXCorrelated(
    half normalDotView,
    half normalDotLight,
    half roughness)
{
    half alpha = TA_GGXAlphaFromRoughness(roughness);
    half viewLambda = TA_SmithGGXLambdaTerm(
        normalDotView,
        normalDotLight,
        alpha
    );
    half lightLambda = TA_SmithGGXLambdaTerm(
        normalDotLight,
        normalDotView,
        alpha
    );
    return 0.5h / max(viewLambda + lightLambda, TA_MIN_DENOMINATOR);
}

#endif
