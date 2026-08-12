//UNITY_SHADER_NO_UPGRADE
#ifndef TA_MATERIAL_CHANNELS_INCLUDED
#define TA_MATERIAL_CHANNELS_INCLUDED

void TA_UnpackORM_float(
    float4 Packed,
    out float AO,
    out float Roughness,
    out float Metallic)
{
    float3 orm = saturate(Packed.rgb);
    AO = orm.r;
    Roughness = orm.g;
    Metallic = orm.b;
}

void TA_UnpackORM_half(
    half4 Packed,
    out half AO,
    out half Roughness,
    out half Metallic)
{
    half3 orm = saturate(Packed.rgb);
    AO = orm.r;
    Roughness = orm.g;
    Metallic = orm.b;
}

void TA_UnpackRGBA_float(
    float4 Packed,
    out float R,
    out float G,
    out float B,
    out float A)
{
    R = Packed.r;
    G = Packed.g;
    B = Packed.b;
    A = Packed.a;
}

void TA_UnpackRGBA_half(
    half4 Packed,
    out half R,
    out half G,
    out half B,
    out half A)
{
    R = Packed.r;
    G = Packed.g;
    B = Packed.b;
    A = Packed.a;
}

#endif
