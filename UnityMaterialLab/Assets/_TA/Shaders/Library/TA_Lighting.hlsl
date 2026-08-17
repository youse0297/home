//UNITY_SHADER_NO_UPGRADE
#ifndef TA_LIGHTING_INCLUDED
#define TA_LIGHTING_INCLUDED

#include "TA_ShaderTypes.hlsl"
#include "TA_Common.hlsl"
#include "TA_Vector.hlsl"
#include "TA_BRDF.hlsl"

TA_LightingBreakdown TA_EvaluateLighting(
    TA_SurfaceData surface,
    TA_LightingInput lightingInput)
{
    half3 normalWS = TA_SafeNormalize(surface.normalWS);
    half3 viewDirectionWS = TA_SafeNormalize(lightingInput.viewDirectionWS);
    half3 lightDirectionWS = TA_SafeNormalize(lightingInput.lightDirectionWS);
    half3 halfDirectionWS = TA_SafeNormalize(lightDirectionWS + viewDirectionWS);
    half normalDotLight = saturate(dot(normalWS, lightDirectionWS));
    half normalDotView = saturate(dot(normalWS, viewDirectionWS));
    half normalDotHalf = saturate(dot(normalWS, halfDirectionWS));
    half viewDotHalf = saturate(dot(viewDirectionWS, halfDirectionWS));
    half roughness = TA_SanitizePerceptualRoughness(surface.roughness);
    half metallic = saturate(surface.metallic);
    half3 baseColor = saturate(surface.baseColor);
    half3 radiance = max(lightingInput.lightColor, 0.0h) * max(lightingInput.lightAttenuation, 0.0h);

    half3 reflectanceAtNormal = lerp(half3(0.04h, 0.04h, 0.04h), baseColor, metallic);
    half3 fresnel = TA_FresnelSchlick(viewDotHalf, reflectanceAtNormal);
    half distribution = TA_DistributionGGX(normalDotHalf, roughness);
    half visibility = TA_VisibilitySmithGGXCorrelated(
        normalDotView,
        normalDotLight,
        roughness
    );

    TA_LightingBreakdown result;
    result.directDiffuse = (1.0h - metallic) * baseColor * TA_INV_PI *
        normalDotLight * radiance;
    result.directSpecular = distribution * visibility * fresnel *
        normalDotLight * radiance;
    result.indirectDiffuse = max(lightingInput.ambientIrradiance, 0.0h) *
        (1.0h - metallic) * baseColor * saturate(surface.ambientOcclusion);
    result.finalLit = result.directDiffuse + result.directSpecular + result.indirectDiffuse;
    return result;
}

#endif
