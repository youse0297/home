# 项目结构约定

## 目录职责

| 目录 | 职责 | 可以依赖 |
| --- | --- | --- |
| `src/` | `graphics_math` 与 `software_renderer` 两个可复用 C++ 库 | 标准库；`software_renderer` 可依赖 `graphics_math` |
| `apps/` | 面向人工运行的最小示例入口 | 两个 C++ 库 |
| `tests/acceptance/` | 具有固定数值和退出码的阶段验收程序 | 两个 C++ 库与 `tests/data/` |
| `tests/data/` | 版本化、确定性的测试输入 | 不依赖源码 |
| `cmake/` | 跨目标复用的编译特性和平台选项 | CMake 本身 |
| `Tools/` | 总验收、报告生成和辅助可视化 | 已发布的命令行目标或独立运行时 |
| `docs/` | 范围、接口、验收和操作说明 | 只引用稳定路径与目标名 |
| `output/` | 需要归档的阶段报告和参考图 | 由 `Tools/` 生成 |
| `UnityMaterialLab/` | 独立的 Unity URP 工程、资产和专项报告 | 不反向依赖 C++ 源码目录 |

依赖方向固定为：

```text
graphics_math -> software_renderer -> apps / acceptance tests
```

`apps/` 和 `tests/acceptance/` 不能被库目标反向引用。Unity 工程保持独立，只通过阶段验收脚本汇总结果。

## CMake 分层

- 根 `CMakeLists.txt` 只声明项目、加载公共选项并添加子目录。
- `cmake/ProjectOptions.cmake` 统一 C++17 和 UTF-8 编译选项。
- `src/CMakeLists.txt` 只定义库目标和公开 include 路径。
- `apps/CMakeLists.txt` 只定义人工运行入口。
- `tests/CMakeLists.txt` 统一定义验收目标、fixture 路径和 CTest 注册。
- 根配置固定 `CMAKE_RUNTIME_OUTPUT_DIRECTORY`，确保分层后仍沿用 `build/Debug/*.exe` 等稳定运行路径。

目标名与 CTest 名属于稳定接口；移动实现文件时不应随意改名。

## 新增规则

1. 新增可复用算法时，将 `.hpp/.cpp` 放入 `src/` 并加入对应库的 source list。
2. 新增演示程序时放入 `apps/`，只保留参数组装和输出，不复制库实现。
3. 新增固定回归时放入 `tests/acceptance/`，通过 `add_acceptance_target` 注册，并补充 `add_test`。
4. 新增 fixture 时放入 `tests/data/`，由 CMake 注入绝对路径，不依赖运行目录。
5. 新增生成工具时放入 `Tools/`；可复现产物写入 `output/` 或对应子工程的 `Reports/`。
6. 构建产物只能进入 `build*`，不得写回 `src/`、`apps/` 或 `tests/acceptance/`。

`Tools/GenerateHandednessPlot.py` 是可选可视化工具，需要 Python 3 和 matplotlib；C++ 构建与阶段验收不依赖该环境。

## 验证

```powershell
cmake -S . -B build
cmake --build build --config Debug --parallel
ctest --test-dir build -C Debug --output-on-failure
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\RunStage1Acceptance.ps1
```

结构调整必须保持 12 个 CTest 名称、`release_acceptance.ppm` 固定 checksum 和阶段 1 必过门禁不变。
