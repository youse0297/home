//UNITY_SHADER_NO_UPGRADE
#ifndef TA_MATERIAL_UV_INCLUDED
#define TA_MATERIAL_UV_INCLUDED

void TA_TransformUV_float(
    float2 UV,
    float2 Tiling,
    float2 Offset,
    out float2 Out)
{
    Out = UV * Tiling + Offset;
}

void TA_TransformUV_half(
    half2 UV,
    half2 Tiling,
    half2 Offset,
    out half2 Out)
{
    Out = UV * Tiling + Offset;
}

void TA_RotateUV_float(
    float2 UV,
    float2 Center,
    float RotationDegrees,
    out float2 Out)
{
    float angle = radians(RotationDegrees);
    float sine;
    float cosine;
    sincos(angle, sine, cosine);
    float2 centered = UV - Center;
    Out = float2(
        centered.x * cosine - centered.y * sine,
        centered.x * sine + centered.y * cosine) + Center;
}

void TA_RotateUV_half(
    half2 UV,
    half2 Center,
    half RotationDegrees,
    out half2 Out)
{
    half angle = radians(RotationDegrees);
    half sine;
    half cosine;
    sincos(angle, sine, cosine);
    half2 centered = UV - Center;
    Out = half2(
        centered.x * cosine - centered.y * sine,
        centered.x * sine + centered.y * cosine) + Center;
}

#endif
