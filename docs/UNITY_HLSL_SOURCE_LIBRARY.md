# Unity HLSL 源码库骨架

本日程项将 Renderer 侧共享 HLSL 从单个 Shader 中拆出，形成可直接包含、依赖方向明确且可静态验收的源码库。首个消费端是 `TA_BasePassLightingDecomposition.shader`；拆分不改变原有 Lambert、GGX、SH 和 10 档调试视图的输出关系。

## 目录与职责

源码库位于 `UnityMaterialLab/Assets/_TA/Shaders/Library`：

| 文件 | 职责 | 直接依赖 |
| --- | --- | --- |
| `TA_ShaderTypes.hlsl` | 表面输入、光照输入与拆解结果结构体 | 无 |
| `TA_Common.hlsl` | 数值常量、粗糙度与标量清理策略 | 无 |
| `TA_Vector.hlsl` | 安全归一化、法线编码、TBN 与空间变换 | Common |
| `TA_Sampling.hlsl` | UV、普通/LOD 采样、法线解包与 ORM 解码 | Unity Core 前置宏 |
| `TA_PBRInput.hlsl` | BaseColor、Normal、ORM 与材质缩放的简化输入组装 | Types、Common、Vector、Sampling |
| `TA_BRDF.hlsl` | Schlick Fresnel、GGX NDF、Smith 可见性 | Common |
| `TA_Lighting.hlsl` | 直接漫反射、直接高光、间接漫反射及最终合成 | Types、Common、Vector、BRDF |
| `TA_DebugViews.hlsl` | 固定 0–9 调试 ID 与输出选择 | Types、Vector |
| `TA_ShaderLibrary.hlsl` | 按依赖顺序聚合全部模块 | 全部模块 |

依赖只能从上层模块指向表中更早的模块。各模块使用 include guard，不直接包含 `Packages/` 下的 Unity/URP 头；引擎数据由消费 Shader 转换为 `TA_LightingInput` 后传入，因此 BRDF 与光照实现不会绑定 `Light` 等 URP 类型。Sampling 模块使用 Unity 跨平台纹理宏，消费 Shader 必须在聚合头之前包含 URP `Core.hlsl`。

## 公共接口

v1.4 固定 27 个公共符号，全部使用 `TA_` 前缀：

- 数据：`TA_SurfaceData`、`TA_LightingInput`、`TA_LightingBreakdown`
- 公共工具：`TA_SanitizePerceptualRoughness`
- 向量：`TA_SafeNormalize`、`TA_EncodeNormalWS`、`TA_BuildBitangentWS`、`TA_BuildTangentToWorld`、`TA_TransformTangentToWorld`
- 采样：`TA_TransformUV`、`TA_SampleTexture2D`、`TA_SampleTexture2DLod`、`TA_SampleNormalTS`、`TA_SampleORM`
- PBR 输入：`TA_PBRInputConfig`、`TA_PBRInputData`、`TA_SamplePBRInput`、`TA_BuildSurfaceData`
- BRDF：`TA_FresnelSchlickScalar`、`TA_FresnelSchlick`、`TA_GGXAlphaFromRoughness`、`TA_DistributionGGXFromAlpha`、`TA_DistributionGGX`、`TA_SmithGGXLambdaTerm`、`TA_VisibilitySmithGGXCorrelated`
- 流程入口：`TA_EvaluateLighting`、`TA_SelectDebugView`

Renderer Shader 应只包含聚合头：

```hlsl
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Library/TA_ShaderLibrary.hlsl"

TA_PBRInputData pbrInput = TA_SamplePBRInput(
    TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap),
    TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap),
    TEXTURE2D_ARGS(_ORMMap, sampler_ORMMap),
    uv,
    pbrConfig);
TA_SurfaceData surface = TA_BuildSurfaceData(pbrInput, normalWS);
TA_LightingBreakdown lighting = TA_EvaluateLighting(surface, lightingInput);
return TA_SelectDebugView(debugView, surface, lighting, shadowAttenuation, alpha);
```

`TA_EvaluateLighting` 保持 `FinalLit = DirectDiffuse + DirectSpecular + IndirectDiffuse`。工具库负责通用采样、解码、PBR 输入组装与空间变换；具体纹理绑定、材质配置和引擎光照数据获取仍由消费 Shader 负责。GGX NDF 先通过 `TA_GGXAlphaFromRoughness` 生成 alpha，再委托给 `TA_DistributionGGXFromAlpha`；几何遮蔽通过显式 `TA_SmithGGXLambdaTerm` 组成相关 Smith 可见性，Fresnel 通过标量/向量 Schlick 入口共享相同的夹取策略。固定数值见 [Unity GGX 法线分布](UNITY_GGX_NORMAL_DISTRIBUTION.md) 和 [Unity 几何遮蔽与 Fresnel](UNITY_GGX_GEOMETRY_FRESNEL.md)。向量与采样接口详见 [Unity 向量与采样工具函数](UNITY_VECTOR_SAMPLING_UTILITIES.md)，输入层详见 [Unity 简化 PBR 输入层](UNITY_SIMPLIFIED_PBR_INPUT_LAYER.md)。

## 与 Shader Graph 函数库的边界

`Assets/_TA/ShaderGraph/Library` 是 Shader Graph Custom Function 的节点级材质预处理库，需要 `_float`/`_half` 精度后缀和节点端口契约。`Assets/_TA/Shaders/Library` 是 Renderer Shader 的源码库，使用结构体和直接返回值，不暴露 Shader Graph 节点入口。两者不能互相包含；确需复用的公式应先明确调用约定，再提升到无引擎依赖的公共模块。

## 验收

在 `UnityMaterialLab` 目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateHlslSourceLibrary.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateVectorSamplingUtilities.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidatePbrInputLayer.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateGgxNormalDistribution.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateGgxGeometryFresnel.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

专项脚本读取 `Assets/_TA/Documentation/HlslSourceLibrary.json`，检查文件存在性、include guard、包依赖隔离、模块依赖顺序、公共前缀和唯一性、聚合顺序、BasePass 接线及最终光照加法不变量，输出 `Reports/HlslSourceLibraryValidation.json`。项目级静态验收会再次检查关键源码和专项报告。

当前机器若被 Unity 许可证阻塞，离线 `PASS` 不等于 Editor shader 编译成功。最终运行验收仍需在 Unity `2022.3.62f3c1` 中打开 BasePass 对照场景，确认 Shader 无编译错误且 10 档视图可切换。
