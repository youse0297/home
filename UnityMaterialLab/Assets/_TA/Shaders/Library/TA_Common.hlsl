//UNITY_SHADER_NO_UPGRADE
#ifndef TA_COMMON_INCLUDED
#define TA_COMMON_INCLUDED

#define TA_PI 3.14159265358979323846h
#define TA_INV_PI 0.31830988618379067154h
#define TA_MIN_PERCEPTUAL_ROUGHNESS 0.045h
#define TA_MIN_GGX_ALPHA 0.002h
#define TA_MIN_DENOMINATOR 0.0001h

half TA_SanitizePerceptualRoughness(half roughness)
{
    return max(saturate(roughness), TA_MIN_PERCEPTUAL_ROUGHNESS);
}

#endif
