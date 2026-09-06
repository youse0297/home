//UNITY_SHADER_NO_UPGRADE
#ifndef TA_ANISOTROPY_INCLUDED
#define TA_ANISOTROPY_INCLUDED

#include "TA_ShaderTypes.hlsl"
#include "TA_Common.hlsl"
#include "TA_Vector.hlsl"
#include "TA_BRDF.hlsl"

struct TA_GGXSpecularTerms
{
    half distribution;
    half visibility;
};

half3 TA_OrthogonalizeTangentWS(half3 normalWS, half3 tangentWS)
{
    half3 normal = TA_SafeNormalize(normalWS);
    if (dot(normal, normal) <= TA_MIN_DENOMINATOR)
    {
        normal = half3(0.0h, 0.0h, 1.0h);
    }

    half3 projectedTangent = tangentWS - normal * dot(normal, tangentWS);
    if (dot(projectedTangent, projectedTangent) > TA_MIN_DENOMINATOR)
    {
        return TA_SafeNormalize(projectedTangent);
    }

    half3 referenceAxis = abs(normal.z) < 0.999h
        ? half3(0.0h, 0.0h, 1.0h)
        : half3(0.0h, 1.0h, 0.0h);
    return TA_SafeNormalize(cross(referenceAxis, normal));
}

void TA_ApplyAnisotropyToSurface(
    inout TA_SurfaceData surface,
    half4 tangentWS,
    half anisotropy,
    half rotationRadians)
{
    half sanitizedAnisotropy = clamp(anisotropy, -0.9h, 0.9h);
    surface.anisotropy = sanitizedAnisotropy;
    if (abs(sanitizedAnisotropy) <= TA_MIN_DENOMINATOR)
    {
        return;
    }

    half3 normal = TA_SafeNormalize(surface.normalWS);
    if (dot(normal, normal) <= TA_MIN_DENOMINATOR)
    {
        normal = half3(0.0h, 0.0h, 1.0h);
    }
    half3 tangent = TA_OrthogonalizeTangentWS(normal, tangentWS.xyz);
    half tangentSign = tangentWS.w < 0.0h ? -1.0h : 1.0h;
    half3 bitangent = tangentSign * TA_SafeNormalize(cross(normal, tangent));
    half rotation = clamp(rotationRadians, -TA_PI, TA_PI);
    half sineRotation;
    half cosineRotation;
    sincos(rotation, sineRotation, cosineRotation);

    surface.normalWS = normal;
    surface.tangentWS = TA_SafeNormalize(
        cosineRotation * tangent + sineRotation * bitangent
    );
    surface.bitangentWS = TA_SafeNormalize(
        -sineRotation * tangent + cosineRotation * bitangent
    );
}

half2 TA_AnisotropicAlphaFromRoughness(half roughness, half anisotropy)
{
    half alpha = TA_GGXAlphaFromRoughness(roughness);
    half sanitizedAnisotropy = clamp(anisotropy, -0.9h, 0.9h);
    half aspect = sqrt(max(1.0h - 0.9h * abs(sanitizedAnisotropy), 0.1h));
    half alphaLong = max(alpha / aspect, TA_MIN_GGX_ALPHA);
    half alphaShort = max(alpha * aspect, TA_MIN_GGX_ALPHA);
    return sanitizedAnisotropy >= 0.0h
        ? half2(alphaLong, alphaShort)
        : half2(alphaShort, alphaLong);
}

half TA_DistributionGGXAnisotropic(
    half normalDotHalf,
    half tangentDotHalf,
    half bitangentDotHalf,
    half2 alphaTB)
{
    half alphaT = max(alphaTB.x, TA_MIN_GGX_ALPHA);
    half alphaB = max(alphaTB.y, TA_MIN_GGX_ALPHA);
    half scaledTangent = tangentDotHalf / alphaT;
    half scaledBitangent = bitangentDotHalf / alphaB;
    half denominatorTerm = scaledTangent * scaledTangent +
        scaledBitangent * scaledBitangent +
        saturate(normalDotHalf) * saturate(normalDotHalf);
    return 1.0h / max(
        TA_PI * alphaT * alphaB * denominatorTerm * denominatorTerm,
        TA_MIN_DENOMINATOR
    );
}

half TA_VisibilitySmithGGXAnisotropic(
    half normalDotView,
    half normalDotLight,
    half tangentDotView,
    half bitangentDotView,
    half tangentDotLight,
    half bitangentDotLight,
    half2 alphaTB)
{
    half normalView = saturate(normalDotView);
    half normalLight = saturate(normalDotLight);
    half alphaT = max(alphaTB.x, TA_MIN_GGX_ALPHA);
    half alphaB = max(alphaTB.y, TA_MIN_GGX_ALPHA);
    half viewLength = length(half3(
        alphaT * tangentDotView,
        alphaB * bitangentDotView,
        normalView
    ));
    half lightLength = length(half3(
        alphaT * tangentDotLight,
        alphaB * bitangentDotLight,
        normalLight
    ));
    half denominator = normalLight * viewLength + normalView * lightLength;
    return 0.5h / max(denominator, TA_MIN_DENOMINATOR);
}

TA_GGXSpecularTerms TA_EvaluateGGXSpecularTerms(
    TA_SurfaceData surface,
    half3 viewDirectionWS,
    half3 lightDirectionWS,
    half3 halfDirectionWS)
{
    half3 normalWS = TA_SafeNormalize(surface.normalWS);
    half normalDotHalf = saturate(dot(normalWS, halfDirectionWS));
    half normalDotView = saturate(dot(normalWS, viewDirectionWS));
    half normalDotLight = saturate(dot(normalWS, lightDirectionWS));
    half roughness = TA_SanitizePerceptualRoughness(surface.roughness);

    TA_GGXSpecularTerms result;
    result.distribution = TA_DistributionGGX(normalDotHalf, roughness);
    result.visibility = TA_VisibilitySmithGGXCorrelated(
        normalDotView,
        normalDotLight,
        roughness
    );
    if (abs(surface.anisotropy) <= TA_MIN_DENOMINATOR)
    {
        return result;
    }

    half tangentDotHalf = dot(surface.tangentWS, halfDirectionWS);
    half bitangentDotHalf = dot(surface.bitangentWS, halfDirectionWS);
    half tangentDotView = dot(surface.tangentWS, viewDirectionWS);
    half bitangentDotView = dot(surface.bitangentWS, viewDirectionWS);
    half tangentDotLight = dot(surface.tangentWS, lightDirectionWS);
    half bitangentDotLight = dot(surface.bitangentWS, lightDirectionWS);
    half2 alphaTB = TA_AnisotropicAlphaFromRoughness(
        roughness,
        surface.anisotropy
    );
    result.distribution = TA_DistributionGGXAnisotropic(
        normalDotHalf,
        tangentDotHalf,
        bitangentDotHalf,
        alphaTB
    );
    result.visibility = TA_VisibilitySmithGGXAnisotropic(
        normalDotView,
        normalDotLight,
        tangentDotView,
        bitangentDotView,
        tangentDotLight,
        bitangentDotLight,
        alphaTB
    );
    return result;
}

#endif
