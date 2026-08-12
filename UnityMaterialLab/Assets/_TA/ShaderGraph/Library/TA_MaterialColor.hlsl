//UNITY_SHADER_NO_UPGRADE
#ifndef TA_MATERIAL_COLOR_INCLUDED
#define TA_MATERIAL_COLOR_INCLUDED

void TA_AdjustColor_float(
    float3 Color,
    float Saturation,
    float Contrast,
    float Brightness,
    out float3 Out)
{
    float luminance = dot(Color, float3(0.2126, 0.7152, 0.0722));
    float3 saturated = lerp(luminance.xxx, Color, max(Saturation, 0.0));
    float3 contrasted = (saturated - 0.5) * max(Contrast, 0.0) + 0.5;
    Out = max(contrasted * max(Brightness, 0.0), 0.0);
}

void TA_AdjustColor_half(
    half3 Color,
    half Saturation,
    half Contrast,
    half Brightness,
    out half3 Out)
{
    half luminance = dot(Color, half3(0.2126h, 0.7152h, 0.0722h));
    half3 saturated = lerp(luminance.xxx, Color, max(Saturation, 0.0h));
    half3 contrasted = (saturated - 0.5h) * max(Contrast, 0.0h) + 0.5h;
    Out = max(contrasted * max(Brightness, 0.0h), 0.0h);
}

#endif
