# Unity 积雪覆盖

`TA_SnowCover.hlsl` 为 Renderer 侧提供轻量、可复用的积雪覆盖响应。模块根据世界空间法线的向上程度生成坡度遮罩，并可选地叠加世界高度渐变。

## 约定

- `TA_EvaluateSnowCover` 对世界法线做安全归一化，以 `dot(N, +Y)` 计算向上程度；`normalThreshold` 和 `normalSoftness` 控制可积雪坡度。
- `heightBlend` 打开后，`positionWS.y` 按 `heightStart/heightFade` 形成高度覆盖；所有覆盖、坡度和高度因子都限制在 `[0,1]`。
- `TA_ApplySnowCoverColor` 将基础色混合到 `snowColor`；`TA_ApplySnowCoverRoughness` 使用统一最小粗糙度策略；`TA_ApplySnowCoverMetallic` 将积雪区域推向介电端 `0`。
- BasePass 只计算一次积雪遮罩并同时驱动颜色、粗糙度和金属度；`snowCoverage=0` 时保持既有材质基线。

## 验收

运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File UnityMaterialLab/Tools/ValidateSnowCover.ps1
```

脚本固定侧向/向上法线、坡度中点、覆盖率、高度全量/部分、颜色、粗糙度、金属度和越界输入共 10 组夹具，并验证材质/Profile 接线。报告写入 `UnityMaterialLab/Reports/SnowCoverValidation.json`，契约位于 `UnityMaterialLab/Assets/_TA/Documentation/SnowCover.json`。

## 边界

当前实现是世界向上与高度驱动的积雪近似，不读取曲率、风向、厚度纹理或融雪温度；其他 Shader 需要显式接入。运行时视觉确认仍需要已授权的 Unity Editor。
