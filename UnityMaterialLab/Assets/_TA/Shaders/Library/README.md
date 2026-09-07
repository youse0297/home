# Renderer HLSL 源码库

本目录提供 Unity URP Renderer Shader 共用的材质、顶点与光照模块。消费 Shader 优先包含 `TA_ShaderLibrary.hlsl`，并通过 `TA_MaterialInterface.hlsl` 交换材质配置、采样结果和光照结果；不要在消费端重新拼装底层 BRDF 流程。

## 使用流程

1. 在顶点阶段构造 `TA_VertexDeformationInput` 和 `TA_VertexDeformationConfig`，调用 `TA_EvaluateVertexDeformationOS` 后再执行对象到世界和裁剪空间变换。
2. 在片元阶段构造 `TA_MaterialConfig`，调用 `TA_SampleMaterial` 获取 `TA_MaterialInputData`。
3. 按需求修改采样结果：依次组合多层法线、程序化遮罩、边缘磨损和积雪。
4. 调用 `TA_ResolveMaterialNormalWS` 取得最终世界空间法线，由 Renderer 获取主光、阴影和 SH。
5. 调用 `TA_EvaluateMaterial`，再从 `TA_MaterialEvaluation.surface`、`lighting` 和 `alpha` 读取输出。

## 模块输入输出

| 模块 | 主要输入 | 主要输出 |
| --- | --- | --- |
| `TA_VertexDeformation` | 对象空间位置/法线、位移高度、显式时间及波浪/风摆参数 | 变形后位置、静态位移量、波浪与风摆偏移 |
| `TA_Sampling` 与 `TA_PBRInput` | BaseColor、Normal、ORM、UV 和缩放参数 | 线性基础色、切线空间法线、AO、粗糙度和金属度 |
| `TA_NormalBlend` | 基础、细节、宏观切线空间法线和权重 | 归一化的 RNM 组合结果 |
| `TA_ProceduralMask` | UV、显式时间、频率、旋转、相位、对比度和强度 | `[0,1]` 遮罩与受遮罩调制的权重 |
| `TA_EdgeWear` | 世界法线、观察方向、阈值、软度、颜色和粗糙度增量 | 磨损遮罩、混合颜色和有界粗糙度 |
| `TA_SnowCover` | 世界法线/位置、覆盖率、高度范围与雪材质参数 | 覆盖遮罩、雪颜色、粗糙度和非金属响应 |
| `TA_Anisotropy` | 世界 TBN、感知粗糙度、各向异性与旋转 | 旋转正交基、方向 alpha、各向异性 GGX 项 |
| `TA_TransparencyRefraction` | IOR、视线/法线、厚度、吸收率、不透明场景色 | 折射 UV、Beer-Lambert 透射、Fresnel 合成色 |
| `TA_Lighting` | `TA_SurfaceData`、视线、主光、衰减和环境辐照度 | 直接漫反射、直接镜面、间接漫反射与最终光照 |
| `TA_MaterialInterface` | 材质配置、纹理、最终法线和 `TA_LightingInput` | 稳定的采样、法线解析和材质评估边界 |
| `TA_DebugViews` | 表面与光照拆解数据、视图 ID | FinalLit 或九种表面/光照调试输出 |

## 示例场景

在 Unity `2022.3.62f3c1` 中执行 `TA/Material Lab/Build Material Showcase`，生成 `Assets/_TA/Scenes/SCN_MaterialShowcase.unity`。同一相机画面包含基础 PBR、多层法线、边缘磨损、积雪、各向异性金属和透明折射六个展台，每个展台使用独立材质并显示模块名称。

场景规范和固定参数见 `Assets/_TA/Documentation/MaterialShowcase.json`，离线参考图为 `Reports/MaterialShowcaseReference.png`。该参考图用于核对布局、输入和输出，不代表 Unity 运行帧；真实截图应另存为 `Assets/_TA/Documentation/MaterialShowcaseRuntime.png`。

## 常见失败点

- BaseColor 必须按 sRGB 导入，Normal 与 ORM 必须按 Linear 导入，ORM 通道固定为 R=AO、G=roughness、B=metallic。
- 切线空间法线必须在组合后重新归一化，并通过带手性符号的 TBN 转到世界空间。
- 材质扩展必须修改 `TA_MaterialInputData` 后再调用 `TA_EvaluateMaterial`，否则表面和光照可能使用不同参数。
- 透明折射依赖 URP Opaque Texture；关闭该开关会使场景色采样无效。
- 顶点变形已接入 UniversalForward，但动画法线重建及 Shadow/Depth 同步仍是后续边界，不能把当前原始图元当成生产变形样例。

## 验收

在 `UnityMaterialLab` 目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateMaterialShowcase.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

专项脚本检查六个展台、独立材质路径、输入/输出、生成器结构、文档和 1600×900 离线参考图，成功标记为 `UNITY_MATERIAL_SHOWCASE: PASS`。
