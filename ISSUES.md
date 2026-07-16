# Issues & TODOs

## 已修复问题 (Fixed)

| 编号 | 问题描述 | 修复日期 | 备注 |
| :--- | :--- | :--- | :--- |
| #1 | `Vec2` 类缺少 `cross` 成员函数，导致 `VectorUtils::side` 编译失败 | 2026-07-17 | 已在 `Vec2.hpp/cpp` 中添加 `cross` |
| #2 | `Vec3` 类缺少 `cross` 成员函数 | 2026-07-17 | 已在 `Vec3.hpp/cpp` 中添加 `cross` |
| #3 | 使用 `std::setprecision` 未包含 `<iomanip>` 头文件 | 2026-07-17 | 已在 `main.cpp` 中添加 `#include <iomanip>` |
| #4 | 函数名大小写错误：`Angle` 应为 `angle` | 2026-07-17 | 统一使用小写 `angle` |
| #5 | Windows 控制台中文乱码（UTF-8 vs GBK） | 2026-07-17 | 通过 `SetConsoleOutputCP(CP_UTF8)` 解决，或改用英文输出 |

---

## 待解决 / 待验证 (Open)

| 编号 | 问题描述 | 优先级 | 状态 |
| :--- | :--- | :--- | :--- |
| #6 | 在 Linux/macOS 下未测试，可能存在平台差异（如 `M_PI` 未定义） | 中 | 待测试 |
| #7 | 未实现 `cross` 的 `constexpr` 或 `noexcept` 优化 | 低 | 考虑加入 |
| #8 | 投影函数在 `b` 为零向量时返回零向量，但调用方可能未检查 | 低 | 可添加日志或断言 |

---

## 未来改进建议 (Future Enhancements)

| 编号 | 建议 | 优先级 | 备注 |
| :--- | :--- | :--- | :--- |
| #9 | 将 `Vec2` 和 `Vec3` 合并为模板类 `Vec<T, N>`，减少代码重复 | 中 | 需重构项目结构 |
| #10 | 添加四元数或矩阵变换支持 | 低 | 后续扩展 |
| #11 | 添加单元测试（如 Google Test） | 高 | 提高可靠性 |
| #12 | 增加 `std::hash` 支持，便于作为 `unordered_map` 键 | 低 | 可选 |
| #13 | 提供 `lerp`（线性插值）、反射等高级几何函数 | 中 | 可放入 `VectorUtils` |

---

## 注意事项

- 当前坐标系默认为右手系，可通过 `g_handedness` 全局变量切换。
- 使用 `Vec2Utils::side` 或 `Vec3Utils::side` 时，请确保 `g_handedness` 设置正确。
- 所有输出示例均以 `std::fixed << std::setprecision(4)` 格式化，如需不同精度可调整。

---

## 如何贡献

如果你发现了新的问题或有改进建议，请在本文件中添加一条记录，或直接在代码仓库中提 Issue / PR。

---

*最后更新：2026-07-17*