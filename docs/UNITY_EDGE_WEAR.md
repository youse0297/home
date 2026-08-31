# Unity 边缘磨损

`TA_EdgeWear.hlsl` 为 Renderer 侧提供轻量、可复用的视角边缘磨损响应。模块使用世界空间法线 `N` 与视线方向 `V` 计算掠射因子 `1 - saturate(N·V)`，再应用阈值和软化区间形成磨损遮罩。

## 约定

- `TA_EvaluateEdgeWear` 对法线和视线做安全归一化；阈值、软化、强度和粗糙度提升均在进入公式前限制到稳定范围。
- `TA_ApplyEdgeWearColor` 将基础色向 `wearColor` 混合并保持 `[0,1]` 输出；`TA_ApplyEdgeWearRoughness` 将粗糙度向 `1` 提升并复用 GGX 的最小粗糙度策略。
- BasePass 只计算一次边缘磨损遮罩，并同时作用于颜色和粗糙度；`edgeWearStrength=0` 时响应为零，不改变原有材质基线。
- `MaterialInputProfile` 负责有限值和范围保护，样例 `MI_LayeredNormal` 显式开启边缘磨损以便观察效果。

## 验收

运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File UnityMaterialLab/Tools/ValidateEdgeWear.ps1
```

脚本固定正视、掠射、阈值中点、部分强度、颜色混合、粗糙度提升/部分响应和输入夹取共 8 组夹具，并验证材质/Profile 接线。报告写入 `UnityMaterialLab/Reports/EdgeWearValidation.json`，契约位于 `UnityMaterialLab/Assets/_TA/Documentation/EdgeWear.json`。

## 边界

当前实现是视角驱动的磨损近似，不读取曲率、烘焙 AO 或 cavity 贴图；若要让磨损驱动其他材质通道或在其他 Shader 中复用，必须显式接入对应消费端。运行时视觉确认仍需要已授权的 Unity Editor。
