Shader "TA/BasePass Lighting Decomposition"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Color", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color Tint", Color) = (1, 1, 1, 1)
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Range(0, 2)) = 1
        [Normal] _DetailNormalMap("Detail Normal Map", 2D) = "bump" {}
        _DetailNormalScale("Detail Normal Scale", Range(0, 2)) = 1
        _DetailNormalWeight("Detail Normal Weight", Range(0, 1)) = 0
        [Normal] _MacroNormalMap("Macro Normal Map", 2D) = "bump" {}
        _MacroNormalScale("Macro Normal Scale", Range(0, 2)) = 1
        _MacroNormalWeight("Macro Normal Weight", Range(0, 1)) = 0
        _ProceduralMaskScale("Procedural Mask Scale", Vector) = (4, 4, 0, 0)
        _ProceduralMaskOffset("Procedural Mask Offset", Vector) = (0, 0, 0, 0)
        _ProceduralMaskRotation("Procedural Mask Rotation", Range(-3.1415927, 3.1415927)) = 0
        _ProceduralMaskTimeScale("Procedural Mask Time Scale", Range(-16, 16)) = 0
        _ProceduralMaskPhase("Procedural Mask Phase", Range(-6.2831853, 6.2831853)) = 0
        _ProceduralMaskContrast("Procedural Mask Contrast", Range(0, 4)) = 1
        _ProceduralMaskStrength("Procedural Mask Strength", Range(0, 1)) = 0
        [HDR] _EdgeWearColor("Edge Wear Color", Color) = (1, 1, 1, 1)
        _EdgeWearThreshold("Edge Wear Threshold", Range(0, 1)) = 0.65
        _EdgeWearSoftness("Edge Wear Softness", Range(0.001, 1)) = 0.2
        _EdgeWearStrength("Edge Wear Strength", Range(0, 1)) = 0
        _EdgeWearRoughnessBoost("Edge Wear Roughness Boost", Range(0, 1)) = 0.25
        [HDR] _SnowColor("Snow Color", Color) = (0.92, 0.96, 1, 1)
        _SnowCoverage("Snow Coverage", Range(0, 1)) = 0
        _SnowNormalThreshold("Snow Normal Threshold", Range(0, 1)) = 0.55
        _SnowNormalSoftness("Snow Normal Softness", Range(0.001, 1)) = 0.2
        _SnowRoughness("Snow Roughness", Range(0.045, 1)) = 0.82
        _SnowHeightBlend("Snow Height Blend", Range(0, 1)) = 0
        _SnowHeightStart("Snow Height Start", Float) = 0
        _SnowHeightFade("Snow Height Fade", Range(0.001, 10)) = 1
        _ORMMap("ORM (R=AO G=Roughness B=Metallic)", 2D) = "white" {}
        _AOStrength("AO Strength", Range(0, 1)) = 1
        _RoughnessScale("Roughness Scale", Range(0, 1)) = 1
        _MetallicScale("Metallic Scale", Range(0, 1)) = 1
        _DisplacementMap("Displacement Height", 2D) = "gray" {}
        _DisplacementAmplitude("Displacement Amplitude", Range(-1, 1)) = 0
        _DisplacementCenter("Displacement Center", Range(0, 1)) = 0.5
        _WaveDirection("Wave Direction XZ", Vector) = (1, 0, 0, 0)
        _WaveAmplitude("Wave Amplitude", Range(-1, 1)) = 0
        _WaveFrequency("Wave Spatial Frequency", Range(0, 32)) = 1
        _WaveSpeed("Wave Speed", Range(-16, 16)) = 1
        _WavePhase("Wave Phase", Range(-6.283185, 6.283185)) = 0
        _WindDirection("Wind Direction OS", Vector) = (1, 0, 0, 0)
        _WindAmplitude("Wind Amplitude", Range(-1, 1)) = 0
        _WindFrequency("Wind Spatial Frequency", Range(0, 32)) = 1
        _WindSpeed("Wind Speed", Range(-16, 16)) = 1
        _WindPhase("Wind Phase", Range(-6.283185, 6.283185)) = 0
        _WindPivotHeight("Wind Pivot Height OS", Float) = 0
        _WindFadeDistance("Wind Height Fade", Range(0.001, 10)) = 1
        [Enum(Final Lit,0,Base Color,1,World Normal,2,Ambient Occlusion,3,Roughness,4,Metallic,5,Direct Diffuse,6,Direct Specular,7,Indirect Diffuse,8,Shadow Attenuation,9)] _DebugView("Debug View", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
        [HideInInspector] _Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5
        [HideInInspector] _Surface("Surface", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "BasePassLightingDecomposition"
            Tags { "LightMode" = "UniversalForward" }
            Cull [_Cull]
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Library/TA_ShaderLibrary.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_DetailNormalMap);
            SAMPLER(sampler_DetailNormalMap);
            TEXTURE2D(_MacroNormalMap);
            SAMPLER(sampler_MacroNormalMap);
            TEXTURE2D(_ORMMap);
            SAMPLER(sampler_ORMMap);
            TEXTURE2D(_DisplacementMap);
            SAMPLER(sampler_DisplacementMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _DetailNormalMap_ST;
                float4 _MacroNormalMap_ST;
                float4 _DisplacementMap_ST;
                float4 _WaveDirection;
                float4 _WindDirection;
                float4 _ProceduralMaskScale;
                float4 _ProceduralMaskOffset;
                half4 _EdgeWearColor;
                half4 _SnowColor;
                half4 _BaseColor;
                half _BumpScale;
                half _DetailNormalScale;
                half _DetailNormalWeight;
                half _MacroNormalScale;
                half _MacroNormalWeight;
                half _ProceduralMaskRotation;
                half _ProceduralMaskTimeScale;
                half _ProceduralMaskPhase;
                half _ProceduralMaskContrast;
                half _ProceduralMaskStrength;
                half _EdgeWearThreshold;
                half _EdgeWearSoftness;
                half _EdgeWearStrength;
                half _EdgeWearRoughnessBoost;
                half _SnowCoverage;
                half _SnowNormalThreshold;
                half _SnowNormalSoftness;
                half _SnowRoughness;
                half _SnowHeightBlend;
                float _SnowHeightStart;
                float _SnowHeightFade;
                half _AOStrength;
                half _RoughnessScale;
                half _MetallicScale;
                half _DisplacementAmplitude;
                half _DisplacementCenter;
                half _WaveAmplitude;
                half _WaveFrequency;
                half _WaveSpeed;
                half _WavePhase;
                half _WindAmplitude;
                half _WindFrequency;
                half _WindSpeed;
                half _WindPhase;
                float _WindPivotHeight;
                float _WindFadeDistance;
                half _DebugView;
                half _Cutoff;
                half _Surface;
                half _Cull;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                half3 normalOS : NORMAL;
                half4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half4 tangentWS : TEXCOORD2;
                float2 uv : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings Vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float2 displacementUV = TA_TransformUV(input.uv, _DisplacementMap_ST);
                half displacementHeight = TA_SampleTexture2DLod(
                    TEXTURE2D_ARGS(_DisplacementMap, sampler_DisplacementMap),
                    displacementUV,
                    0.0
                ).r;

                TA_VertexDeformationInput deformationInput;
                deformationInput.positionOS = input.positionOS.xyz;
                deformationInput.normalOS = input.normalOS;
                deformationInput.heightSample = displacementHeight;
                deformationInput.timeSeconds = _Time.y;

                TA_VertexDeformationConfig deformationConfig;
                deformationConfig.heightAmplitude = _DisplacementAmplitude;
                deformationConfig.heightCenter = _DisplacementCenter;
                deformationConfig.waveDirectionXZ = _WaveDirection.xz;
                deformationConfig.waveAmplitude = _WaveAmplitude;
                deformationConfig.waveFrequency = _WaveFrequency;
                deformationConfig.waveSpeed = _WaveSpeed;
                deformationConfig.wavePhase = _WavePhase;
                deformationConfig.windDirectionOS = (half3)_WindDirection.xyz;
                deformationConfig.windAmplitude = _WindAmplitude;
                deformationConfig.windFrequency = _WindFrequency;
                deformationConfig.windSpeed = _WindSpeed;
                deformationConfig.windPhase = _WindPhase;
                deformationConfig.windPivotHeightOS = _WindPivotHeight;
                deformationConfig.windFadeDistanceOS = _WindFadeDistance;

                TA_VertexDeformationResult deformation = TA_EvaluateVertexDeformationOS(
                    deformationInput,
                    deformationConfig
                );
                VertexPositionInputs positionInputs = GetVertexPositionInputs(deformation.positionOS);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = half4(
                    normalInputs.tangentWS,
                    input.tangentOS.w * GetOddNegativeScale()
                );
                output.uv = TA_TransformUV(input.uv, _BaseMap_ST);
                output.shadowCoord = GetShadowCoord(positionInputs);
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                TA_PBRInputConfig pbrConfig;
                pbrConfig.baseColorTint = _BaseColor;
                pbrConfig.normalScale = _BumpScale;
                pbrConfig.ambientOcclusionStrength = _AOStrength;
                pbrConfig.roughnessScale = _RoughnessScale;
                pbrConfig.metallicScale = _MetallicScale;

                TA_PBRInputData pbrInput = TA_SamplePBRInput(
                    TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap),
                    TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap),
                    TEXTURE2D_ARGS(_ORMMap, sampler_ORMMap),
                    input.uv,
                    pbrConfig
                );
                half3 detailNormalTS = TA_SampleNormalTS(
                    TEXTURE2D_ARGS(_DetailNormalMap, sampler_DetailNormalMap),
                    TA_TransformUV(input.uv, _DetailNormalMap_ST),
                    _DetailNormalScale
                );
                half3 macroNormalTS = TA_SampleNormalTS(
                    TEXTURE2D_ARGS(_MacroNormalMap, sampler_MacroNormalMap),
                    TA_TransformUV(input.uv, _MacroNormalMap_ST),
                    _MacroNormalScale
                );
                TA_ProceduralMaskConfig proceduralMaskConfig;
                proceduralMaskConfig.uvScale = _ProceduralMaskScale.xy;
                proceduralMaskConfig.uvOffset = _ProceduralMaskOffset.xy;
                proceduralMaskConfig.rotationRadians = _ProceduralMaskRotation;
                proceduralMaskConfig.timeScale = _ProceduralMaskTimeScale;
                proceduralMaskConfig.phase = _ProceduralMaskPhase;
                proceduralMaskConfig.contrast = _ProceduralMaskContrast;
                proceduralMaskConfig.strength = _ProceduralMaskStrength;
                half proceduralMask = TA_EvaluateProceduralMask(
                    input.uv,
                    _Time.y,
                    proceduralMaskConfig
                );
                TA_NormalLayerTS detailLayer;
                detailLayer.normalTS = detailNormalTS;
                detailLayer.weight = TA_ApplyProceduralMask(
                    _DetailNormalWeight,
                    proceduralMask
                );
                TA_NormalLayerTS macroLayer;
                macroLayer.normalTS = macroNormalTS;
                macroLayer.weight = TA_ApplyProceduralMask(
                    _MacroNormalWeight,
                    proceduralMask
                );
                pbrInput.normalTS = TA_ComposeNormalLayersTS(
                    pbrInput.normalTS,
                    detailLayer,
                    macroLayer
                );
                half3 normalWS = TA_TransformTangentToWorld(
                    pbrInput.normalTS,
                    input.normalWS,
                    input.tangentWS
                );
                half3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                TA_EdgeWearConfig edgeWearConfig;
                edgeWearConfig.threshold = _EdgeWearThreshold;
                edgeWearConfig.softness = _EdgeWearSoftness;
                edgeWearConfig.strength = _EdgeWearStrength;
                edgeWearConfig.roughnessBoost = _EdgeWearRoughnessBoost;
                edgeWearConfig.wearColor = _EdgeWearColor.rgb;
                half edgeWearMask = TA_EvaluateEdgeWear(
                    normalWS,
                    viewDirectionWS,
                    edgeWearConfig
                );
                pbrInput.baseColor = TA_ApplyEdgeWearColor(
                    pbrInput.baseColor,
                    edgeWearConfig,
                    edgeWearMask
                );
                pbrInput.roughness = TA_ApplyEdgeWearRoughness(
                    pbrInput.roughness,
                    edgeWearConfig,
                    edgeWearMask
                );
                TA_SnowCoverConfig snowConfig;
                snowConfig.snowColor = _SnowColor.rgb;
                snowConfig.coverage = _SnowCoverage;
                snowConfig.normalThreshold = _SnowNormalThreshold;
                snowConfig.normalSoftness = _SnowNormalSoftness;
                snowConfig.snowRoughness = _SnowRoughness;
                snowConfig.heightBlend = _SnowHeightBlend;
                snowConfig.heightStart = _SnowHeightStart;
                snowConfig.heightFade = _SnowHeightFade;
                half snowMask = TA_EvaluateSnowCover(
                    normalWS,
                    input.positionWS,
                    snowConfig
                );
                pbrInput.baseColor = TA_ApplySnowCoverColor(
                    pbrInput.baseColor,
                    snowConfig.snowColor,
                    snowMask
                );
                pbrInput.roughness = TA_ApplySnowCoverRoughness(
                    pbrInput.roughness,
                    snowConfig.snowRoughness,
                    snowMask
                );
                pbrInput.metallic = TA_ApplySnowCoverMetallic(
                    pbrInput.metallic,
                    snowMask
                );
                TA_SurfaceData surface = TA_BuildSurfaceData(pbrInput, normalWS);

                Light mainLight = GetMainLight(input.shadowCoord);
                TA_LightingInput lightingInput;
                lightingInput.viewDirectionWS = viewDirectionWS;
                lightingInput.lightDirectionWS = mainLight.direction;
                lightingInput.lightColor = mainLight.color;
                lightingInput.lightAttenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                lightingInput.ambientIrradiance = max(SampleSH(surface.normalWS), 0.0h);

                TA_LightingBreakdown lighting = TA_EvaluateLighting(surface, lightingInput);
                return TA_SelectDebugView(
                    _DebugView,
                    surface,
                    lighting,
                    mainLight.shadowAttenuation,
                    pbrInput.alpha
                );
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
