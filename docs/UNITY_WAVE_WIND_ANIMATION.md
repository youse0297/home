# Unity 波浪与风摆动画

本日程项在顶点位移基础上增加可复用、可固定时间回归的程序化动画。BasePass 用同一个行进正弦函数生成波浪和阵风信号：波浪沿对象空间顶点法线起伏，风摆沿对象空间风向移动，并通过高度渐变固定根部。两种振幅默认均为 `0`，已有材质和光照基线不变。

## 动画模型

行进正弦的相位为：

```text
phase = dot(positionOS.xz, normalize(directionXZ)) * clamp(abs(frequency), 0, 32)
      + timeSeconds * clamp(speed, -16, 16)
      + phaseOffset
signal = sin(phase)
```

方向使用安全归一化，零方向会退化为只随时间变化的同步信号。相位和 `_Time.y` 使用 `float`，避免对象坐标及较长运行时间过早丢失精度；最终偏移使用 `half` 参数。

风摆高度权重为：

```text
windWeight = saturate((positionOS.y - pivotHeight) / max(abs(fadeDistance), epsilon))
```

低于 pivot 的顶点固定，向上经过 fadeDistance 后达到完整风摆。使用原始网格高度计算权重，使高度图位移和波浪不会移动锚定边界。

## 材质参数

| 参数 | 范围与默认值 | 作用 |
| --- | --- | --- |
| `_WaveDirection` | `(1,0)` | 波浪在对象空间 XZ 的传播方向 |
| `_WaveAmplitude` | `[-1,1]`，默认 `0` | 沿顶点法线的波浪幅度 |
| `_WaveFrequency` | `[0,32]`，默认 `1` | 波浪空间频率 |
| `_WaveSpeed` | `[-16,16]`，默认 `1` | 波浪时间速度与方向 |
| `_WavePhase` | `[-2π,2π]`，默认 `0` | 波浪相位偏移 |
| `_WindDirection` | `(1,0,0)` | 风摆对象空间偏移方向；XZ 同时决定阵风传播方向 |
| `_WindAmplitude` | `[-1,1]`，默认 `0` | 完整权重处的风摆幅度 |
| `_WindFrequency` | `[0,32]`，默认 `1` | 阵风空间频率 |
| `_WindSpeed` | `[-16,16]`，默认 `1` | 阵风时间速度与方向 |
| `_WindPhase` | `[-2π,2π]`，默认 `0` | 阵风相位偏移 |
| `_WindPivotHeight` | 默认 `0` | 对象空间固定根部高度 |
| `_WindFadeDistance` | `[0.001,10]`，默认 `1` | 从固定根部到完整风摆的高度 |

## 执行顺序

1. 从高度图解码并应用基础法线位移。
2. 以原始对象空间位置和显式时间计算波浪、阵风信号及风摆高度权重。
3. 在已位移位置上加上波浪与风摆偏移。
4. 把动画位置传给 `GetVertexPositionInputs`，生成世界空间和裁剪空间位置。

底层公式位于 `UnityMaterialLab/Assets/_TA/Shaders/Library/TA_VertexAnimation.hlsl`，调用顺序由 `TA_VertexDeformation.hlsl` 统一编排，首个消费端为 `TA_BasePassLightingDecomposition.shader`。机器契约位于 `Assets/_TA/Documentation/WaveWindAnimation.json`，分层边界见 [Unity 顶点位移模块化](UNITY_VERTEX_DISPLACEMENT_MODULARIZATION.md)。

## 验收

在 `UnityMaterialLab` 目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateWaveWindAnimation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

专项回归固定 15 组样例，覆盖零/四分之一相位、方向归一化、时间推进、频率绝对值、速度夹取、高度锚定、波浪/风摆独立与组合偏移、零振幅兼容和振幅夹取。报告写入 `Reports/WaveWindAnimationValidation.json`，并作为阶段 1 必过门禁。

## 当前边界

- 动画仍使用原网格法线与切线，不从动画后的几何重建法线。
- 自定义动画只接入 `UniversalForward`；复用的 URP `ShadowCaster`、`DepthOnly` 和 `DepthNormals` pass 保持静态。
- 相位和风向属于对象空间，不保证多个独立对象之间形成连续的世界空间波场。
- 顶点动画只能移动现有顶点，视觉平滑度取决于网格密度；完整效果仍需 Unity Editor 运行验收。
