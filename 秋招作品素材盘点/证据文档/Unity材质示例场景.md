# Unity 示例场景与文档

本日程项把已经验收的 Renderer HLSL 模块收口到一个可复现的同场景材质展板，并补齐源码库入口、模块输入输出、固定参数、参考图和检查步骤。示例优先用于功能比较与讲解，不把离线绘制的参考板冒充 Unity 运行截图。

## 交付内容

- Editor 生成器：`UnityMaterialLab/Assets/_TA/Editor/MaterialShowcaseBootstrap.cs`
- 场景：`UnityMaterialLab/Assets/_TA/Scenes/SCN_MaterialShowcase.unity`
- 场景契约：`UnityMaterialLab/Assets/_TA/Documentation/MaterialShowcase.json`
- 源码库入口：`UnityMaterialLab/Assets/_TA/Shaders/Library/README.md`
- 离线参考图：`UnityMaterialLab/Reports/MaterialShowcaseReference.png`
- 专项报告：`UnityMaterialLab/Reports/MaterialShowcaseValidation.json`

场景及六份 `MAT_Showcase_*` 材质由生成器确定性创建，不提交未经过当前 Unity Editor 重建的手写 `.unity` 或 `.mat` 文件。

## 展台设计

| 展台 | 观察目标 | 固定输入 | 输出 |
| --- | --- | --- | --- |
| Base PBR | 统一材质入口与能量守恒光照 | 粗糙度 `0.55`、金属度 `0` | 直接和间接 PBR 合成 |
| Layered Normal | RNM 多层法线与程序遮罩 | Detail `0.65`、Macro `0.35`、Mask `0.75` | 最终世界空间法线 |
| Edge Wear | 掠射角磨损 | Threshold `0.58`、Strength `0.85` | 磨损颜色和粗糙度 |
| Snow Cover | 世界朝上与高度遮罩 | Coverage `0.72`、Height Blend `0.35` | 介电积雪覆盖层 |
| Anisotropic Metal | 旋转切线基中的方向高光 | Metallic `1`、Anisotropy `0.72` | 各向异性 GGX 镜面 |
| Transparent Refraction | 折射、吸收和 Fresnel | IOR `1.5`、Thickness `0.6` | 场景色折射合成 |

## 生成与截图

1. 用 Unity `2022.3.62f3c1` 打开 `UnityMaterialLab`，等待 URP 和 Shader 导入完成。
2. 执行 `TA/Material Lab/Build Material Showcase`。
3. 打开 `SCN_MaterialShowcase`，将 Game View 固定为 `1600×900`。
4. 确认六个展台、标签、暖色主光和蓝色轮廓光均在同一画面。
5. 保存运行截图为 `Assets/_TA/Documentation/MaterialShowcaseRuntime.png`。

当前机器若缺少 Unity `headless` 或 `ui` entitlement，只能完成生成器、契约和离线参考图验收。离线图固定标注 `OFFLINE REFERENCE`，不替代 Shader 编译、场景生成或运行截图。

## 验证

在 `UnityMaterialLab` 目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateMaterialShowcase.ps1
```

成功时输出 `UNITY_MATERIAL_SHOWCASE: PASS`，报告必须满足：六个唯一展台、六个唯一材质路径、每项至少一组输入、每项一个输出、生成器包含固定相机/灯光/Build Settings 接入，参考图为 `1600×900` PNG。

## 分析笔记

1. 同场景比较必须固定相机、主光、环境光和背景，否则材质差异会被拍摄条件掩盖。
2. 展台材质必须相互独立；共享后再修改参数会导致最后一次写入覆盖所有样例。
3. 模块展示需要同时记录输入和可观察输出，仅列函数名不足以复现或排查结果。
4. 离线参考板适合检查布局和契约完整性，但无法证明 URP Shader 已编译，也无法证明场景颜色、阴影和透明排序正确。
5. 顶点变形需要密集网格、变形后法线和辅助 Pass 一致性；当前展板将其保留在文档流程中，而不制造误导性的低模视觉样例。

## 已知边界

- 透明材质需要 URP Opaque Texture；若显示为纯色，先检查 `RP_MaterialLab_URP.asset` 的 Opaque Texture 配置。
- 边缘磨损基于视角掠射项，不等同于曲率烘焙结果；立方体用于放大可观察差异。
- 当前展板不覆盖 Clear Coat、Subsurface、IBL、实时探针或多光源性能对比。
- 运行时截图和 RenderDoc 捕获仍需要本机 Unity 许可证及对应外部工具。
