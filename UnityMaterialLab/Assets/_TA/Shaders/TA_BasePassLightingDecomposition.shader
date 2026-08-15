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
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.shadowCoord = GetShadowCoord(positionInputs);
                return output;
            }

            half3 FresnelSchlick(half cosineTheta, half3 reflectanceAtNormal)
            {
                half factor = Pow4(1.0h - cosineTheta) * (1.0h - cosineTheta);
                return reflectanceAtNormal + (1.0h - reflectanceAtNormal) * factor;
            }

            half DistributionGGX(half normalDotHalf, half roughness)
            {
                half alpha = max(roughness * roughness, 0.002h);
                half alphaSquared = alpha * alpha;
                half denominator = normalDotHalf * normalDotHalf * (alphaSquared - 1.0h) + 1.0h;
                return alphaSquared / max(PI * denominator * denominator, 0.0001h);
            }

            half VisibilitySmithGGXCorrelated(
                half normalDotView,
                half normalDotLight,
                half roughness
            )
            {
                half alpha = max(roughness * roughness, 0.002h);
                half alphaSquared = alpha * alpha;
                half viewLambda = normalDotLight * sqrt(
                    max((-normalDotView * alphaSquared + normalDotView) * normalDotView + alphaSquared, 0.0h)
                );
                half lightLambda = normalDotView * sqrt(
                    max((-normalDotLight * alphaSquared + normalDotLight) * normalDotLight + alphaSquared, 0.0h)
                );
                return 0.5h / max(viewLambda + lightLambda, 0.0001h);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 baseColor = saturate(baseSample.rgb * _BaseColor.rgb);
                half4 normalSample = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
                half3 normalTS = UnpackNormalScale(normalSample, _BumpScale);
                half3 bitangentWS = input.tangentWS.w * cross(input.normalWS, input.tangentWS.xyz);
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS);
                half3 normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tangentToWorld));

                half3 orm = saturate(SAMPLE_TEXTURE2D(_ORMMap, sampler_ORMMap, input.uv).rgb);
                half ambientOcclusion = lerp(1.0h, orm.r, saturate(_AOStrength));
                half roughness = max(saturate(orm.g * _RoughnessScale), 0.045h);
                half metallic = saturate(orm.b * _MetallicScale);
                half3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                Light mainLight = GetMainLight(input.shadowCoord);
                half3 lightDirectionWS = normalize(mainLight.direction);
                half3 halfDirectionWS = SafeNormalize(lightDirectionWS + viewDirectionWS);
                half normalDotLight = saturate(dot(normalWS, lightDirectionWS));
                half normalDotView = saturate(dot(normalWS, viewDirectionWS));
                half normalDotHalf = saturate(dot(normalWS, halfDirectionWS));
                half viewDotHalf = saturate(dot(viewDirectionWS, halfDirectionWS));
                half attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                half3 radiance = mainLight.color * attenuation;

                half3 reflectanceAtNormal = lerp(0.04h.xxx, baseColor, metallic);
                half3 fresnel = FresnelSchlick(viewDotHalf, reflectanceAtNormal);
                half distribution = DistributionGGX(normalDotHalf, roughness);
                half visibility = VisibilitySmithGGXCorrelated(
                    normalDotView,
                    normalDotLight,
                    roughness
                );
                half3 directDiffuse = (1.0h - metallic) * baseColor * INV_PI *
                    normalDotLight * radiance;
                half3 directSpecular = distribution * visibility * fresnel *
                    normalDotLight * radiance;
                half3 indirectDiffuse = max(SampleSH(normalWS), 0.0h) *
                    (1.0h - metallic) * baseColor * ambientOcclusion;
                half3 finalLit = directDiffuse + directSpecular + indirectDiffuse;

                if (_DebugView < 0.5h)
                    return half4(finalLit, baseSample.a * _BaseColor.a);
                if (_DebugView < 1.5h)
                    return half4(baseColor, 1.0h);
                if (_DebugView < 2.5h)
                    return half4(normalWS * 0.5h + 0.5h, 1.0h);
                if (_DebugView < 3.5h)
                    return ambientOcclusion.xxxx;
                if (_DebugView < 4.5h)
                    return roughness.xxxx;
                if (_DebugView < 5.5h)
                    return metallic.xxxx;
                if (_DebugView < 6.5h)
                    return half4(directDiffuse, 1.0h);
                if (_DebugView < 7.5h)
                    return half4(directSpecular, 1.0h);
                if (_DebugView < 8.5h)
                    return half4(indirectDiffuse, 1.0h);
                return mainLight.shadowAttenuation.xxxx;
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
