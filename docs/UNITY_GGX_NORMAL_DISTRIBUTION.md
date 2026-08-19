# Unity GGX 法线分布

本日程项把 Renderer 侧的 GGX 法线分布从光照函数中的内联公式提升为可复用、可验证的 BRDF 接口。`TA_DistributionGGX` 保留粗糙度入口，`TA_DistributionGGXFromAlpha` 接收已经确定的微表面宽度，二者共享 `TA_GGXAlphaFromRoughness` 的输入策略。

## 公式与边界

感知粗糙度 `r` 先执行 `saturate`，再应用 Unity Renderer 的最小感知粗糙度 `0.045`：

```text
r' = max(saturate(r), 0.045)
alpha = max(r'², 0.002)
```

对 `N·H` 先执行 `saturate`，再计算 Trowbridge-Reitz NDF：

```text
a² = alpha²
d = (N·H)²(a² - 1) + 1
D = a² / max(πd², 0.0001)
```

`TA_MIN_GGX_ALPHA` 和 `TA_MIN_DENOMINATOR` 位于 `TA_Common.hlsl`，保证半精度路径在零粗糙度、正视高光和有限越界余弦输入下仍保持有限结果。Smith 相关可见性同样复用 `TA_GGXAlphaFromRoughness`，避免 NDF 与几何项采用不同的 alpha。

## 接口

| 接口 | 契约 |
| --- | --- |
| `TA_GGXAlphaFromRoughness` | 清理感知粗糙度，输出 `[0.002025, 1]` 的 alpha |
| `TA_DistributionGGXFromAlpha` | 饱和 `N·H` 与 alpha，执行 NDF 公式和分母下限 |
| `TA_DistributionGGX` | 将粗糙度入口委托到上述两个接口 |

## 验收

在 `UnityMaterialLab` 目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateGgxNormalDistribution.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateHlslSourceLibrary.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

专项 manifest 固定零/中/最大粗糙度、正视/掠射余弦、余弦饱和、alpha 下限和粗糙度入口委托；报告写入 `Reports/GgxNormalDistributionValidation.json`。这些离线检查证明源码与公式契约一致，不替代 Unity Editor 的真实 Shader 编译和运行时画面验收。
