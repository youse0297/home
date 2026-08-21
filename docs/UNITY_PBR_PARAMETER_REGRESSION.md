# Unity PBR 参数回归

本日程项把材质参数边界从“范围/派生公式检查”提升为固定的 PBR 光照输出回归。回归入口位于 `UnityMaterialLab/Tools/ValidatePbrParameterRegression.ps1`，契约位于 `UnityMaterialLab/Assets/_TA/Documentation/PbrParameterRegression.json`，报告写入 `UnityMaterialLab/Reports/PbrParameterRegressionValidation.json`。

## 覆盖范围

- Metallic：`0`、`0.35`、`0.5`、`1`，检查 `(1-metallic)` 漫反射能量单调下降和纯金属零 diffuse。
- Roughness：`0`、`0.25`、`0.5`、`0.75`、`1`，检查清理后的 GGX alpha 单调增加以及零粗糙度下限。
- 越界输入：BaseColor、Metallic、Roughness 同时越界，确认进入光照前完成 clamp/sanitize。
- 法线响应：固定倾斜世界法线，确认 TBN/法线方向改变后直接光输出仍有限且非负。

所有 fixture 使用同一组方向光、视线和 HDR 辐亮度，锁定 `DirectDiffuse` 与 `DirectSpecular` 的线性 HDR 数值，而不是只比较显示截图。回归同时检查 `TA_SamplePBRInput`、`TA_BuildSurfaceData`、`TA_EvaluateDirectLighting` 和 BasePass 的实际接线。

## 验收

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidatePbrParameterRegression.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

阶段 1 总验收将此 validator 作为必选离线门禁。当前矩阵包含 12 个 fixture，固定基准的最大误差应小于 `1e-6`；它与 `MaterialBoundaryMatrix` 互补，后者继续负责 Profile 范围、smoothness、alpha 和 Normal Scale 上限。
