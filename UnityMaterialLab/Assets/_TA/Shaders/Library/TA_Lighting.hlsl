//UNITY_SHADER_NO_UPGRADE
#ifndef TA_LIGHTING_INCLUDED
#define TA_LIGHTING_INCLUDED

#include "TA_ShaderTypes.hlsl"
#include "TA_Common.hlsl"
#include "TA_Vector.hlsl"
#include "TA_BRDF.hlsl"

TA_DirectLightingBreakdown TA_EvaluateDirectLighting(
    TA_SurfaceData surface,
    TA_LightingInput lightingInput)
{
    half3 normalWS = TA_SafeNormalize(surface.normalWS);
    half3 viewDirectionWS = TA_SafeNormalize(lightingInput.viewDirectionWS);
    half3 lightDirectionWS = TA_SafeNormalize(lightingInput.lightDirectionWS);
    half normalDotLight = saturate(dot(normalWS, lightDirectionWS));
    half normalDotView = saturate(dot(normalWS, viewDirectionWS));

    TA_DirectLightingBreakdown result;
    result.directDiffuse = 0.0h;
    result.directSpecular = 0.0h;
    if (normalDotLight <= 0.0h || normalDotView <= 0.0h)
    {
        return result;
    }

    half3 halfDirectionWS = TA_SafeNormalize(lightDirectionWS + viewDirectionWS);
    half normalDotHalf = saturate(dot(normalWS, halfDirectionWS));
    half viewDotHalf = saturate(dot(viewDirectionWS, halfDirectionWS));
    half roughness = TA_SanitizePerceptualRoughness(surface.roughness);
    half metallic = saturate(surface.metallic);
    half3 baseColor = saturate(surface.baseColor);
    half3 radiance = max(lightingInput.lightColor, 0.0h) *
        max(lightingInput.lightAttenuation, 0.0h);

    half3 reflectanceAtNormal = lerp(half3(0.04h, 0.04h, 0.04h), baseColor, metallic);
    half3 fresnel = TA_FresnelSchlick(viewDotHalf, reflectanceAtNormal);
    half distribution = TA_DistributionGGX(normalDotHalf, roughness);
    half visibility = TA_VisibilitySmithGGXCorrelated(
        normalDotView,
        normalDotLight,
        roughness
    );
    half3 diffuseWeight = (1.0h - metallic) * (1.0h - fresnel);

    result.directDiffuse = diffuseWeight * baseColor * TA_INV_PI *
        normalDotLight * radiance;
    result.directSpecular = distribution * visibility * fresnel *
        normalDotLight * radiance;
    return result;
}

TA_LightingBreakdown TA_EvaluateLighting(
    TA_SurfaceData surface,
    TA_LightingInput lightingInput)
{
    TA_DirectLightingBreakdown directLighting = TA_EvaluateDirectLighting(
        surface,
        lightingInput
    );
    half metallic = saturate(surface.metallic);

    TA_LightingBreakdown result;
    result.directDiffuse = directLighting.directDiffuse;
    result.directSpecular = directLighting.directSpecular;
    result.indirectDiffuse = max(lightingInput.ambientIrradiance, 0.0h) *
        (1.0h - metallic) * saturate(surface.baseColor) *
        saturate(surface.ambientOcclusion);
    result.finalLit = result.directDiffuse + result.directSpecular + result.indirectDiffuse;
    return result;
}

#endif
