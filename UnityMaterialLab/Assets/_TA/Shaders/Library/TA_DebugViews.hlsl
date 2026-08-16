//UNITY_SHADER_NO_UPGRADE
#ifndef TA_DEBUG_VIEWS_INCLUDED
#define TA_DEBUG_VIEWS_INCLUDED

#include "TA_ShaderTypes.hlsl"
#include "TA_Common.hlsl"

#define TA_DEBUG_FINAL_LIT 0.0h
#define TA_DEBUG_BASE_COLOR 1.0h
#define TA_DEBUG_WORLD_NORMAL 2.0h
#define TA_DEBUG_AMBIENT_OCCLUSION 3.0h
#define TA_DEBUG_ROUGHNESS 4.0h
#define TA_DEBUG_METALLIC 5.0h
#define TA_DEBUG_DIRECT_DIFFUSE 6.0h
#define TA_DEBUG_DIRECT_SPECULAR 7.0h
#define TA_DEBUG_INDIRECT_DIFFUSE 8.0h
#define TA_DEBUG_SHADOW_ATTENUATION 9.0h

half4 TA_SelectDebugView(
    half debugView,
    TA_SurfaceData surface,
    TA_LightingBreakdown lighting,
    half shadowAttenuation,
    half alpha)
{
    if (debugView < TA_DEBUG_BASE_COLOR - 0.5h)
        return half4(lighting.finalLit, alpha);
    if (debugView < TA_DEBUG_WORLD_NORMAL - 0.5h)
        return half4(surface.baseColor, 1.0h);
    if (debugView < TA_DEBUG_AMBIENT_OCCLUSION - 0.5h)
        return half4(TA_EncodeNormalWS(surface.normalWS), 1.0h);
    if (debugView < TA_DEBUG_ROUGHNESS - 0.5h)
        return surface.ambientOcclusion.xxxx;
    if (debugView < TA_DEBUG_METALLIC - 0.5h)
        return surface.roughness.xxxx;
    if (debugView < TA_DEBUG_DIRECT_DIFFUSE - 0.5h)
        return surface.metallic.xxxx;
    if (debugView < TA_DEBUG_DIRECT_SPECULAR - 0.5h)
        return half4(lighting.directDiffuse, 1.0h);
    if (debugView < TA_DEBUG_INDIRECT_DIFFUSE - 0.5h)
        return half4(lighting.directSpecular, 1.0h);
    if (debugView < TA_DEBUG_SHADOW_ATTENUATION - 0.5h)
        return half4(lighting.indirectDiffuse, 1.0h);
    return shadowAttenuation.xxxx;
}

#endif
