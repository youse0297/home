# VecMath

VecMath 是一个使用 C++17 编写的轻量级向量与矩阵数学项目，提供二维、三维和四维向量运算、4×4 矩阵运算、左右手坐标系支持，以及图形学中常用的平移、缩放和旋转变换。

项目当前以控制台程序演示立方体顶点经过组合变换后的结果，不依赖第三方数学库。

## 主要功能

| 模块 | 功能 |
| --- | --- |
| `Vec2` | 二维向量加减、数乘、点积、叉积、长度和归一化 |
| `Vec3` | 三维向量加减、数乘、点积、叉积、长度和归一化 |
| `Vec4` | 四维向量运算，以及 `Vec3` 到齐次坐标的转换 |
| `VectorUtils` | 夹角、投影、侧向判断和左右手坐标系转换 |
| `Mat4` | 4×4 矩阵、矩阵乘法、矩阵与四维向量相乘 |
| `Transform` | 平移、缩放、绕 X/Y/Z 轴旋转和绕任意轴旋转 |

## 数学约定

- 默认使用右手坐标系，可通过全局变量 `g_handedness` 切换为左手坐标系。
- 从右手系转换到左手系时，Z 分量取反。
- `Mat4` 使用列主序存储：`m[col * 4 + row]`。
- `Mat4 * Vec4` 表示矩阵乘列向量；项目也提供 `Vec4 * Mat4` 左乘形式。
- 组合矩阵 `T * R * S` 的实际应用顺序是先缩放、再旋转、最后平移。
- `Transform` 的旋转角度使用弧度；`rotationAxis` 要求旋转轴是单位向量。
- `Mat4()` 创建零矩阵，单位矩阵需要使用 `Mat4::identity()`。

## 环境要求

- 支持 C++17 的编译器，例如 GCC/MinGW-w64、Clang 或 MSVC
- Windows 示例程序使用 `SetConsoleOutputCP` 设置 UTF-8 控制台输出
- 核心数学代码仅依赖 C++ 标准库

## 编译与运行

### MinGW-w64

在项目根目录执行：

```powershell
g++ -std=gnu++17 -finput-charset=UTF-8 -fexec-charset=UTF-8 -g src/main.cpp src/Vec2.cpp src/Vec3.cpp src/VectorUtils.cpp src/Vec4.cpp src/Mat4.cpp src/Transform.cpp -o main.exe
./main.exe
```

示例程序使用了 MinGW 提供的 `M_PI`，所以这里采用 `gnu++17` 模式；向量、矩阵和变换模块本身按 C++17 编写。

### 中文显示

所有源码文件应保存为 UTF-8。如果 PowerShell 仍然显示乱码，可以先切换终端代码页：

```powershell
chcp 65001
./main.exe
```

编译参数 `-finput-charset=UTF-8` 用于指定源文件编码，`-fexec-charset=UTF-8` 用于保证字符串常量以 UTF-8 写入可执行文件。

## 使用示例

### 向量与投影

```cpp
#include "Vec3.hpp"
#include "VectorUtils.hpp"

Vec3 direction(1.0, 0.0, 0.0);
Vec3 point(2.0, 3.0, 0.0);

Vec3 projection = Vec3Utils::project(point, direction);
double angle = Vec3Utils::angle(direction, point);
```

### 齐次坐标

```cpp
Vec3 value(1.0, 2.0, 3.0);

Vec4 point(value, 1.0);      // w = 1，表示位置，可受平移影响
Vec4 direction(value, 0.0);  // w = 0，表示方向，不受平移影响
```

### 组合变换

```cpp
#include "Transform.hpp"

constexpr double pi = 3.14159265358979323846;

Mat4 scale = Transform::scaling(Vec3(1.5, 1.5, 1.5));
Mat4 rotation = Transform::rotationY(45.0 * pi / 180.0);
Mat4 translation = Transform::translation(Vec3(2.0, 1.0, 0.0));
Mat4 transform = translation * rotation * scale;

Vec4 vertex(Vec3(1.0, 1.0, 1.0), 1.0);
Vec4 transformed = transform * vertex;
```

## 项目结构

```text
.
├── CMakeLists.txt
├── README.md
├── ISSUES.md
├── output/
│   └── handedness.png
└── src/
    ├── main.cpp
    ├── Vec2.hpp / Vec2.cpp
    ├── Vec3.hpp / Vec3.cpp
    ├── Vec4.hpp / Vec4.cpp
    ├── Mat4.hpp / Mat4.cpp
    ├── Transform.hpp / Transform.cpp
    ├── VectorUtils.hpp / VectorUtils.cpp
    └── handedness.py
```

## 注意事项

- 零向量归一化会返回零向量。
- 标量除法遇到零会抛出异常。
- `side` 的符号会受到当前左右手坐标系设置影响。
- `handedness.py` 用于生成左右手坐标系示意图，输出位于 `output/handedness.png`。
- 已知问题和后续计划记录在 [ISSUES.md](ISSUES.md) 中。
