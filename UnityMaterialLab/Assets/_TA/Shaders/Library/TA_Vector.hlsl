//UNITY_SHADER_NO_UPGRADE
#ifndef TA_VECTOR_INCLUDED
#define TA_VECTOR_INCLUDED

#include "TA_Common.hlsl"

half3 TA_SafeNormalize(half3 value)
{
    half lengthSquared = dot(value, value);
    return value * rsqrt(max(lengthSquared, TA_MIN_DENOMINATOR));
}

half3 TA_EncodeNormalWS(half3 normalWS)
{
    return TA_SafeNormalize(normalWS) * 0.5h + 0.5h;
}

half3 TA_BuildBitangentWS(
    half3 normalWS,
    half3 tangentWS,
    half tangentSign)
{
    return tangentSign * cross(normalWS, tangentWS);
}

half3x3 TA_BuildTangentToWorld(
    half3 normalWS,
    half4 tangentWS)
{
    half3 bitangentWS = TA_BuildBitangentWS(normalWS, tangentWS.xyz, tangentWS.w);
    return half3x3(tangentWS.xyz, bitangentWS, normalWS);
}

half3 TA_TransformTangentToWorld(
    half3 vectorTS,
    half3 normalWS,
    half4 tangentWS)
{
    half3x3 tangentToWorld = TA_BuildTangentToWorld(normalWS, tangentWS);
    return TA_SafeNormalize(mul(vectorTS, tangentToWorld));
}

#endif
