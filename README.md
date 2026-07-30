# VecMath / CPU 软渲染器

本项目使用 C++17 构建 CPU 软渲染器。当前包含完整的图形数学基础、OBJ 顶点数据读取、MVP 顶点着色、屏幕空间三角形覆盖、透视正确插值、深度测试与基础面剔除，以及独立的 framebuffer 和渲染循环骨架。

项目当前以控制台程序演示完整的 MVP 顶点路径、非均匀缩放下的逆转置法线变换和 TBN 映射，以及基础 Fresnel/Schlick 反射率。图形数学阶段验收覆盖 4 组固定数值套件，并可通过 CTest 重复执行，不依赖第三方数学库。

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
| `Fresnel` | 介电材质基础反射率 `F0` 和标量/RGB Schlick 近似 |
| `Framebuffer` | 行主序 RGBA/深度缓冲、严格 `Less` 深度测试、原子片元写入和清屏 |
| `ObjLoader` | OBJ `v/vt/vn`、正负索引、三角面、多边形扇形三角化和结构化解析异常 |
| `VertexStage` | OBJ 三角面装配、MVP 顶点变换、屏幕空间输出和保守裁剪分类 |
| `Rasterizer` | 包围盒、边函数、top-left 覆盖、重心坐标、透视权重和基础面剔除 |
| `SoftwareRenderer` | 固定帧生命周期、逐帧清屏、帧回调和完成帧计数 |

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
- 介电材质正入射反射率为 `F0 = ((n1 - n2) / (n1 + n2))²`；Schlick 近似为 `F = F0 + (1 - F0)(1 - cosθ)⁵`。

## 环境要求

- 支持 C++17 的编译器，例如 GCC/MinGW-w64、Clang 或 MSVC
- Windows 示例程序使用 `SetConsoleOutputCP` 设置 UTF-8 控制台输出
- 核心数学代码仅依赖 C++ 标准库

## 编译与运行

### CMake

```powershell
cmake -S . -B build
cmake --build build --config Debug
./build/Debug/vecmath.exe
./build/Debug/soft_renderer.exe
./build/Debug/obj_loader_acceptance.exe
./build/Debug/vertex_stage_acceptance.exe
./build/Debug/triangle_rasterizer_acceptance.exe
./build/Debug/depth_buffer_acceptance.exe
ctest --test-dir build -C Debug --output-on-failure
```

### MinGW-w64

在项目根目录执行：

```powershell
g++ -std=c++17 -finput-charset=UTF-8 -fexec-charset=UTF-8 -g src/main.cpp src/Vec2.cpp src/Vec3.cpp src/VectorUtils.cpp src/Mat3.cpp src/Vec4.cpp src/Mat4.cpp src/Transform.cpp src/Camera.cpp src/Projection.cpp src/Pipeline.cpp src/TangentSpace.cpp src/Fresnel.cpp -o main.exe
./main.exe

g++ -std=c++17 -finput-charset=UTF-8 -fexec-charset=UTF-8 -g src/soft_renderer_main.cpp src/Framebuffer.cpp src/SoftwareRenderer.cpp -o soft_renderer.exe
./soft_renderer.exe

g++ -std=c++17 -finput-charset=UTF-8 -fexec-charset=UTF-8 -g src/obj_loader_main.cpp src/ObjLoader.cpp src/Vec2.cpp src/Vec3.cpp -o obj_loader_acceptance.exe
./obj_loader_acceptance.exe

g++ -std=c++17 -finput-charset=UTF-8 -fexec-charset=UTF-8 -g src/vertex_stage_main.cpp src/VertexStage.cpp src/ObjLoader.cpp src/Pipeline.cpp src/Transform.cpp src/Camera.cpp src/Projection.cpp src/Mat4.cpp src/Vec4.cpp src/Vec3.cpp src/Vec2.cpp -o vertex_stage_acceptance.exe
./vertex_stage_acceptance.exe

g++ -std=c++17 -finput-charset=UTF-8 -fexec-charset=UTF-8 -g src/rasterizer_main.cpp src/Rasterizer.cpp src/VertexStage.cpp src/ObjLoader.cpp src/Pipeline.cpp src/Transform.cpp src/Camera.cpp src/Projection.cpp src/Mat4.cpp src/Vec4.cpp src/Vec3.cpp src/Vec2.cpp -o triangle_rasterizer_acceptance.exe
./triangle_rasterizer_acceptance.exe

g++ -std=c++17 -finput-charset=UTF-8 -fexec-charset=UTF-8 -g src/depth_buffer_main.cpp src/Framebuffer.cpp src/Rasterizer.cpp src/VertexStage.cpp src/ObjLoader.cpp src/Pipeline.cpp src/Transform.cpp src/Camera.cpp src/Projection.cpp src/Mat4.cpp src/Vec4.cpp src/Vec3.cpp src/Vec2.cpp -o depth_buffer_acceptance.exe
./depth_buffer_acceptance.exe
```

### 中文显示

所有源码文件应保存为 UTF-8。如果 PowerShell 仍然显示乱码，可以先切换终端代码页：

```powershell
chcp 65001
./main.exe
```

编译参数 `-finput-charset=UTF-8` 用于指定源文件编码，`-fexec-charset=UTF-8` 用于保证字符串常量以 UTF-8 写入可执行文件。

## 图形数学阶段验收

| 验收套件 | 固定基准 |
| --- | --- |
| 向量、矩阵与组合变换 | Vec2 长度/点积/叉积、Vec3 右手系叉积、Mat3 求逆、`T * R * S` 顺序 |
| MVP 与视口映射 | 世界/观察/裁剪/NDC/屏幕坐标，以及组合 MVP 一致性 |
| 法线矩阵与切线空间 | 非均匀缩放逆转置、TBN 正交性、空间往返、奇异矩阵保护 |
| Fresnel | 介电材质 `F0`、标量/RGB Schlick 近似、无效折射率与反射率保护 |

使用 CMake 构建后，可重复运行阶段验收：

```powershell
cmake -S . -B build
cmake --build build --config Debug
ctest --test-dir build -C Debug --output-on-failure
```

四个套件全部执行且固定基准一致时，程序输出 `图形数学阶段验收: PASS` 并以退出码 `0` 结束；任何数值偏差、非有限值或参数保护失败都会以非零退出码结束。

## 软渲染器骨架

`Framebuffer` 分配同尺寸的 RGBA 颜色缓冲与 `[0, 1]` 深度缓冲。`SoftwareRenderer` 每帧先清理两组缓冲，再调用一次帧回调，回调成功后递增完成帧数。

当前固定基准运行 4×3 framebuffer 共 3 帧，验证逐帧清屏、缓冲读写、帧序号，以及非法尺寸/深度/坐标保护。完整接口约定、后续范围和排除项见 [CPU 软渲染器 v1.0 范围冻结](docs/SOFTWARE_RENDERER_SCOPE.md)。

OBJ 读取、顶点着色、三角形覆盖与深度缓冲已按前四项日程完成。本版本仍明确不做阴影、抗锯齿和次表面散射；纹理和 PBR 属于后续已排期任务。

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

### Fresnel 基础

```cpp
#include "Fresnel.hpp"

double glassF0 = Fresnel::dielectricF0(1.0, 1.5);
double facing = Fresnel::schlick(1.0, glassF0);
double atSixtyDegrees = Fresnel::schlick(0.5, glassF0);
double grazing = Fresnel::schlick(0.0, glassF0);

Vec3 copperF0(0.95, 0.64, 0.54);
Vec3 copperAtSixtyDegrees = Fresnel::schlick(0.5, copperF0);
```

空气到玻璃的固定基准得到 `F0 = 0.04`。正视时反射率为 `0.04`，60° 时为 `0.07`，掠射角时趋近 `1.0`；RGB 重载可表达金属的有色基础反射率。

## 项目结构

```text
.
├── CMakeLists.txt
├── README.md
├── ISSUES.md
├── docs/
│   └── SOFTWARE_RENDERER_SCOPE.md
├── output/
│   └── handedness.png
├── src/
    ├── main.cpp
    ├── soft_renderer_main.cpp
    ├── obj_loader_main.cpp
    ├── vertex_stage_main.cpp
    ├── rasterizer_main.cpp
    ├── depth_buffer_main.cpp
    ├── Framebuffer.hpp / Framebuffer.cpp
    ├── ObjLoader.hpp / ObjLoader.cpp
    ├── Rasterizer.hpp / Rasterizer.cpp
    ├── SoftwareRenderer.hpp / SoftwareRenderer.cpp
    ├── VertexStage.hpp / VertexStage.cpp
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
    ├── Fresnel.hpp / Fresnel.cpp
    ├── VectorUtils.hpp / VectorUtils.cpp
    └── handedness.py
└── tests/
    └── data/
        └── vertex_data.obj
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
- `Fresnel::schlick` 会把 `cosTheta` 夹到 `[0, 1]`；`F0` 必须位于 `[0, 1]`，折射率必须为有限正数。
- framebuffer 采用左上原点和行主序，深度范围固定为 `[0, 1]`；`depthTest` 使用严格 `Less`，`writeFragment` 仅在通过时同时写入颜色和深度。
- OBJ 面索引在加载时转为零基下标；缺失的 UV/法线保留为 `kMissingObjIndex`。格式、数值或索引错误抛出 `ObjParseError`，可查询来源、行号和原因。
- `VertexStage` 保留 OBJ 角点索引，输出世界/观察/裁剪/NDC/屏幕坐标及 `reciprocalW`；`RequiresClipping` 只标记待裁剪，不在本阶段修改三角形。
- `Rasterizer` 在像素中心采样并采用 top-left 共享边规则；线性重心坐标用于屏幕深度，`barycentric[i] * reciprocalW[i]` 归一化后用于透视正确属性插值。
- `Rasterizer` 只接收 `FullyInside` 三角形；`FullyOutside` 不产生样本，`RequiresClipping` 必须先经过后续几何裁剪阶段。
- `RasterizerOptions` 默认不剔除；启用背面剔除时，左上原点屏幕坐标默认以顺时针为正面，也可切换为逆时针或前面剔除。
- `handedness.py` 用于生成左右手坐标系示意图，输出位于 `output/handedness.png`。
- 已知问题和后续计划记录在 [ISSUES.md](ISSUES.md) 中。
