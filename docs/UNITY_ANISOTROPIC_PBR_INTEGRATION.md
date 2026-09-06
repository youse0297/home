# Unity 各向异性 PBR 整合

本日程项把已完成的各向异性切线框架、方向粗糙度、GGX 分布和 Smith 可见性收口到直接光 PBR 的统一镜面项入口。基础模块继续负责数学与数据边界，光照模块负责金属度工作流、Schlick Fresnel、能量守恒漫反射、光源辐亮度和最终拆解输出。

## 整合边界

- `TA_GGXSpecularTerms` 保存 GGX `distribution` 与 `visibility`，`TA_EvaluateGGXSpecularTerms` 是光照层唯一消费的镜面项入口。
- `anisotropy=0` 返回既有 `TA_DistributionGGX` 与 `TA_VisibilitySmithGGXCorrelated`，保持历史直接光数值基线。
- 非零值使用旋转后的 T/B 基计算各向异性 D/V；正负强度交换粗糙度轴，旋转 π 后高光响应保持周期一致。
- `TA_EvaluateDirectLighting` 以 `F0=lerp(0.04, BaseColor, Metallic)` 计算 Schlick Fresnel，漫反射仍使用 `(1-F)*(1-Metallic)`，镜面项使用 `D*V*F*NdotL*radiance`。
- BasePass 在光照前应用切线框架和积雪衰减；既有 `DirectSpecular` 调试 ID `7` 直接显示各向异性整合结果，不改变 0–9 调试视图契约。

## 验收

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\ValidateAnisotropicPbrIntegration.ps1
```

专项固定 12 组最终线性 HDR `DirectDiffuse/DirectSpecular`：各向同性参考、正负强度、90°/180° 旋转、介电、纯金属、低/高粗糙度、强度夹取、积雪衰减和背面保护。验证器同时检查统一入口、光照委托、金属度能量分配、BasePass 接线与调试视图。契约位于 `UnityMaterialLab/Assets/_TA/Documentation/AnisotropicPbrIntegration.json`，报告写入 `UnityMaterialLab/Reports/AnisotropicPbrIntegrationValidation.json`。

## 后续边界

当前完成主方向光下的各向异性 PBR 整合以及原有 SH 间接漫反射，尚未实现各向异性环境高光、预过滤 IBL、流向图或毛发方向贴图。平台 Shader 导入、性能和高光外观仍需在已授权 Unity Editor 中补验。
