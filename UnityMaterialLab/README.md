# Unity Material Lab

可复用的 Unity URP 资产导入与材质球测试工程，固定使用 `2022.3.62f3c1` 和 URP `14.0.12`。

## 打开与生成

1. 使用 Unity Hub 将本目录作为现有工程加入。
2. 确认 Editor 为 `2022.3.62f3c1`，首次打开等待 Package Manager 和资产导入完成。
3. 执行菜单 `TA/Material Lab/Build Test Scene`，或运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\BuildAndValidate.ps1
```

若本机 Unity 许可证尚未激活，可先运行不启动 Editor 的静态验收：

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

从仓库根目录运行 `Tools/RunStage1Acceptance.ps1` 可同时执行 CPU `12/12`、全部 Unity 离线门禁，并把许可证和 RenderDoc 状态汇总到阶段 1 总报告。

生成场景位于 `Assets/_TA/Scenes/SCN_MaterialImportLab.unity`。基线截图和结构化验收报告位于 `Assets/_TA/Documentation/`。

## 目录与命名

| 目录 | 内容 | 命名前缀 |
| --- | --- | --- |
| `Art/Models` | 原始模型 | `SM_` |
| `Art/Textures` | 原始贴图 | `T_` |
| `Materials` | URP 材质 | `MAT_` |
| `Prefabs` | 可复用对象 | `PF_` |
| `Scenes` | 测试场景 | `SCN_` |
| `Editor` | 构建与验收工具 | 类名表达用途 |
| `Documentation` | 来源、截图、报告 | 描述性命名 |

所有项目资产收敛在 `Assets/_TA`，不把生成缓存或第三方内容放入该目录。

## 导入口径

- 模型单位按 1 Unity Unit = 1 meter；不烘焙轴向；导入源法线，切线使用 MikkTSpace 计算。
- 模型不导入材质、相机、灯光或动画；自动生成第二套 UV，供后续 Lightmap 检查。
- 基础色贴图标记为 sRGB，启用 mipmap、Repeat 和 Bilinear；本阶段保持无压缩，便于观察导入基线。
- 项目使用线性颜色空间、文本序列化和可见 `.meta` 文件，保证版本控制可追踪。

## 输入与输出

- 输入：CC0 OBJ、CC0 PNG、URP Lit 参数、固定相机/灯光。
- 输出：一个材质球 Prefab、一个导入资产 Prefab、一个 PBR 主材质、三个 PBR 材质实例、三个输入 Profile、可复用测试场景、基线截图和 JSON 验收报告。
- 验收：URP 已启用；模型含法线/UV；贴图导入设置正确；场景根节点、Prefab、材质和 Build Settings 完整。

## 材质输入与实例

- `T_CC0_Crate_BaseColor.png` 按 sRGB 导入，作为 BaseColor 输入。
- `T_PBR_Normal.png` 按 Linear/Normal Map 导入，作为切线空间法线输入。
- `T_PBR_ORM.png` 按 Linear/Default 导入，通道固定为 R=AO、G=roughness、B=metallic。
- `MAT_PBR_Master.mat` 是基础 URP Lit 主材质；`MAT_PBR_*.mat` 是三个独立实例，参数由 `MI_PBR_*.asset` Profile 暴露并应用。
- `roughness` 在 URP Lit 中转换为 `smoothness = 1 - roughness`；ORM 的 G/B 保留给后续自定义 PBR 路径。

## 材质参数边界验证

- 固定矩阵包含 Metallic `0/0.5/1`、Roughness `0/0.25/0.5/0.75/1`、Normal Scale `0/1/2`，共 11 个样例。
- `MaterialBoundaryMatrix` 统一计算 `smoothness=1-roughness`、`alpha=max(roughness²,1e-4)` 和介电权重 `1-metallic`。
- `MaterialBoundaryValidator` 生成 11 个边界材质、三行对比场景、1200×720 截图和 JSON 报告。
- 无 Editor 许可证时，`Tools/GenerateBoundaryBoard.ps1` 从同一 JSON 基准生成 `Reports/MaterialBoundaryBoard.png`，`StaticValidate.ps1` 校验全部公式与范围。
- 结论：Metallic 中间值仅作为混合过渡；Normal Scale `2` 为验证上限；零粗糙度使用 GGX 数值下限避免奇异值。

## Shader Graph Custom Function 节点

- `Assets/_TA/ShaderGraph/TA_CustomFunctions.hlsl` 提供 File 模式的 `TA_SanitizeMaterial` 与 `TA_SampleMaterialInputs`，均含 `_float` / `_half` 精度变体。
- `TA_SampleMaterialInputs` 覆盖标量（Metallic/Roughness/NormalScale）、向量（UV）和纹理（BaseColor/Normal/ORM）端口，并以 `UnityTexture2D.tex` + `UnityTexture2D.samplerstate` 采样。
- 在 Unity 菜单执行 `TA/Material Lab/Create Custom Function Example`，生成 `SG_CustomFunctionExample.shadersubgraph`；函数名填 `TA_SampleMaterialInputs`，不要追加精度后缀。
- 端口表、失败点和静态验收见 `../docs/UNITY_SHADER_GRAPH_CUSTOM_FUNCTION.md` 与 `Assets/_TA/Documentation/ShaderGraphCustomFunctionContract.json`。

## 材质函数库

- `Assets/_TA/ShaderGraph/Library/TA_MaterialFunctions.hlsl` 聚合 UV 变换/旋转、法线强度、ORM/RGBA 通道解包与颜色调整共 6 个可复用函数。
- 每个函数都有 `_float` / `_half` 版本；在 Custom Function 的 File 模式填写基础函数名，不填写精度后缀。
- `MaterialFunctionLibraryV1.json` 记录输入/输出契约和 6 组固定数值基准；`MaterialFunctionLibraryExample.json` 可直接作为最小 Shader Graph 节点配方。
- 运行 `Tools/ValidateMaterialFunctionLibrary.ps1` 后，检查 `Reports/MaterialFunctionLibraryValidation.json`；详细接口和失败点见 `../docs/UNITY_MATERIAL_FUNCTION_LIBRARY.md`。

## 贴图压缩

- Standalone 平台按用途压缩：BaseColor=`BC7+sRGB`、Normal=`BC5+Linear/NormalMap`、ORM=`BC1+Linear`，均为质量 `100` 且禁用 Crunch。
- `TextureCompressionPolicy` 由 Bootstrap 执行并在 Editor 验收中校验平台覆盖；ORM 通道保持 `R=AO/G=roughness/B=metallic`。
- `Tools/GenerateTextureCompressionBoard.ps1` 生成 `Reports/TextureCompressionBoard.png`，包含 BC1 实际往返预览/误差、BC1/BC5/BC7 显存对照和用途选择。
- 策略、显存公式和失败点见 `../docs/UNITY_TEXTURE_COMPRESSION.md`；固定数据见 `Assets/_TA/Documentation/TextureCompressionMatrix.json`。

## LOD 基础

- `Assets/_TA/Runtime/LodPolicy.cs` 固定 High/Medium/Low 阈值为 `0.60/0.25/0.05`，并记录 544/144/40 顶点与 1024/256/64 三角形基准。
- 执行菜单 `TA/Material Lab/Build LOD Test Scene` 生成 `Assets/_TA/LOD/PF_LOD_MaterialBall.prefab`、`SCN_LOD_Baseline.unity` 和 `LODValidation.json`；场景包含四个切换样本及 `CrossFade=0.15s`。
- `Tools/GenerateLodBoard.ps1` 生成 `Reports/LODComparisonBoard.png`；阈值、LOD bias 和固定样本由 `Tools/StaticValidate.ps1` 验证。详细规则见 `../docs/UNITY_LOD_BASICS.md`。

## RenderDoc 截帧准备

- 执行菜单 `TA/Material Lab/Prepare RenderDoc Capture` 固定 `1280x720`、关闭 VSync、`30 FPS`、Render Scale `1.0`、MSAA `1x` 和 HDR。
- `RenderDocCaptureFeature` 注入 `RD/Frame/Begin`、Opaque、Lighting、Transparent、PostFX、Frame End 六个 GPU 事件书签。
- 运行 `Tools/RenderDocCaptureCheck.ps1` 检查 RenderDoc/Unity 工具状态；真实文件保存为 `Reports/RenderDoc/MaterialLab_Frame_0001.rdc`。完整步骤见 `../docs/UNITY_RENDERDOC_CAPTURE_PREPARATION.md`。

## BasePass 与光照拆解

- `TA_BasePassLightingDecomposition.shader` 在 URP `UniversalForward` BasePass 中提供 `FinalLit`、BaseColor、WorldNormal、AO、Roughness、Metallic、DirectDiffuse、DirectSpecular、IndirectDiffuse 和 ShadowAttenuation 共 10 档视图。
- `BasePassLightingDebugController` 使用 `MaterialPropertyBlock` 独立切换 Renderer，不复制共享材质；执行菜单 `TA/Material Lab/Build BasePass Lighting Decomposition` 可生成两行五列对照场景。
- `Tools/GenerateBasePassLightingBoard.ps1` 用固定输入验证 Lambert、GGX、SH 与 `FinalLit = DirectDiffuse + DirectSpecular + IndirectDiffuse`，输出 1440×900 对照板和 JSON 报告。
- 输出保持在线性 HDR 空间，不在材质 pass 内重复应用曝光、色调映射或 sRGB 编码。模式表、RenderDoc 检查点和失败边界见 `../docs/UNITY_BASEPASS_LIGHTING_DECOMPOSITION.md`。

## HLSL 源码库

- `Assets/_TA/Shaders/Library/TA_ShaderLibrary.hlsl` 是 Renderer 侧唯一聚合入口，按 Types、Common、Vector、Sampling、PBRInput、BRDF、Lighting、DebugViews 的依赖顺序装配 8 个模块。
- BasePass 通过 `TA_PBRInputConfig`、`TA_SamplePBRInput` 和 `TA_BuildSurfaceData` 组装表面数据，再调用 `TA_EvaluateLighting` 与 `TA_SelectDebugView`；采样、材质边界、GGX 和调试选择不再内联重复。
- `Assets/_TA/ShaderGraph/Library` 继续服务 Shader Graph 节点，不与 Renderer 源码库互相包含。运行 `Tools/ValidateHlslSourceLibrary.ps1` 检查 29 个公共符号；直接光 PBR 由 `Tools/ValidateDirectLightPbrIntegration.ps1` 验证，向量/采样、PBR 输入、GGX NDF 和几何遮蔽/Fresnel 边界分别由对应专项脚本验证。完整约定见 `../docs/UNITY_HLSL_SOURCE_LIBRARY.md`、`../docs/UNITY_DIRECT_LIGHT_PBR_INTEGRATION.md`、`../docs/UNITY_VECTOR_SAMPLING_UTILITIES.md`、`../docs/UNITY_SIMPLIFIED_PBR_INPUT_LAYER.md`、`../docs/UNITY_GGX_NORMAL_DISTRIBUTION.md` 和 `../docs/UNITY_GGX_GEOMETRY_FRESNEL.md`。

## 几何遮蔽与 Fresnel

- `TA_SmithGGXLambdaTerm` 抽出相关 Smith 可见性所需的单项 lambda；`TA_VisibilitySmithGGXCorrelated` 以两个 lambda 和分母下限组成最终遮蔽项。
- `TA_FresnelSchlickScalar` 与 `TA_FresnelSchlick` 共享 Schlick 五次方近似，并统一夹取余弦和 `F0`，覆盖介电与有色金属反射率。
- `Assets/_TA/Documentation/GgxGeometryFresnel.json` 固定正视/60°/掠射 Fresnel、F0 夹取、RGB 反射率及 Smith 对齐/斜视/零粗糙度基准；运行 `Tools/ValidateGgxGeometryFresnel.ps1` 生成 `Reports/GgxGeometryFresnelValidation.json`。

## GGX 法线分布

- `TA_GGXAlphaFromRoughness` 统一执行感知粗糙度清理和 `alpha` 映射；`TA_DistributionGGXFromAlpha` 提供可复用的 Trowbridge-Reitz NDF，`TA_DistributionGGX` 保留粗糙度入口。
- `Assets/_TA/Documentation/GgxNormalDistribution.json` 固定零/中/最大粗糙度、正视/掠射余弦、alpha 下限和入口委托基准；运行 `Tools/ValidateGgxNormalDistribution.ps1` 生成 `Reports/GgxNormalDistributionValidation.json`。
- NDF 使用 `max(saturate(roughness), 0.045)`、`max(alpha, 0.002)` 和 `max(π·denominator², 0.0001)`，避免半精度路径在零粗糙度和正视方向产生奇异值。

## 常见失败点

- 用错误 Editor 打开导致包升级、材质序列化变化或场景重导入。
- FBX/OBJ 单位和轴向未统一，出现 100 倍缩放、倒置或错误枢轴。
- 法线贴图/数据贴图误标为 sRGB，或基础色贴图忘记启用 sRGB。
- 模型自动导入来源材质，造成重复材质、命名污染和不可追踪依赖。
- 把 `Library`、`Temp`、`Logs` 或本机绝对路径提交到版本控制。

## 当前边界

本阶段已建立工程、资产基线、BaseColor/Normal/ORM 输入契约、三个 URP Lit 材质实例、参数边界矩阵、可生成的 Shader Graph Custom Function 子图示例、材质函数库 v1、Standalone 贴图压缩策略与对照基准、三档 LOD 基础策略和切换场景、RenderDoc 截帧准备层、URP Forward BasePass 光照拆解视图，以及包含向量、采样和简化 PBR 输入层的 Renderer HLSL 源码库。完整 Shader Graph 主材质属于后续日程任务。

当前机器的 Editor 自动化若被许可证阻塞，诊断与解锁步骤见 `Reports/EDITOR_VALIDATION_BLOCKED.md`；静态 PASS 不能替代最终 Editor 场景验收。
## Direct-light PBR integration

The renderer-facing HLSL source library is v1.5.0. BasePass direct light is evaluated through `TA_EvaluateDirectLighting`, with `(1-F_Schlick) * (1-metallic)` diffuse energy weighting and GGX/Smith/Fresnel specular composition. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateDirectLightPbrIntegration.ps1` for the dedicated two-fixture check.

## PBR parameter regression

`Tools/ValidatePbrParameterRegression.ps1` locks 12 direct-light fixtures across Metallic, Roughness, out-of-range input sanitization and a tilted normal. It complements the 11-case `MaterialBoundaryMatrix` by comparing linear HDR `DirectDiffuse`/`DirectSpecular` outputs and is included in the Stage 1 required gates.
