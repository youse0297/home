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
- 输出：一个材质球 Prefab、一个导入资产 Prefab、五个 URP Lit 材质、可复用测试场景、基线截图和 JSON 验收报告。
- 验收：URP 已启用；模型含法线/UV；贴图导入设置正确；场景根节点、Prefab、材质和 Build Settings 完整。

## 常见失败点

- 用错误 Editor 打开导致包升级、材质序列化变化或场景重导入。
- FBX/OBJ 单位和轴向未统一，出现 100 倍缩放、倒置或错误枢轴。
- 法线贴图/数据贴图误标为 sRGB，或基础色贴图忘记启用 sRGB。
- 模型自动导入来源材质，造成重复材质、命名污染和不可追踪依赖。
- 把 `Library`、`Temp`、`Logs` 或本机绝对路径提交到版本控制。

## 当前边界

本阶段只建立工程、资产基线和 URP Lit 验证材质。Shader Graph 主材质、BaseColor/Normal/ORM 实例参数和参数边界矩阵属于后续日程任务。

当前机器的 Editor 自动化若被许可证阻塞，诊断与解锁步骤见 `Reports/EDITOR_VALIDATION_BLOCKED.md`；静态 PASS 不能替代最终 Editor 场景验收。
