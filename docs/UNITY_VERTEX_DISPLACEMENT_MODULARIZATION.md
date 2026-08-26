# Unity 顶点位移模块化

本日程项把 BasePass 中手工编排的高度位移、波浪和风摆逻辑收口为 Renderer HLSL 源码库的单一高层入口。重构不改变高度解码、动画公式或默认材质外观；消费 Shader 只负责资源采样与材质参数绑定，效果顺序和诊断结果由 `TA_VertexDeformation.hlsl` 统一管理。

## 模块分层

| 层级 | 文件 | 职责 |
| --- | --- | --- |
| 基础位移 | `TA_VertexDisplacement.hlsl` | 高度中心解码、沿对象空间法线移动位置 |
| 程序动画 | `TA_VertexAnimation.hlsl` | 行进正弦、高度锚定、波浪与风摆偏移 |
| 高层编排 | `TA_VertexDeformation.hlsl` | 结构化输入/配置/结果、固定调用顺序与诊断量 |
| 消费端 | `TA_BasePassLightingDecomposition.shader` | LOD0 高度采样、材质参数绑定、Unity 位置变换 |

高层模块只包含前两层 HLSL，不包含 Unity/URP 包头、纹理宏或 `_Time`。因此公式可以被其他 Renderer Shader 复用，而纹理类型、采样器和时间源仍由消费端决定。

## 公共契约

`TA_VertexDeformationInput` 提供原始 `positionOS`、`normalOS`、已经采样的 `heightSample` 和显式 `timeSeconds`。

`TA_VertexDeformationConfig` 集中保存高度、波浪和风摆参数。字段与 BasePass 材质属性一一对应，但结构本身不依赖 Unity 材质系统。

`TA_VertexDeformationResult` 返回：

- `positionOS`：最终对象空间动画位置。
- `heightDisplacement`：中心化高度位移标量。
- `waveSignal`：波浪正弦信号。
- `windSignal`：风摆正弦信号。
- `windWeight`：根部锚定高度权重。

消费端只调用一次：

```hlsl
TA_VertexDeformationResult deformation = TA_EvaluateVertexDeformationOS(
    deformationInput,
    deformationConfig);
VertexPositionInputs positionInputs = GetVertexPositionInputs(deformation.positionOS);
```

## 固定顺序

1. 解码高度样本并沿原网格法线应用基础位移。
2. 使用原始对象空间位置和显式时间计算波浪、阵风及高度权重。
3. 在高度位移结果上加上波浪与风摆偏移。
4. 返回最终对象空间位置，再由消费端进入 Unity 对象到世界/裁剪变换。

使用原始位置计算相位与锚定，避免高度图或波浪反过来移动风摆根部，也避免不同效果之间形成隐式反馈。

## 验收

在 `UnityMaterialLab` 目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateVertexDisplacementModularization.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

专项回归固定 6 组高层组合，覆盖零振幅、纯高度、纯波浪、根部固定、半权重风摆和三效果组合。门禁还检查两个直接依赖、结构字段、诊断输出、无隐藏纹理/时间全局、固定调用顺序、BasePass 单入口，以及消费端不再直接调用低层函数。报告写入 `Reports/VertexDisplacementModularizationValidation.json`。

## 当前边界

- 模块不负责纹理采样；消费端必须提供高度样本与显式时间。
- 模块不重建动画后的法线或切线。
- Pass 一致性仍由消费 Shader 负责；当前只接入 `UniversalForward`，Shadow/Depth pass 保持静态。
- 对象空间动画和网格密度边界与波浪/风摆基础项保持一致。
