# Unity HLSL 专项验收

## 验收结论

可复用 HLSL 材质源码库 v1.0 已完成离线发布验收。验收从仅含 `ProjectVersion.txt` 和 URP `manifest.json` 的空 Unity 工程骨架开始，迁移发布包后核对文件哈希与 include 闭包，再使用 Windows SDK `fxc` 对聚合入口执行警告即错误的真实编译。

| 项目 | 固定口径 |
| --- | --- |
| 发布版本 | `1.0.0` |
| 源码契约版本 | `1.16.0` |
| Unity / URP | `2022.3.62f3c1` / `14.0.12` |
| 功能模块 | 18 个，不含聚合头 |
| HLSL 文件 | 19 个，含 `TA_ShaderLibrary.hlsl` |
| 公共符号 | 74 个 |
| 专项验证器 | 18/18 通过 |
| 源码库结构检查 | 116/116 通过 |
| 编译策略 | `ps_5_0`、`PSMain`、`/WX /Ges`、0 warning |
| 发布包条目 | 21 个：19 个 HLSL、README、release manifest |

发布产品版本与内部源码契约版本分别管理：`v1.0.0` 表示首次可迁移发布，`v1.16.0` 表示库内模块和接口演进到第 16 次契约修订。

## 一键复现

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\ValidateHlslSpecialAcceptance.ps1
```

脚本会从 PATH 或已安装的 Windows 10 SDK 自动发现 `fxc.exe`；也可使用 `-FxcPath` 显式指定。成功时输出 `UNITY_HLSL_SPECIAL_ACCEPTANCE: PASS`，并刷新：

- `UnityMaterialLab/Releases/TA_HLSL_MaterialLibrary_v1.0.0.zip`
- `UnityMaterialLab/Releases/TA_HLSL_MaterialLibrary_v1.0.0.sha256`
- `UnityMaterialLab/Reports/HlslSpecialAcceptance.json`

脚本会按文件名排序并固定 ZIP 条目时间，因此源码不变时重复发布得到相同 SHA-256。校验和文件是发布包完整性的唯一记录，验收报告同时保存本次哈希、归档字节数和条目数。

## 从空工程迁移

专项脚本自动执行以下流程：

1. 创建仅含 Unity 版本文件和 URP 包声明的两文件工程骨架。
2. 将 ZIP 解压到骨架根目录，得到 `Assets/TA_HLSL/Library`。
3. 按 `release-manifest.json` 校验每个发布文件的 SHA-256。
4. 逐个解析双引号 include，确认依赖全部落在迁移后的源码库中。
5. 将 `HlslReleaseSmoke.hlsl` 放入迁移工程，直接包含聚合头并调用顶点变形、采样、PBR、法线、遮罩、磨损、积雪、各向异性、光照、折射和调试输出接口。
6. 使用 `fxc /T ps_5_0 /E PSMain /WX /Ges` 编译，任何 warning 或 error 都会使验收失败。

手工接入已有 URP 工程时，解压发布包并复制 `Assets/TA_HLSL` 即可。消费 Shader 必须先包含 URP Core，再包含聚合头：

```hlsl
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/TA_HLSL/Library/TA_ShaderLibrary.hlsl"
```

## 验收清单

| 检查 | 通过条件 | 证据 |
| --- | --- | --- |
| 范围冻结 | 18 模块、74 公共符号、版本匹配 | `HlslSpecialAcceptance.json` |
| 分项回归 | 18 个验证器全部返回各自 PASS marker | `Reports/*Validation.json` |
| 源码结构 | 116 项检查且无失败 | `HlslSourceLibraryValidation.json` |
| 空工程起点 | 解包前仅 2 个工程文件 | `migration.projectSkeletonFileCount` |
| 迁移完整性 | 19 个 HLSL、所有哈希一致、include 闭包完整 | `migration` 与 `release-manifest.json` |
| 编译警告 | `fxc` 退出码 0，warning 数为 0 | `compiler` |
| 发布卫生 | 无 `.meta`、Unity 缓存、报告或 Git 状态 | `PACKAGE_CLEAN` |
| 可重复发布 | 连续生成的 ZIP SHA-256 一致 | `.sha256` 与专项报告 |

## 已知限制

- Windows SDK 编译器验证可移植 HLSL 语法、接口调用和迁移后的依赖可达性，不等价于 Unity URP 全平台 shader variant 编译。
- 当前机器缺少有效 Unity Editor entitlement，真实 Shader 导入、URP variant 编译和运行画面仍记为 `BLOCKED_LICENSE`。
- Unity 消费端必须先包含 `Core.hlsl`，使 `TEXTURE2D`、`SAMPLER` 等跨平台宏可用。
- 顶点动画法线重建以及 ShadowCaster/Depth pass 同步不在 v1.0 范围内。

许可证恢复后，应在 Unity 中导入发布 ZIP、打开综合示例场景并确认 Console 无 Shader 编译错误；该补验不会替代当前已通过的独立迁移和警告清零门禁。
