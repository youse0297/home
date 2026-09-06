# Unity 材质库统一接口

本日程项将 Renderer Shader 对材质源码库的调用收口到一个稳定入口。`TA_BasePassLightingDecomposition.shader` 与 `TA_TransparentRefraction.shader` 不再直接依赖旧的 PBR 输入、表面组装、各向异性和光照函数，而是共同消费 `TA_MaterialInterface.hlsl`。

## 接口契约

统一接口公开三种扁平数据和三个流程函数：

| 接口 | 职责 |
| --- | --- |
| `TA_MaterialConfig` | BaseColor、Normal、AO、Roughness、Metallic 与各向异性参数 |
| `TA_MaterialInputData` | 纹理采样后的可扩展材质数据 |
| `TA_MaterialEvaluation` | 最终 `TA_SurfaceData`、光照拆解和 Alpha |
| `TA_SampleMaterial` | 统一采样 BaseColor、Normal 与 ORM |
| `TA_ResolveMaterialNormalWS` | 将最终切线空间法线转换到世界空间 |
| `TA_EvaluateMaterial` | 固定执行表面组装、各向异性应用和光照评估 |

Renderer 的调用顺序固定为：

1. 用 `TA_SampleMaterial` 得到 `TA_MaterialInputData`。
2. 在评估前应用多层法线、程序化遮罩、边缘磨损、积雪等材质扩展。
3. 用 `TA_ResolveMaterialNormalWS` 解析扩展后的最终法线。
4. 由 Renderer 填充 `TA_LightingInput`，再调用 `TA_EvaluateMaterial`。
5. 从 `TA_MaterialEvaluation.surface`、`lighting` 和 `alpha` 消费结果。

旧的 `TA_PBRInputConfig`、`TA_PBRInputData`、`TA_SamplePBRInput`、`TA_TransformTangentToWorld`、`TA_BuildSurfaceData`、`TA_ApplyAnisotropyToSurface` 与 `TA_EvaluateLighting` 仍作为库内实现保留，但不再是 Renderer 消费端接口。

## 扩展与引擎边界

多层法线、程序化遮罩、边缘磨损和积雪修改 `TA_MaterialInputData`；统一评估随后重建表面数据，保证扩展顺序可见且各消费端一致。积雪覆盖会在评估前衰减各向异性，避免覆盖层继承底材方向性高光。

主光、阴影衰减、SH 环境光、屏幕场景色和时间仍由具体 Renderer Shader 获取。统一接口不包含 URP `Light`、阴影、SH、场景颜色或时间全局，因此可以独立进行数值和结构回归。

## 验收

在 `UnityMaterialLab` 目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateUnifiedMaterialInterface.ps1
```

脚本检查 6 个公共符号、3 个直接依赖、2 个 Renderer 消费端、4 组法线/光照数值基准，以及消费端无旧接口直调。报告写入 `Reports/UnifiedMaterialInterfaceValidation.json`，成功标记为 `UNITY_UNIFIED_MATERIAL_INTERFACE: PASS`。

## 当前边界

- 当前统一 BaseColor、Normal、ORM、各向异性与 Alpha；Clear Coat、Subsurface 等模型尚未纳入。
- Unity 纹理对象不能可靠地存入普通 HLSL 结构，因此纹理与采样器继续作为采样函数参数显式传入。
- 离线验收验证接口结构与既有 PBR 数值等价；Shader 编译和画面检查仍需有效 Unity Editor 许可证。
