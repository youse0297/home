//UNITY_SHADER_NO_UPGRADE
#ifndef TA_SHADER_TYPES_INCLUDED
#define TA_SHADER_TYPES_INCLUDED

struct TA_SurfaceData
{
    half3 baseColor;
    half3 normalWS;
    half ambientOcclusion;
    half roughness;
    half metallic;
};

struct TA_LightingInput
{
    half3 viewDirectionWS;
    half3 lightDirectionWS;
    half3 lightColor;
    half lightAttenuation;
    half3 ambientIrradiance;
};

struct TA_LightingBreakdown
{
    half3 directDiffuse;
    half3 directSpecular;
    half3 indirectDiffuse;
    half3 finalLit;
};

#endif
