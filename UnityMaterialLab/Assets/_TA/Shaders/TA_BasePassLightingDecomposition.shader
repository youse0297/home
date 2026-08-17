Shader "TA/BasePass Lighting Decomposition"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Color", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color Tint", Color) = (1, 1, 1, 1)
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Range(0, 2)) = 1
        _ORMMap("ORM (R=AO G=Roughness B=Metallic)", 2D) = "white" {}
        _AOStrength("AO Strength", Range(0, 1)) = 1
        _RoughnessScale("Roughness Scale", Range(0, 1)) = 1
        _MetallicScale("Metallic Scale", Range(0, 1)) = 1
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
            TEXTURE2D(_ORMMap);
            SAMPLER(sampler_ORMMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _BumpScale;
                half _AOStrength;
                half _RoughnessScale;
                half _MetallicScale;
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

                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
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

                half4 baseSample = TA_SampleTexture2D(
                    TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap),
                    input.uv
                );
                half3 normalTS = TA_SampleNormalTS(
                    TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap),
                    input.uv,
                    _BumpScale
                );
                half3 normalWS = TA_TransformTangentToWorld(
                    normalTS,
                    input.normalWS,
                    input.tangentWS
                );

                half3 orm = TA_SampleORM(
                    TEXTURE2D_ARGS(_ORMMap, sampler_ORMMap),
                    input.uv
                );
                TA_SurfaceData surface;
                surface.baseColor = saturate(baseSample.rgb * _BaseColor.rgb);
                surface.normalWS = normalWS;
                surface.ambientOcclusion = lerp(1.0h, orm.r, saturate(_AOStrength));
                surface.roughness = TA_SanitizePerceptualRoughness(orm.g * _RoughnessScale);
                surface.metallic = saturate(orm.b * _MetallicScale);

                Light mainLight = GetMainLight(input.shadowCoord);
                TA_LightingInput lightingInput;
                lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                lightingInput.lightDirectionWS = mainLight.direction;
                lightingInput.lightColor = mainLight.color;
                lightingInput.lightAttenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                lightingInput.ambientIrradiance = max(SampleSH(normalWS), 0.0h);

                TA_LightingBreakdown lighting = TA_EvaluateLighting(surface, lightingInput);
                return TA_SelectDebugView(
                    _DebugView,
                    surface,
                    lighting,
                    mainLight.shadowAttenuation,
                    baseSample.a * _BaseColor.a
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
