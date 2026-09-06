Shader "TA/Transparent Refraction"
{
    Properties
    {
        [MainTexture] _BaseMap("Surface Color", 2D) = "white" {}
        [MainColor] _BaseColor("Surface Tint", Color) = (0.2, 0.65, 0.8, 1)
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Range(0, 2)) = 1
        _ORMMap("ORM (R=AO G=Roughness B=Metallic)", 2D) = "white" {}
        _AOStrength("AO Strength", Range(0, 1)) = 1
        _RoughnessScale("Roughness Scale", Range(0, 1)) = 0.25
        _MetallicScale("Metallic Scale", Range(0, 1)) = 0
        _Opacity("Surface Opacity", Range(0, 1)) = 0.12
        _IndexOfRefraction("Index Of Refraction", Range(1, 2.5)) = 1.5
        _Thickness("Optical Thickness", Range(0, 10)) = 0.6
        [HDR] _AbsorptionCoefficient("Absorption Coefficient", Color) = (0.08, 0.025, 0.01, 1)
        _RefractionStrength("Screen Refraction Strength", Range(0, 0.1)) = 0.025
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "TransparentRefraction"
            Tags { "LightMode" = "UniversalForward" }
            Cull [_Cull]
            Blend One Zero
            ZWrite Off
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
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
                half4 _AbsorptionCoefficient;
                half _BumpScale;
                half _AOStrength;
                half _RoughnessScale;
                half _MetallicScale;
                half _Opacity;
                half _IndexOfRefraction;
                half _Thickness;
                half _RefractionStrength;
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
                half3 normalWS = TA_TransformTangentToWorld(
                    pbrInput.normalTS,
                    input.normalWS,
                    input.tangentWS
                );
                TA_SurfaceData surface = TA_BuildSurfaceData(pbrInput, normalWS);
                half3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

                Light mainLight = GetMainLight(input.shadowCoord);
                TA_LightingInput lightingInput;
                lightingInput.viewDirectionWS = viewDirectionWS;
                lightingInput.lightDirectionWS = mainLight.direction;
                lightingInput.lightColor = mainLight.color;
                lightingInput.lightAttenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                lightingInput.ambientIrradiance = max(SampleSH(surface.normalWS), 0.0h);
                TA_LightingBreakdown lighting = TA_EvaluateLighting(surface, lightingInput);

                half3 refractionDirectionWS = TA_EvaluateRefractionDirectionWS(
                    surface.normalWS,
                    viewDirectionWS,
                    _IndexOfRefraction
                );
                half3 refractionDirectionVS = TransformWorldToViewDir(
                    refractionDirectionWS,
                    true
                );
                half3 incidentDirectionVS = TransformWorldToViewDir(
                    -viewDirectionWS,
                    true
                );
                float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);
                float2 refractionUV = TA_EvaluateRefractionUV(
                    screenUV,
                    incidentDirectionVS,
                    refractionDirectionVS,
                    _RefractionStrength,
                    _Thickness
                );
                half3 opaqueSceneColor = SampleSceneColor(refractionUV);

                TA_TransparencyRefractionConfig refractionConfig;
                refractionConfig.absorptionCoefficient = _AbsorptionCoefficient.rgb;
                refractionConfig.opacity = _Opacity * pbrInput.alpha;
                refractionConfig.indexOfRefraction = _IndexOfRefraction;
                refractionConfig.thickness = _Thickness;
                TA_TransparencyRefractionData refraction = TA_EvaluateTransparencyRefraction(
                    opaqueSceneColor,
                    lighting.finalLit,
                    saturate(dot(surface.normalWS, viewDirectionWS)),
                    refractionConfig
                );
                return half4(refraction.color, 1.0h);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
