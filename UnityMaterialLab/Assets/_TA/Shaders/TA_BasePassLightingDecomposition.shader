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
                half4 _BaseColor;
                half _BumpScale;
                half _DetailNormalScale;
                half _DetailNormalWeight;
                half _MacroNormalScale;
                half _MacroNormalWeight;
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
                TA_NormalLayerTS detailLayer;
                detailLayer.normalTS = detailNormalTS;
                detailLayer.weight = _DetailNormalWeight;
                TA_NormalLayerTS macroLayer;
                macroLayer.normalTS = macroNormalTS;
                macroLayer.weight = _MacroNormalWeight;
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
                TA_SurfaceData surface = TA_BuildSurfaceData(pbrInput, normalWS);

                Light mainLight = GetMainLight(input.shadowCoord);
                TA_LightingInput lightingInput;
                lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
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
