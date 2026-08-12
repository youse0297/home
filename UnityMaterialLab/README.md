# Unity Material Lab

可复用的 Unity URP 资产导入与材质球测试工程，固定使用 `2022.3.62f3c1` 和 URP `14.0.12`。

## 打开与生成

1. 使用 Unity Hub 将本目录作为现有工程加入。
2. 确认 Editor 为 `2022.3.62f3c1`，首次打开等待 Package Manager 和资产导入完成。
3. 执行菜单 `TA/Material Lab/Build Test Scene`，或运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\BuildAndValidate.ps1
```

若本机 Unity 许可证尚未激活，可先运行不启动 Editor 的静态验收：

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

生成场景位于 `Assets/_TA/Scenes/SCN_MaterialImportLab.unity`。基线截图和结构化验收报告位于 `Assets/_TA/Documentation/`。

## 目录与命名

| 目录 | 内容 | 命名前缀 |
| --- | --- | --- |
| `Art/Models` | 原始模型 | `SM_` |
| `Art/Textures` | 原始贴图 | `T_` |
| `Materials` | URP 材质 | `MAT_` |
| `Prefabs` | 可复用对象 | `PF_` |
| `Scenes` | 测试场景 | `SCN_` |
| `Editor` | 构建与验收工具 | 类名表达用途 |
| `Documentation` | 来源、截图、报告 | 描述性命名 |

所有项目资产收敛在 `Assets/_TA`，不把生成缓存或第三方内容放入该目录。

## 导入口径

- 模型单位按 1 Unity Unit = 1 meter；不烘焙轴向；导入源法线，切线使用 MikkTSpace 计算。
- 模型不导入材质、相机、灯光或动画；自动生成第二套 UV，供后续 Lightmap 检查。
- 基础色贴图标记为 sRGB，启用 mipmap、Repeat 和 Bilinear；本阶段保持无压缩，便于观察导入基线。
- 项目使用线性颜色空间、文本序列化和可见 `.meta` 文件，保证版本控制可追踪。

## 输入与输出

- 输入：CC0 OBJ、CC0 PNG、URP Lit 参数、固定相机/灯光。
- 输出：一个材质球 Prefab、一个导入资产 Prefab、一个 PBR 主材质、三个 PBR 材质实例、三个输入 Profile、可复用测试场景、基线截图和 JSON 验收报告。
- 验收：URP 已启用；模型含法线/UV；贴图导入设置正确；场景根节点、Prefab、材质和 Build Settings 完整。

## 材质输入与实例

- `T_CC0_Crate_BaseColor.png` 按 sRGB 导入，作为 BaseColor 输入。
- `T_PBR_Normal.png` 按 Linear/Normal Map 导入，作为切线空间法线输入。
- `T_PBR_ORM.png` 按 Linear/Default 导入，通道固定为 R=AO、G=roughness、B=metallic。
- `MAT_PBR_Master.mat` 是基础 URP Lit 主材质；`MAT_PBR_*.mat` 是三个独立实例，参数由 `MI_PBR_*.asset` Profile 暴露并应用。
- `roughness` 在 URP Lit 中转换为 `smoothness = 1 - roughness`；ORM 的 G/B 保留给后续自定义 PBR 路径。

## 材质参数边界验证

- 固定矩阵包含 Metallic `0/0.5/1`、Roughness `0/0.25/0.5/0.75/1`、Normal Scale `0/1/2`，共 11 个样例。
- `MaterialBoundaryMatrix` 统一计算 `smoothness=1-roughness`、`alpha=max(roughness²,1e-4)` 和介电权重 `1-metallic`。
- `MaterialBoundaryValidator` 生成 11 个边界材质、三行对比场景、1200×720 截图和 JSON 报告。
- 无 Editor 许可证时，`Tools/GenerateBoundaryBoard.ps1` 从同一 JSON 基准生成 `Reports/MaterialBoundaryBoard.png`，`StaticValidate.ps1` 校验全部公式与范围。
- 结论：Metallic 中间值仅作为混合过渡；Normal Scale `2` 为验证上限；零粗糙度使用 GGX 数值下限避免奇异值。

## Shader Graph Custom Function 节点

- `Assets/_TA/ShaderGraph/TA_CustomFunctions.hlsl` 提供 File 模式的 `TA_SanitizeMaterial` 与 `TA_SampleMaterialInputs`，均含 `_float` / `_half` 精度变体。
- `TA_SampleMaterialInputs` 覆盖标量（Metallic/Roughness/NormalScale）、向量（UV）和纹理（BaseColor/Normal/ORM）端口，并以 `UnityTexture2D.tex` + `UnityTexture2D.samplerstate` 采样。
- 在 Unity 菜单执行 `TA/Material Lab/Create Custom Function Example`，生成 `SG_CustomFunctionExample.shadersubgraph`；函数名填 `TA_SampleMaterialInputs`，不要追加精度后缀。
- 端口表、失败点和静态验收见 `../docs/UNITY_SHADER_GRAPH_CUSTOM_FUNCTION.md` 与 `Assets/_TA/Documentation/ShaderGraphCustomFunctionContract.json`。

## 常见失败点

- 用错误 Editor 打开导致包升级、材质序列化变化或场景重导入。
- FBX/OBJ 单位和轴向未统一，出现 100 倍缩放、倒置或错误枢轴。
- 法线贴图/数据贴图误标为 sRGB，或基础色贴图忘记启用 sRGB。
- 模型自动导入来源材质，造成重复材质、命名污染和不可追踪依赖。
- 把 `Library`、`Temp`、`Logs` 或本机绝对路径提交到版本控制。

## 当前边界

本阶段已建立工程、资产基线、BaseColor/Normal/ORM 输入契约、三个 URP Lit 材质实例、参数边界矩阵，以及可生成的 Shader Graph Custom Function 子图示例。完整 Shader Graph 主材质属于后续日程任务。

当前机器的 Editor 自动化若被许可证阻塞，诊断与解锁步骤见 `Reports/EDITOR_VALIDATION_BLOCKED.md`；静态 PASS 不能替代最终 Editor 场景验收。
