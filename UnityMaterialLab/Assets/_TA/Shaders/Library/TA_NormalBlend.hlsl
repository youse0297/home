//UNITY_SHADER_NO_UPGRADE
#ifndef TA_NORMAL_BLEND_INCLUDED
#define TA_NORMAL_BLEND_INCLUDED

#include "TA_Vector.hlsl"

struct TA_NormalLayerTS
{
    half3 normalTS;
    half weight;
};

half3 TA_BlendNormalRNMTS(
    half3 baseNormalTS,
    half3 detailNormalTS)
{
    half3 base = TA_SafeNormalize(baseNormalTS);
    half3 detail = TA_SafeNormalize(detailNormalTS);
    half3 reference = abs(base.z) < 0.999h
        ? half3(0.0h, 0.0h, 1.0h)
        : half3(0.0h, 1.0h, 0.0h);
    half3 tangent = TA_SafeNormalize(cross(reference, base));
    half3 bitangent = cross(base, tangent);
    return TA_SafeNormalize(
        tangent * detail.x + bitangent * detail.y + base * detail.z
    );
}

half3 TA_ApplyNormalLayerTS(
    half3 baseNormalTS,
    TA_NormalLayerTS layer)
{
    half weight = saturate(layer.weight);
    half3 blended = TA_BlendNormalRNMTS(baseNormalTS, layer.normalTS);
    return TA_SafeNormalize(lerp(
        TA_SafeNormalize(baseNormalTS),
        blended,
        weight
    ));
}

half3 TA_ComposeNormalLayersTS(
    half3 baseNormalTS,
    TA_NormalLayerTS detailLayer,
    TA_NormalLayerTS macroLayer)
{
    half3 result = TA_ApplyNormalLayerTS(baseNormalTS, detailLayer);
    return TA_ApplyNormalLayerTS(result, macroLayer);
}

#endif
