# Unity 几何遮蔽与 Fresnel

本日程项把 GGX 直接光 BRDF 的几何遮蔽和 Fresnel 从单体光照表达式拆成可复用、可验证的 BRDF 接口。几何项采用相关 Smith GGX，Fresnel 采用 Schlick 五次方近似；两者都在进入公式前统一处理有限范围内的越界输入。

## 几何遮蔽

`TA_SmithGGXLambdaTerm` 计算一个方向的 lambda 子项：

```text
alpha = max(saturate(alpha), 0.002)
a² = alpha²
lambda(N·X, N·Y) = saturate(N·Y) · sqrt(max(((-saturate(N·X) · a²) + saturate(N·X)) · saturate(N·X) + a², 0))
```

相关 Smith 可见性复用两个对称 lambda：

```text
V_Smith = 0.5 / max(lambda(N·V, N·L) + lambda(N·L, N·V), 0.0001)
```

`TA_VisibilitySmithGGXCorrelated` 仍是光照层使用的稳定入口；lambda 子项独立公开后，可以单独检查掠射角、越界余弦和零粗糙度下的数值行为。

## Fresnel

标量入口 `TA_FresnelSchlickScalar` 与 RGB 入口 `TA_FresnelSchlick` 使用相同的 Schlick 近似：

```text
cosine = saturate(cosTheta)
F0 = saturate(reflectanceAtNormal)
F = F0 + (1 - F0) · (1 - cosine)^5
```

这样既保留介电材质 `F0 = 0.04`，也支持金属基础色形成的有色 F0；正视角保持 F0，掠射角趋近 1。F0 和余弦夹取使公共接口与 `TA_Lighting.hlsl` 的饱和输入策略一致。

## 接口

| 接口 | 契约 |
| --- | --- |
| `TA_FresnelSchlickScalar` | 标量 F0 的 Schlick 近似，夹取余弦和 F0 |
| `TA_FresnelSchlick` | RGB F0 的 Schlick 近似，逐通道委托标量策略 |
| `TA_SmithGGXLambdaTerm` | 接收方向余弦与 alpha，输出相关 Smith 的单项 lambda |
| `TA_VisibilitySmithGGXCorrelated` | 由两个 lambda 和最小分母组成最终几何可见性 |

## 验收

在 `UnityMaterialLab` 目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateGgxGeometryFresnel.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateGgxNormalDistribution.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateHlslSourceLibrary.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

专项 manifest 固定介电正视/60°/掠射 Fresnel、F0 夹取、RGB 反射率以及 Smith 对齐、斜视和零粗糙度基准；报告写入 `Reports/GgxGeometryFresnelValidation.json`。离线报告验证源码和数值契约，不替代 Unity Editor 的真实 Shader 编译与运行时画面验收。
