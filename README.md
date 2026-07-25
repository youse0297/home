# VecMath

VecMath 是一个使用 C++17 编写的轻量级向量与矩阵数学项目，提供二维、三维和四维向量运算、3×3/4×4 矩阵运算、左右手坐标系支持，以及图形学中常用的模型、视图、投影、视口、法线矩阵和切线空间变换。

项目当前以控制台程序演示完整的 MVP 顶点路径，以及非均匀缩放下的逆转置法线变换和 TBN 映射，并使用固定数值自动验收，不依赖第三方数学库。

## 主要功能

| 模块 | 功能 |
| --- | --- |
| `Vec2` | 二维向量加减、数乘、点积、叉积、长度和归一化 |
| `Vec3` | 三维向量加减、数乘、点积、叉积、长度和归一化 |
| `Vec4` | 四维向量运算，以及 `Vec3` 到齐次坐标的转换 |
| `VectorUtils` | 夹角、投影、侧向判断和左右手坐标系转换 |
| `Mat3` | 3×3 列主序矩阵、行列式、转置、求逆和方向向量变换 |
| `Mat4` | 4×4 矩阵、矩阵乘法、矩阵与四维向量相乘 |
| `Transform` | 平移、缩放、绕 X/Y/Z 轴旋转和绕任意轴旋转（Rodrigues 公式） |
| `Camera` | `lookAt` 视图矩阵生成，支持任意相机位置与朝向 |
| `Projection` | `perspective` 透视投影矩阵生成，采用右手系和 OpenGL 风格 NDC |
| `Pipeline` | MVP 组合、齐次除法、裁剪体判断和屏幕视口映射 |
| `TangentSpace` | 逆转置法线矩阵、方向/法线变换、TBN 构建和空间转换 |

## 数学约定

- 默认使用右手坐标系，可通过全局变量 `g_handedness` 切换为左手坐标系。
- 从右手系转换到左手系时，Z 分量取反。
- `Mat4` 使用列主序存储：`m[col * 4 + row]`。
- `Mat4 * Vec4` 表示矩阵乘列向量；项目也提供 `Vec4 * Mat4` 左乘形式。
- 组合矩阵 `T * R * S` 的实际应用顺序是先缩放、再旋转、最后平移。
- `Transform` 的旋转角度使用弧度；`rotationAxis` 要求旋转轴是单位向量。
- `Mat4()` 创建零矩阵，单位矩阵需要使用 `Mat4::identity()`。
- `Camera::lookAt` 基于右手系构建视图矩阵，相机看向 -Z 方向，forward = eye - target。
- `Camera::perspective` 使用右手系和 OpenGL 风格 NDC，深度范围为 `[-1, 1]`；垂直视场角使用弧度。
- MVP 组合顺序为 `Projection * View * Model`，矩阵作用于列向量时从右向左执行。
- 默认屏幕视口采用左上角原点，X 向右、Y 向下；也可以选择左下角原点。
- NDC 深度 `[-1, 1]` 会映射到视口的 `[minDepth, maxDepth]`，默认是 `[0, 1]`。
- 法线矩阵使用模型矩阵左上 3×3 线性部分的逆转置：`NormalMatrix = transpose(inverse(Mat3(Model)))`。
- TBN 矩阵按列存储 `T`、`B`、`N`，通过 Gram-Schmidt 保证切线与法线正交；切线符号用于处理镜像 UV。

## 环境要求

- 支持 C++17 的编译器，例如 GCC/MinGW-w64、Clang 或 MSVC
- Windows 示例程序使用 `SetConsoleOutputCP` 设置 UTF-8 控制台输出
- 核心数学代码仅依赖 C++ 标准库

## 编译与运行

### MinGW-w64

在项目根目录执行：

```powershell
g++ -std=c++17 -finput-charset=UTF-8 -fexec-charset=UTF-8 -g src/main.cpp src/Vec2.cpp src/Vec3.cpp src/VectorUtils.cpp src/Mat3.cpp src/Vec4.cpp src/Mat4.cpp src/Transform.cpp src/Camera.cpp src/Projection.cpp src/Pipeline.cpp src/TangentSpace.cpp -o main.exe
./main.exe
```

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

### 相机视图矩阵

```cpp
#include "Camera.hpp"

Vec3 eye(0.0, 0.0, 5.0);     // 相机位置
Vec3 target(0.0, 0.0, 0.0);  // 观察目标
Vec3 up(0.0, 1.0, 0.0);      // 世界上方向

Mat4 view = Camera::lookAt(eye, target, up);

Vec4 worldPoint(0.0, 0.0, 0.0, 1.0);
Vec4 viewPoint = view * worldPoint;  // 变换到相机空间
```

### 透视投影矩阵

```cpp
#include "Projection.hpp"

constexpr double pi = 3.14159265358979323846;

double fovY = 60.0 * pi / 180.0;
double aspect = 16.0 / 9.0;
Mat4 projection = Camera::perspective(fovY, aspect, 0.1, 100.0);

Vec4 viewPoint(0.0, 0.0, -1.0, 1.0);
Vec4 clipPoint = projection * viewPoint;
Vec4 ndcPoint = clipPoint / clipPoint.w;
```

`fovY` 使用弧度，`aspect` 必须大于 0，并且需要满足 `0 < zNear < zFar`；参数无效时函数会抛出 `std::invalid_argument`。

### 完整 MVP 与视口映射

```cpp
#include "Camera.hpp"
#include "Pipeline.hpp"
#include "Projection.hpp"
#include "Transform.hpp"

constexpr double pi = 3.14159265358979323846;

Mat4 model = Transform::translation(Vec3(1.0, 0.0, 0.0));
Mat4 view = Camera::lookAt(
    Vec3(0.0, 0.0, 5.0),
    Vec3(0.0, 0.0, 0.0),
    Vec3(0.0, 1.0, 0.0)
);
Mat4 projection = Camera::perspective(pi / 2.0, 16.0 / 9.0, 1.0, 10.0);

Pipeline::Viewport viewport{
    0.0, 0.0, 1280.0, 720.0,
    0.0, 1.0,
    Pipeline::ViewportOrigin::TopLeft
};

Pipeline::VertexResult result = Pipeline::transformVertex(
    Vec4(0.0, 0.0, 0.0, 1.0),
    model,
    view,
    projection,
    viewport
);
```

该样例最终得到 NDC 坐标 `(0.1125, 0, 0.7778)`，映射到 1280×720 视口后为屏幕坐标 `(712, 360, 0.8889)`。

视口映射公式如下：

```text
screenX = viewportX + (ndcX + 1) / 2 * width
screenY = viewportY + (1 - (ndcY + 1) / 2) * height   // 左上原点
screenZ = minDepth + (ndcZ + 1) / 2 * (maxDepth - minDepth)
```

### 法线矩阵与切线空间

```cpp
#include "TangentSpace.hpp"
#include "Transform.hpp"

Mat4 model = Transform::scaling(Vec3(2.0, 1.0, 0.5));
Vec3 objectTangent = Vec3(1.0, 0.0, 1.0).normalized();
Vec3 objectNormal = Vec3(1.0, 0.0, -1.0).normalized();

Mat3 normalMatrix = TangentSpace::makeNormalMatrix(model);
Vec3 worldTangent = TangentSpace::transformDirection(
    model,
    objectTangent
).normalized();
Vec3 worldNormal = TangentSpace::transformNormal(
    normalMatrix,
    objectNormal
);
Mat3 tbn = TangentSpace::buildTBN(worldNormal, worldTangent);

Vec3 tangentNormal(0.0, 0.0, 1.0);
Vec3 mappedWorldNormal = TangentSpace::tangentToWorld(tbn, tangentNormal);
```

固定基准中，正确逆转置变换得到 `T·N = 0`；如果错误地用模型矩阵直接变换法线，则 `T·N ≈ 0.8824`，说明非均匀缩放已经破坏垂直关系。构建 TBN 后，切线空间 `+Z` 会精确映射回世界空间法线。

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
    ├── Mat3.hpp / Mat3.cpp
    ├── Mat4.hpp / Mat4.cpp
    ├── Transform.hpp / Transform.cpp
    ├── Camera.hpp / Camera.cpp
    ├── Projection.hpp / Projection.cpp
    ├── Pipeline.hpp / Pipeline.cpp
    ├── TangentSpace.hpp / TangentSpace.cpp
    ├── VectorUtils.hpp / VectorUtils.cpp
    └── handedness.py
```

## 注意事项

- 零向量归一化会返回零向量。
- 标量除法遇到零会抛出异常。
- `side` 的符号会受到当前左右手坐标系设置影响。
- 透视除法要求裁剪坐标的 `w` 为有限非零值，否则 `Pipeline::perspectiveDivide` 会抛出异常。
- `Pipeline::mapToViewport` 不会自动裁剪超出 NDC 的坐标；应先检查 `insideClipVolume`。
- 常见失败点包括：MVP 乘法顺序写反、视图矩阵行列混淆、忘记齐次除法、混用 `[-1,1]` 与 `[0,1]` 深度范围，以及屏幕 Y 轴方向错误。
- 法线不能在非均匀缩放下直接乘模型矩阵；平移分量也不参与法线变换。
- 零缩放会使法线矩阵不可逆；切线与法线平行时也无法构建有效 TBN，接口会抛出异常。
- 镜像 UV 应把顶点切线的手性符号传给 `buildTBN`，否则副切线方向会翻转。
- `handedness.py` 用于生成左右手坐标系示意图，输出位于 `output/handedness.png`。
- 已知问题和后续计划记录在 [ISSUES.md](ISSUES.md) 中。
