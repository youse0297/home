# Unity 多层法线混合原理

本日程项为 Renderer 侧 HLSL 源码库增加切线空间多层法线混合。基础法线作为底层，细节层和宏观层按固定顺序逐层重定向；每层使用独立权重，默认权重为 `0`，因此现有材质保持原有法线输出。

## 原理

`TA_BlendNormalRNMTS` 为每个细节法线建立相对底层法线的稳定正交参考框架，再将细节的切线空间分量重定向到该框架。`TA_ApplyNormalLayerTS` 将重定向结果与底层按 `saturate(weight)` 插值并安全归一化，`TA_ComposeNormalLayersTS` 固定执行：

```text
base → detail → macro
```

该顺序避免直接相加切线向量造成的能量偏差，也保证零权重层是恒等操作。采样、UV 变换和 Unity `UnpackNormalScale` 仍由消费 Shader 负责。

## BasePass 接入

`TA_BasePassLightingDecomposition.shader` 新增 `_DetailNormalMap` / `_MacroNormalMap` 及对应 Scale/Weight 参数。两张可选法线贴图使用独立 UV 变换和采样状态，随后一次调用 `TA_ComposeNormalLayersTS`；组合结果继续经过既有 TBN 转换进入 PBR 光照。

## 验收

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateNormalLayerBlending.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

契约位于 `Assets/_TA/Documentation/NormalLayerBlending.json`，覆盖零层、单层、半权重、组合、权重越界和非单位输入等 7 组固定夹具；报告写入 `Reports/NormalLayerBlendingValidation.json`。当前边界仍是切线空间输入、两层显式绑定，不自动重建几何法线或扩展任意层数。
