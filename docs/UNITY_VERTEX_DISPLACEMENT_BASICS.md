# Unity 顶点位移基础

本日程项为 Renderer HLSL 源码库补充最小、可复用的顶点位移路径。BasePass 顶点着色器在对象空间读取高度、解码有符号位移，并在 Unity 的对象到世界/裁剪变换之前沿对象空间顶点法线修改位置。默认振幅为 `0`，已有材质和光照回归不发生外观变化。

## 输入契约

| 属性 | 范围与默认值 | 含义 |
| --- | --- | --- |
| `_DisplacementMap` | 默认灰色纹理 | 顶点阶段读取 R 通道高度 |
| `_DisplacementAmplitude` | `[-1, 1]`，默认 `0` | 对象空间最大位移尺度；负值反转方向 |
| `_DisplacementCenter` | `[0, 1]`，默认 `0.5` | 解码为零位移的高度中心 |

位移标量固定为：

```text
displacement = (saturate(height) - saturate(center)) * clamp(amplitude, -1, 1)
```

顶点纹理没有隐式导数，因此消费端通过 `TA_SampleTexture2DLod(..., 0.0)` 显式读取 LOD0。高度图 UV 使用独立的 `_DisplacementMap_ST`，与 BaseColor、Normal、ORM 的 UV 变换互不覆盖。

## 空间与执行顺序

`TA_DecodeVertexDisplacement` 负责有界高度解码；`TA_ApplyVertexDisplacementOS` 使用 `TA_SafeNormalize(normalOS)`，执行 `positionOS + normalOS * displacement`。BasePass 的固定顺序如下：

1. 变换高度图 UV 并在顶点阶段读取 LOD0。
2. 解码中心化位移标量。
3. 沿归一化对象空间顶点法线修改 `positionOS`。
4. 把新位置传给 `GetVertexPositionInputs`，再生成世界空间与裁剪空间位置。

若启用程序化动画，波浪与风摆会在基础高度位移之后、`GetVertexPositionInputs` 之前以加法偏移叠加；详见 [Unity 波浪与风摆动画](UNITY_WAVE_WIND_ANIMATION.md)。

零法线通过安全归一化产生零方向，不会把非有限值写入顶点位置；零振幅无条件保留原始位置。

## 接入文件

- 共享模块：`UnityMaterialLab/Assets/_TA/Shaders/Library/TA_VertexDisplacement.hlsl`
- 高层编排：`UnityMaterialLab/Assets/_TA/Shaders/Library/TA_VertexDeformation.hlsl`
- 聚合入口：`UnityMaterialLab/Assets/_TA/Shaders/Library/TA_ShaderLibrary.hlsl`
- 首个消费端：`UnityMaterialLab/Assets/_TA/Shaders/TA_BasePassLightingDecomposition.shader`
- 机器契约：`UnityMaterialLab/Assets/_TA/Documentation/VertexDisplacementBasics.json`

## 验收

在 `UnityMaterialLab` 目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateVertexDisplacementBasics.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

专项回归固定 8 组样例，覆盖中心值、正负高度、负振幅、输入夹取、非单位/反向/零法线，并检查公共接口、LOD0、零振幅默认值以及位移早于对象变换。结果写入 `Reports/VertexDisplacementBasicsValidation.json`，同时作为阶段 1 必过门禁。

基础公式由 `TA_VertexDisplacement.hlsl` 保持独立，高度、波浪和风摆的调用顺序已提升到 [Unity 顶点位移模块化](UNITY_VERTEX_DISPLACEMENT_MODULARIZATION.md) 的高层入口。

## 当前边界

- 本基础项不从位移后的几何重建法线；光照仍使用原网格顶点法线与法线贴图。
- 自定义位移目前只接入 `UniversalForward`。Shader 复用的 URP `ShadowCaster`、`DepthOnly` 和 `DepthNormals` pass 仍使用未位移网格，因此非零振幅不保证阴影和深度轮廓一致。
- 完整运行验收仍需有效 Unity Editor 许可证，以确认目标平台的 Shader 编译和实际网格密度下的视觉结果。
