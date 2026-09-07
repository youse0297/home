#define TEXTURE2D_PARAM(textureName, samplerName) Texture2D textureName, SamplerState samplerName
#define TEXTURE2D_ARGS(textureName, samplerName) textureName, samplerName
#define SAMPLE_TEXTURE2D(textureName, samplerName, coordinates) textureName.Sample(samplerName, coordinates)
#define SAMPLE_TEXTURE2D_LOD(textureName, samplerName, coordinates, level) textureName.SampleLevel(samplerName, coordinates, level)

float3 UnpackNormalScale(float4 packedNormal, float scale)
{
    float3 normal = packedNormal.xyz * 2.0 - 1.0;
    normal.xy *= scale;
    return normalize(normal);
}

#include "TA_ShaderLibrary.hlsl"

Texture2D SmokeBaseMap : register(t0);
Texture2D SmokeNormalMap : register(t1);
Texture2D SmokeOrmMap : register(t2);
SamplerState SmokeSampler : register(s0);

float4 PSMain(float4 positionCS : SV_POSITION, float2 uv : TEXCOORD0) : SV_TARGET
{
    TA_VertexDeformationInput deformationInput;
    deformationInput.positionOS = float3(uv, 0.25);
    deformationInput.normalOS = half3(0.0h, 0.0h, 1.0h);
    deformationInput.heightSample = TA_SampleTexture2DLod(
        TEXTURE2D_ARGS(SmokeOrmMap, SmokeSampler),
        uv,
        0.0
    ).g;
    deformationInput.timeSeconds = positionCS.x * 0.01;

    TA_VertexDeformationConfig deformationConfig;
    deformationConfig.heightAmplitude = 0.1h;
    deformationConfig.heightCenter = 0.5h;
    deformationConfig.waveDirectionXZ = float2(1.0, 0.0);
    deformationConfig.waveAmplitude = 0.05h;
    deformationConfig.waveFrequency = 2.0h;
    deformationConfig.waveSpeed = 1.0h;
    deformationConfig.wavePhase = 0.25h;
    deformationConfig.windDirectionOS = half3(1.0h, 0.0h, 0.0h);
    deformationConfig.windAmplitude = 0.04h;
    deformationConfig.windFrequency = 1.5h;
    deformationConfig.windSpeed = 0.8h;
    deformationConfig.windPhase = 0.1h;
    deformationConfig.windPivotHeightOS = 0.0;
    deformationConfig.windFadeDistanceOS = 1.0;
    TA_VertexDeformationResult deformation = TA_EvaluateVertexDeformationOS(
        deformationInput,
        deformationConfig
    );

    TA_MaterialConfig materialConfig;
    materialConfig.baseColorTint = half4(0.8h, 0.5h, 0.25h, 1.0h);
    materialConfig.normalScale = 1.0h;
    materialConfig.ambientOcclusionStrength = 0.9h;
    materialConfig.roughnessScale = 0.8h;
    materialConfig.metallicScale = 0.6h;
    materialConfig.anisotropy = 0.45h;
    materialConfig.anisotropyRotation = 0.3h;
    TA_MaterialInputData materialInput = TA_SampleMaterial(
        TEXTURE2D_ARGS(SmokeBaseMap, SmokeSampler),
        TEXTURE2D_ARGS(SmokeNormalMap, SmokeSampler),
        TEXTURE2D_ARGS(SmokeOrmMap, SmokeSampler),
        TA_TransformUV(uv, float4(1.0, 1.0, 0.0, 0.0)),
        materialConfig
    );

    TA_NormalLayerTS detailLayer;
    detailLayer.normalTS = TA_SampleNormalTS(
        TEXTURE2D_ARGS(SmokeNormalMap, SmokeSampler),
        uv * 4.0,
        0.7h
    );
    detailLayer.weight = 0.6h;
    TA_NormalLayerTS macroLayer;
    macroLayer.normalTS = half3(0.15h, 0.0h, 0.988686h);
    macroLayer.weight = 0.3h;

    TA_ProceduralMaskConfig maskConfig;
    maskConfig.uvScale = float2(4.0, 4.0);
    maskConfig.uvOffset = float2(0.1, 0.2);
    maskConfig.rotationRadians = 0.25;
    maskConfig.timeScale = 0.5;
    maskConfig.phase = 0.1;
    maskConfig.contrast = 1.2h;
    maskConfig.strength = 0.8h;
    half proceduralMask = TA_EvaluateProceduralMask(
        uv,
        deformationInput.timeSeconds,
        maskConfig
    );
    detailLayer.weight = TA_ApplyProceduralMask(detailLayer.weight, proceduralMask);
    materialInput.normalTS = TA_ComposeNormalLayersTS(
        materialInput.normalTS,
        detailLayer,
        macroLayer
    );

    half4 tangentWS = half4(1.0h, 0.0h, 0.0h, 1.0h);
    half3 normalWS = TA_ResolveMaterialNormalWS(
        materialInput,
        half3(0.0h, 0.0h, 1.0h),
        tangentWS
    );
    half3 viewDirectionWS = TA_SafeNormalize(half3(0.2h, 0.1h, 1.0h));

    TA_EdgeWearConfig edgeWearConfig;
    edgeWearConfig.threshold = 0.55h;
    edgeWearConfig.softness = 0.2h;
    edgeWearConfig.strength = 0.7h;
    edgeWearConfig.roughnessBoost = 0.35h;
    edgeWearConfig.wearColor = half3(1.0h, 0.4h, 0.1h);
    half edgeWear = TA_EvaluateEdgeWear(normalWS, viewDirectionWS, edgeWearConfig);
    materialInput.baseColor = TA_ApplyEdgeWearColor(
        materialInput.baseColor,
        edgeWearConfig,
        edgeWear
    );
    materialInput.roughness = TA_ApplyEdgeWearRoughness(
        materialInput.roughness,
        edgeWearConfig,
        edgeWear
    );

    TA_SnowCoverConfig snowConfig;
    snowConfig.snowColor = half3(0.92h, 0.96h, 1.0h);
    snowConfig.coverage = 0.65h;
    snowConfig.normalThreshold = 0.5h;
    snowConfig.normalSoftness = 0.2h;
    snowConfig.snowRoughness = 0.82h;
    snowConfig.heightBlend = 0.3h;
    snowConfig.heightStart = 0.0;
    snowConfig.heightFade = 1.0;
    half snow = TA_EvaluateSnowCover(normalWS, deformation.positionOS, snowConfig);
    materialInput.baseColor = TA_ApplySnowCoverColor(
        materialInput.baseColor,
        snowConfig.snowColor,
        snow
    );
    materialInput.roughness = TA_ApplySnowCoverRoughness(
        materialInput.roughness,
        snowConfig.snowRoughness,
        snow
    );
    materialInput.metallic = TA_ApplySnowCoverMetallic(materialInput.metallic, snow);

    TA_LightingInput lightingInput;
    lightingInput.viewDirectionWS = viewDirectionWS;
    lightingInput.lightDirectionWS = TA_SafeNormalize(half3(0.3h, 0.5h, 0.8h));
    lightingInput.lightColor = half3(3.0h, 2.8h, 2.5h);
    lightingInput.lightAttenuation = 0.8h;
    lightingInput.ambientIrradiance = half3(0.08h, 0.10h, 0.14h);
    TA_MaterialEvaluation material = TA_EvaluateMaterial(
        materialInput,
        normalWS,
        tangentWS,
        lightingInput,
        materialConfig
    );

    half3 refractionDirectionWS = TA_EvaluateRefractionDirectionWS(
        material.surface.normalWS,
        viewDirectionWS,
        1.5h
    );
    float2 refractionUV = TA_EvaluateRefractionUV(
        uv,
        -viewDirectionWS,
        refractionDirectionWS,
        0.025h,
        0.6h
    );
    TA_TransparencyRefractionConfig refractionConfig;
    refractionConfig.absorptionCoefficient = half3(0.08h, 0.025h, 0.01h);
    refractionConfig.opacity = 0.12h;
    refractionConfig.indexOfRefraction = 1.5h;
    refractionConfig.thickness = 0.6h;
    TA_TransparencyRefractionData refraction = TA_EvaluateTransparencyRefraction(
        TA_SampleTexture2D(TEXTURE2D_ARGS(SmokeBaseMap, SmokeSampler), refractionUV).rgb,
        material.lighting.finalLit,
        dot(material.surface.normalWS, viewDirectionWS),
        refractionConfig
    );

    half4 debugOutput = TA_SelectDebugView(
        0.0h,
        material.surface,
        material.lighting,
        lightingInput.lightAttenuation,
        material.alpha
    );
    half diagnostic = deformation.heightDisplacement + deformation.waveSignal +
        deformation.windSignal + deformation.windWeight + edgeWear + snow +
        refraction.fresnel + refraction.surfaceWeight;
    return float4(lerp(debugOutput.rgb, refraction.color, 0.25h) + diagnostic * 0.0001h, 1.0h);
}
