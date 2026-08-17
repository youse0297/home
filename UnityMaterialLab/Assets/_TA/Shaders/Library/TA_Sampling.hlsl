//UNITY_SHADER_NO_UPGRADE
#ifndef TA_SAMPLING_INCLUDED
#define TA_SAMPLING_INCLUDED

float2 TA_TransformUV(float2 uv, float4 scaleOffset)
{
    return uv * scaleOffset.xy + scaleOffset.zw;
}

half4 TA_SampleTexture2D(
    TEXTURE2D_PARAM(textureObject, samplerObject),
    float2 uv)
{
    return SAMPLE_TEXTURE2D(textureObject, samplerObject, uv);
}

half4 TA_SampleTexture2DLod(
    TEXTURE2D_PARAM(textureObject, samplerObject),
    float2 uv,
    float lod)
{
    return SAMPLE_TEXTURE2D_LOD(textureObject, samplerObject, uv, lod);
}

half3 TA_SampleNormalTS(
    TEXTURE2D_PARAM(textureObject, samplerObject),
    float2 uv,
    half normalScale)
{
    half4 packedNormal = TA_SampleTexture2D(
        TEXTURE2D_ARGS(textureObject, samplerObject),
        uv
    );
    return UnpackNormalScale(packedNormal, normalScale);
}

half3 TA_SampleORM(
    TEXTURE2D_PARAM(textureObject, samplerObject),
    float2 uv)
{
    half4 packedOrm = TA_SampleTexture2D(
        TEXTURE2D_ARGS(textureObject, samplerObject),
        uv
    );
    return saturate(packedOrm.rgb);
}

#endif
