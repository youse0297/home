# 阶段 1 总验收

## 验收结论规则

阶段 1 同时覆盖 CPU 软渲染器发布基线和 Unity 材质实验室的离线资产/Shader 基线。统一入口只在必过门禁失败时返回非零退出码，并用三个结论区分结果：

- `PASS`：全部离线门禁与外部运行门禁均通过。
- `CONDITIONAL_PASS`：全部必过离线门禁通过，但 Unity Editor 许可证或 RenderDoc 工具仍阻塞运行验收。
- `FAIL`：任一必过构建、测试、数值或静态门禁失败。

`CONDITIONAL_PASS` 不等同于完整发布通过；它只表示当前仓库内可执行的阶段 1 内容已经通过，外部阻塞项必须保留证据并在环境恢复后补验。

## 必过门禁

| 类别 | 门禁 | 固定要求 |
| --- | --- | --- |
| CPU | CMake Configure | 工程可重新配置 |
| CPU | Debug Build | `release_acceptance` 等目标构建成功 |
| CPU | CTest | `12/12` 全部通过 |
| CPU | Release PPM | 生成 P6 发布图；固定 checksum 由 CTest 校验 |
| Unity | Material Boundary Matrix | 11 组 Metallic/Roughness/Normal Scale 基线可生成 |
| Unity | Material Function Library | 6 个函数与 6 组 fixture 全部通过 |
| Unity | Texture Compression | BC1/BC5/BC7 策略、显存和 BC1 往返基线通过 |
| Unity | LOD Baseline | 三档阈值、四个切换样本与对照板通过 |
| Unity | BasePass Decomposition | 10 档视图与最终光照加法不变量通过 |
| Unity | Static Validation | 工程、资产、HLSL、C# 离线编译和报告全部通过 |

## 外部运行门禁

- Unity Editor Runtime：需要 Unity `2022.3.62f3c1` 的有效 `headless` 或 `ui` entitlement，完成场景生成、Shader 导入/编译和运行截图。
- RenderDoc Capture Readiness：需要安装 RenderDoc，按六个 `RD/*` GPU 书签完成真实 `.rdc` 捕获；不得用静态对照板冒充捕获文件。

外部运行门禁会写入总报告，但在明确记录为 `BLOCKED` 时不把源码判为失败。

## 执行命令

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\RunStage1Acceptance.ps1
```

脚本会自动从 PATH 或已有 `build/CMakeCache.txt` 解析 `cmake.exe`/`ctest.exe`，依次重建 CPU 工程、运行 12 项 CTest、刷新 Unity 离线报告、检查 RenderDoc 准备状态，并在最后运行 `StaticValidate.ps1`。

固定输出：

- `output/Stage1AcceptanceReport.json`：机器可读的门禁、阻塞项、证据路径和命令尾部输出。
- `output/Stage1AcceptanceSummary.md`：可直接归档的中文验收摘要。
- `build/release_acceptance.ppm`：CPU 三材质发布基准图。
- `UnityMaterialLab/Reports/`：Unity 参数、函数、压缩、LOD、BasePass 和静态报告。

## 补验步骤

1. 激活 Unity Editor 许可证并运行 `UnityMaterialLab/Tools/BuildAndValidate.ps1`。
2. 执行 `TA/Material Lab/Build BasePass Lighting Decomposition`，确认场景中 10 档视图与静态板一致。
3. 安装 RenderDoc，运行 `UnityMaterialLab/Tools/RenderDocCaptureCheck.ps1`，要求状态变为 `READY_TO_CAPTURE`。
4. 捕获稳定帧并保存为 `UnityMaterialLab/Reports/RenderDoc/MaterialLab_Frame_0001.rdc`。
5. 重新运行阶段 1 总验收，并人工确认外部运行证据。
The Stage 1 offline gate set now includes the dedicated `Direct-light PBR Integration` validator. It checks the energy-conserving direct diffuse path, GGX/Smith/Fresnel specular composition, back-face guard and BasePass wiring before the aggregate static gate.
