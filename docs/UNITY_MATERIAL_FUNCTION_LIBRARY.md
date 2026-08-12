# Unity 材质函数库 v1

## 目标与结构

材质函数库将可复用、无状态的 Shader Graph File 模式函数从业务节点中拆出。入口文件是
`UnityMaterialLab/Assets/_TA/ShaderGraph/Library/TA_MaterialFunctions.hlsl`；它聚合以下四个
模块，所有公开函数都提供 `_float` 和 `_half` 变体。

| 模块 | 函数 | 输入 | 输出 | 约束 |
| --- | --- | --- | --- | --- |
| UV | `TA_TransformUV` | UV、Tiling、Offset | UV | `UV * Tiling + Offset` |
| UV | `TA_RotateUV` | UV、Center、RotationDegrees | UV | 围绕 Center 逆时针旋转 |
| Normal | `TA_NormalStrength` | NormalTS、Strength | NormalTS | Strength 钳制到 `[0,2]`，零向量回退 `(0,0,1)` |
| Channels | `TA_UnpackORM` | Packed RGBA | AO、Roughness、Metallic | `R/G/B` 解包并钳制到 `[0,1]` |
| Channels | `TA_UnpackRGBA` | Packed RGBA | R、G、B、A | 保持原始通道数值 |
| Color | `TA_AdjustColor` | Color、Saturation、Contrast、Brightness | Color | 在线性空间执行，负增益归零 |

## Shader Graph 接入

创建一个 Custom Function 节点并选择 **File**：

1. 在 Name 填函数基础名，例如 `TA_NormalStrength`，不要填写 `_float` 或 `_half`。
2. 在 Source 中选择对应模块；需要统一入口时选择 `TA_MaterialFunctions.hlsl`。
3. 在 Graph Inspector 中按上表建立同顺序的输入/输出端口。
4. 先使用 `MaterialFunctionLibraryExample.json` 中的固定输入值，确认输出一致，再接入材质图。

最小组合是 `TA_TransformUV -> 纹理采样 -> TA_UnpackORM`，另将法线采样结果传给
`TA_NormalStrength`，基础色的线性结果传给 `TA_AdjustColor`。现有
`TA_SampleMaterialInputs` 已复用 `TA_NormalStrength` 与 `TA_UnpackORM`。

## 常见失败点

- Function Name 手工添加 `_float` 或 `_half`，导致 Shader Graph 再次追加精度后缀。
- `TA_UnpackORM` 的 R/G/B 顺序被误接为 metallic/roughness/AO；本工程固定 R=AO、G=roughness、B=metallic。
- 法线强度只缩放 XY 却不重新归一化，导致光照强度失真。
- 在 sRGB 空间做饱和度、对比度或亮度调整；颜色函数的输入必须是线性颜色。
- 将 `TA_RotateUV` 的角度当作弧度传入；接口明确使用角度。

## 验收

```powershell
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\ValidateMaterialFunctionLibrary.ps1
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\StaticValidate.ps1
```

第一个命令验证 6 个固定数值基准，输出
`UnityMaterialLab/Reports/MaterialFunctionLibraryValidation.json`；第二个命令确认模块、聚合入口、
精度变体、端口类别和示例清单完整。
