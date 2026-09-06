# Unity 各向异性基础

本日程项为 Renderer 侧直接光 PBR 增加最小、可复用的各向异性 GGX 路径。`TA_Anisotropy.hlsl` 从最终世界空间法线与网格切线重建正交 T/B/N 基，支持绕法线旋转高光方向，并将单一感知粗糙度拆为切线与副切线两个 GGX alpha。

## 模型约定

- `_Anisotropy` 对材质暴露 `[-1,1]`，内部限制到 `[-0.9,0.9]`，避免端点产生奇异高光；正值沿切线方向展宽，负值交换两个粗糙度轴。
- `_AnisotropyRotation` 使用弧度并限制到 `[-π,π]`，只旋转 T/B 基，不改变最终法线和强度。
- `TA_OrthogonalizeTangentWS` 针对多层法线后的最终法线重新正交化切线，并为平行或退化切线提供稳定轴。
- `TA_DistributionGGXAnisotropic` 使用 `T·H`、`B·H`、`N·H` 和 `alphaT/alphaB`；`TA_VisibilitySmithGGXAnisotropic` 在同一基底计算相关 Smith 可见性。
- `_Anisotropy=0` 时 `TA_EvaluateDirectLighting` 保留原有 `TA_DistributionGGX` 与 `TA_VisibilitySmithGGXCorrelated` 分支，旧材质光照基线不变。
- 积雪使用既有 `snowMask` 衰减底材各向异性；完全覆盖区域表现为各向同性雪层。

示例 `MAT_LayeredNormal` 与 `MI_LayeredNormal` 使用 `anisotropy=0.65`、`rotation=0.35`，用于在现有多层法线、边缘磨损和积雪材质上观察拉伸高光。

## 验收

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\ValidateAnisotropyBasics.ps1
```

脚本固定零值 alpha、正负轴交换、输入夹取、法线正对与两个切向 GGX 分布、各向异性 Smith 可见性、退化切线以及旋转/手性共 10 组数值夹具；同时检查表面数据、光照分支、BasePass 和样例材质/Profile 接线。报告写入 `UnityMaterialLab/Reports/AnisotropyBasicsValidation.json`，契约位于 `UnityMaterialLab/Assets/_TA/Documentation/AnisotropyBasics.json`。

## 边界

当前方向来自网格切线和标量旋转，不读取流向图、毛发方向图或拉丝纹理。离线验收固定公式与接线；最终平台 Shader 编译和高光外观仍需在已授权的 Unity Editor 中确认。
