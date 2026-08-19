# Unity BasePass 与光照拆解

本日程项在 URP Forward 的 `UniversalForward` BasePass 中提供可切换、可并排比较的表面与光照调试视图。拆解输出保持在线性 HDR 空间，曝光、色调映射和显示编码由 URP 后续阶段处理，避免把显示变换误算进材质或光照分量。

## 固定输入与生成入口

- Shader：`Assets/_TA/Shaders/TA_BasePassLightingDecomposition.shader`
- 材质：`Assets/_TA/Materials/MAT_BasePassLightingDecomposition.mat`
- 场景：`Assets/_TA/BasePass/SCN_BasePassLightingDecomposition.unity`
- 数据契约：`Assets/_TA/Documentation/BasePassLightingDecomposition.json`
- 菜单：`TA/Material Lab/Build BasePass Lighting Decomposition`
- 离线对照板：`Tools/GenerateBasePassLightingBoard.ps1`

场景生成器会创建两行五列的材质球矩阵、固定 HDR 相机、方向主光和环境光。每个材质球通过 `BasePassLightingDebugController` 写入独立的 `MaterialPropertyBlock`，共享一份材质而不产生运行时材质实例。

UV、纹理采样、法线解包、PBR 输入、TBN、BRDF、光照合成和调试输出已由 `Assets/_TA/Shaders/Library/TA_ShaderLibrary.hlsl` 统一提供，BasePass 只保留纹理绑定、配置填写和 URP 光照数据适配。模块依赖见 [Unity HLSL 源码库骨架](UNITY_HLSL_SOURCE_LIBRARY.md)，输入边界见 [Unity 简化 PBR 输入层](UNITY_SIMPLIFIED_PBR_INPUT_LAYER.md)。

## 调试视图

| ID | 视图 | 类别 | 输出含义 |
| ---: | --- | --- | --- |
| 0 | `FinalLit` | Composite | `DirectDiffuse + DirectSpecular + IndirectDiffuse` |
| 1 | `BaseColor` | Surface | sRGB 贴图经 Unity 解码后的线性基础色 |
| 2 | `WorldNormal` | Surface | 世界法线映射到 `[0, 1]` |
| 3 | `AmbientOcclusion` | Surface | ORM.R 与 AO 强度混合后的标量 |
| 4 | `Roughness` | Surface | ORM.G 乘缩放并应用 `0.045` 数值下限 |
| 5 | `Metallic` | Surface | ORM.B 乘缩放并限制到 `[0, 1]` |
| 6 | `DirectDiffuse` | Lighting | Lambert 漫反射、主光颜色、衰减、`N·L` |
| 7 | `DirectSpecular` | Lighting | GGX NDF、Smith 可见性、Schlick Fresnel 与主光 |
| 8 | `IndirectDiffuse` | Lighting | `SampleSH` 环境光、AO、非金属漫反射权重 |
| 9 | `ShadowAttenuation` | Lighting | URP 主光阴影衰减，白为完全受光，黑为完全遮挡 |

`FinalLit` 的固定加法关系是本项的核心验收：最终颜色只能由三个已公开的光照分量相加，调试视图本身不叠加雾、曝光或色调映射。

## 使用方式

1. 使用 Unity `2022.3.62f3c1` 打开 `UnityMaterialLab`。
2. 执行 `TA/Material Lab/Build BasePass Lighting Decomposition`。
3. 打开生成的 `SCN_BasePassLightingDecomposition`；矩阵会同时展示全部十档视图。
4. 若只检查单个模型，将 `BasePassLightingDebugController` 挂到模型根节点并选择 `Debug View`。
5. 捕获 RenderDoc 时使用已有 `RD/Opaque/Boundary` 与 `RD/Lighting/Forward` 书签定位该 `UniversalForward` draw call，检查 `_DebugView`、三张贴图、主光常量和阴影纹理。

## 验收

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\GenerateBasePassLightingBoard.ps1
powershell -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

第一条命令用固定输入解析与 shader 相同的 Lambert/GGX/SH 公式，生成 `Reports/BasePassLightingDecompositionBoard.png` 和数值报告；第二条检查 shader 通道、视图 ID、场景生成入口、控制器、数据契约、加法不变量和报告尺寸。

当前机器若仍被 Unity 许可证阻挡，静态 `PASS` 只能证明源代码、契约与离线公式一致，不能替代 Editor 内的 shader 编译、场景截图或真实 RenderDoc 截帧。不得用对照板冒充运行时截图或 `.rdc`。

## 常见失败点

- 把 ORM 当作 sRGB 采样，导致 AO、粗糙度和金属度失真。
- 在各光照分量内部做曝光或色调映射，导致分量相加无法还原 `FinalLit`。
- 法线贴图转换后没有归一化，导致 `N·L` 与 GGX 高光随插值长度变化。
- 将粗糙度直接当作 GGX 的 alpha；本实现通过 `TA_GGXAlphaFromRoughness` 使用清理后的 `alpha = roughness²`，并在 NDF 分母设置数值下限。
- 用 `renderer.material` 切换视图，意外克隆材质；控制器应使用 `MaterialPropertyBlock`。
