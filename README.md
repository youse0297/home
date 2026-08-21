# VecMath / CPU 软渲染器

本项目使用 C++17 构建 CPU 软渲染器，并附带 Unity URP 材质导入测试工程。当前包含完整的图形数学基础、OBJ 顶点数据读取、MVP 顶点着色、屏幕空间三角形覆盖、透视正确插值、深度测试、基础面剔除、PPM 纹理/UV 采样、世界空间法线与切线数据，以及 Lambert 漫反射、简化 GGX BRDF、纹理驱动金属粗糙度材质、曝光、Reinhard 色调映射和 sRGB 转换。

项目当前以控制台程序演示完整的 MVP 顶点路径、非均匀缩放下的逆转置法线变换和 TBN 映射，以及基础 Fresnel/Schlick 反射率。发布门禁覆盖 12 组固定验收，并生成具有代表色和整图 checksum 的三材质 PPM 基准图；完整流水线不依赖第三方图形或数学库。

Unity 资产导入阶段位于 `UnityMaterialLab/`，固定 Unity `2022.3.62f3c1`、URP `14.0.12`，包含 CC0 OBJ/PNG、统一命名/目录、URP Lit 材质球、BaseColor/Normal/ORM 输入、三个材质实例、11 组参数边界、Prefab、测试场景、导入 Bootstrap、三档 LOD 基础场景、RenderDoc 截帧准备、BasePass 光照拆解、Renderer 侧 HLSL 源码库和静态验收。工程步骤见 [Unity 工程与资产导入](UnityMaterialLab/README.md)，输入契约见 [Unity 材质输入与实例](docs/UNITY_MATERIAL_INPUTS.md)，边界结论见 [Unity 材质参数边界验证](docs/UNITY_MATERIAL_BOUNDARIES.md)，Custom Function 接入见 [Shader Graph Custom Function 节点](docs/UNITY_SHADER_GRAPH_CUSTOM_FUNCTION.md)，函数库见 [Unity 材质函数库](docs/UNITY_MATERIAL_FUNCTION_LIBRARY.md)，源码库见 [Unity HLSL 源码库骨架](docs/UNITY_HLSL_SOURCE_LIBRARY.md)，向量与采样接口见 [Unity 向量与采样工具函数](docs/UNITY_VECTOR_SAMPLING_UTILITIES.md)，简化 PBR 输入见 [Unity 简化 PBR 输入层](docs/UNITY_SIMPLIFIED_PBR_INPUT_LAYER.md)，GGX NDF 见 [Unity GGX 法线分布](docs/UNITY_GGX_NORMAL_DISTRIBUTION.md)，几何遮蔽与 Fresnel 见 [Unity 几何遮蔽与 Fresnel](docs/UNITY_GGX_GEOMETRY_FRESNEL.md)，压缩策略见 [Unity 贴图压缩](docs/UNITY_TEXTURE_COMPRESSION.md)，LOD 规则见 [Unity LOD 基础](docs/UNITY_LOD_BASICS.md)，截帧准备见 [Unity RenderDoc 截帧准备](docs/UNITY_RENDERDOC_CAPTURE_PREPARATION.md)，拆解视图见 [Unity BasePass 与光照拆解](docs/UNITY_BASEPASS_LIGHTING_DECOMPOSITION.md)。

## 阶段 1 总验收

统一入口会重新配置和构建 CPU 软渲染器、执行 CTest `12/12`、刷新 Unity 的参数/函数/压缩/LOD/BasePass 报告，并汇总 Unity Editor 与 RenderDoc 的外部阻塞状态：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\RunStage1Acceptance.ps1
```

结果写入 `output/Stage1AcceptanceReport.json` 与 `output/Stage1AcceptanceSummary.md`。结论规则、门禁清单和补验步骤见 [阶段 1 总验收](docs/STAGE1_ACCEPTANCE.md)。

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
| `ImageIO` | framebuffer 到 P6 RGB8 编码、有限值检查、显示范围夹取和文件写出 |
| `ObjLoader` | OBJ `v/vt/vn`、正负索引、三角面、多边形扇形三角化和结构化解析异常 |
| `VertexStage` | OBJ 三角面装配、MVP 变换、UV/世界法线/切线/手性输出和保守裁剪分类 |
| `Rasterizer` | 包围盒、边函数、top-left 覆盖、重心坐标、透视权重和基础面剔除 |
| `Texture2D` | PPM P3/P6 纹理加载、8/16 位归一化、Clamp/Repeat 最近邻 UV 采样 |
| `Material` | 基础色因子/贴图、金属粗糙度 G/B 打包贴图、独立采样状态和片元材质组装 |
| `Shading` | Lambert、GGX NDF、Smith 遮蔽、金属粗糙度直接光照、曝光、Reinhard 和 sRGB 编解码 |
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
- 漫反射在线性空间计算：`diffuse = albedo × radiance × max(N·L, 0) / π`，其中 `L` 从表面指向光源。
- 简化 GGX 使用感知粗糙度、Trowbridge-Reitz NDF、Schlick-GGX Smith 几何项和 Schlick Fresnel；`F0 = lerp(0.04, baseColor, metallic)`。
- 材质工作流先将 sRGB 基础色贴图解码到线性空间并乘 RGBA 因子；线性打包贴图使用 G 通道粗糙度、B 通道金属度，再分别乘材质因子。
- 曝光档位 `EV` 使用乘数 `2^EV`；显示输出依次执行曝光、Reinhard 色调映射和线性到 sRGB 编码。

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
./build/Debug/texture_sampling_acceptance.exe
./build/Debug/surface_attributes_acceptance.exe
./build/Debug/diffuse_exposure_acceptance.exe
./build/Debug/ggx_brdf_acceptance.exe
./build/Debug/material_workflow_acceptance.exe
./build/Debug/release_acceptance.exe ./build/release_acceptance.ppm
ctest --test-dir build -C Debug --output-on-failure
```

### MinGW-w64

仍以 CMake 清单为唯一构建来源，不再维护容易失效的逐文件命令：

```powershell
cmake -S . -B build-mingw -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Debug
cmake --build build-mingw --parallel
ctest --test-dir build-mingw --output-on-failure
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

OBJ 读取、顶点着色、三角形覆盖、深度缓冲、纹理/UV 采样、法线/切线数据、Lambert 漫反射、曝光/色调映射、简化 GGX、纹理驱动金属粗糙度，以及三组材质回归与发布验收均已按日程完成。本版本仍明确不做阴影、抗锯齿和次表面散射。

## 发布验收

`release_acceptance` 在 `96×32` framebuffer 中渲染哑光介电、粗糙金属和光滑金属三栏基准。验收固定 `1872` 个材质像素、中心 RGB8、背景色、深度和整图 FNV-1a64 `0x6e50ef105c6d04c`，并写出 `build/release_acceptance.ppm`。

构建成功且 CTest `12/12` 通过后，v1.0 发布门禁才算通过。完整命令、流水线原理、材质参数、发布边界与验收记录见 [CPU 软渲染器 v1.0 发布验收](docs/RELEASE_ACCEPTANCE.md)。

## Unity 工程与资产导入

`UnityMaterialLab` 使用 Editor Bootstrap 统一导入 CC0 展示箱：模型按米制、源法线、MikkTSpace 切线、自动 Lightmap UV、禁用源材质；基础色 PNG 按 sRGB、Repeat、Bilinear、MipMap 导入。Bootstrap 生成五个材质球、导入资产 Prefab、场景、Build Settings、960×540 基线截图和 JSON 报告。

在没有 Unity Editor 许可证时可运行 `UnityMaterialLab/Tools/StaticValidate.ps1`，它会完成工程结构、资产内容、输入契约、实例范围、命名和离线 C# 编译检查。当前机器的 Unity Editor 批处理验收仍可能被本地许可证阻塞，证据和解锁步骤见 `UnityMaterialLab/Reports/EDITOR_VALIDATION_BLOCKED.md`；静态 PASS 不替代 Editor 场景 PASS。

材质边界验收额外固定 Metallic `0/0.5/1`、Roughness `0/0.25/0.5/0.75/1`、Normal Scale `0/1/2`。静态报告校验所有样例的范围、`smoothness`、GGX `alpha` 和介电权重，并生成可直接查看的对比板。

URP Forward 的 BasePass 调试材质现提供 10 档表面/光照视图，并固定 `FinalLit = DirectDiffuse + DirectSpecular + IndirectDiffuse` 的线性 HDR 加法关系。使用 Unity 菜单可生成两行五列对照场景；无许可证时可运行离线公式板和静态门禁。完整模式、捕获检查点与验收命令见 [Unity BasePass 与光照拆解](docs/UNITY_BASEPASS_LIGHTING_DECOMPOSITION.md)。

Renderer 侧共享 HLSL 已拆分为 Types、Common、Vector、Sampling、PBRInput、BRDF、Lighting、DebugViews 八个模块，并由 `TA_ShaderLibrary.hlsl` 稳定聚合。BRDF 模块现在明确分离 GGX alpha/NDF、Smith lambda/相关遮蔽和标量/向量 Fresnel；模块边界见 [Unity HLSL 源码库骨架](docs/UNITY_HLSL_SOURCE_LIBRARY.md)，输入策略见 [Unity 简化 PBR 输入层](docs/UNITY_SIMPLIFIED_PBR_INPUT_LAYER.md)，NDF 契约见 [Unity GGX 法线分布](docs/UNITY_GGX_NORMAL_DISTRIBUTION.md)，几何与 Fresnel 契约见 [Unity 几何遮蔽与 Fresnel](docs/UNITY_GGX_GEOMETRY_FRESNEL.md)。

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

### 漫反射与显示变换

```cpp
#include "Shading.hpp"

SoftRenderer::Shading::DirectionalLight light;
light.directionToLight = Vec3(0.0, 0.0, 1.0);
light.radiance = Vec3(3.141592653589793, 3.141592653589793, 3.141592653589793);

Vec3 linearAlbedo = SoftRenderer::Shading::srgbToLinear(Vec3(0.8, 0.4, 0.2));
Vec3 hdr = SoftRenderer::Shading::lambertDiffuse(
    linearAlbedo,
    Vec3(0.0, 0.0, 1.0),
    light
);
SoftRenderer::Color display = SoftRenderer::Shading::toDisplayColor(hdr, 1.0);
```

纹理颜色先从 sRGB 解码到线性空间，再参与 Lambert 光照；HDR 结果按 EV 曝光并经 Reinhard 压缩后编码回 sRGB。`Framebuffer` 仍接受有限 HDR 值，显示变换由调用方显式执行。

### 简化 GGX BRDF

```cpp
SoftRenderer::Shading::MetallicRoughnessMaterial material{
    Vec3(0.8, 0.4, 0.2),
    0.0,
    0.5
};
Vec3 hdr = SoftRenderer::Shading::ggxDirectLighting(
    material,
    Vec3(0.0, 0.0, 1.0),
    Vec3(0.0, 0.0, 1.0),
    light
);
```

`baseColor` 必须是线性颜色，`metallic` 与感知 `roughness` 均位于 `[0,1]`。视线方向从表面指向相机；纯介电材质使用 `F0 = 0.04` 并保留漫反射，纯金属使用有色 `baseColor` 作为 `F0` 且漫反射归零。

### 金属粗糙度材质采样

```cpp
#include "Material.hpp"

SoftRenderer::Material::MetallicRoughnessDefinition definition;
definition.baseColorFactor = {0.8, 0.5, 0.25, 1.0};
definition.metallicFactor = 0.9;
definition.roughnessFactor = 0.6;
definition.baseColorTexture = &baseColorTexture;
definition.metallicRoughnessTexture = &metallicRoughnessTexture;

auto sample = SoftRenderer::Material::sampleMetallicRoughness(definition, uv);
Vec3 hdr = SoftRenderer::Shading::ggxDirectLighting(
    sample.shading,
    normal,
    directionToView,
    light
);
```

`MetallicRoughnessDefinition` 不持有纹理对象，调用期间纹理必须保持有效。基础色因子为线性 RGBA；基础色贴图 RGB 按 sRGB 解码，Alpha 保持线性。金属粗糙度贴图不做 sRGB 转换，其 R/A 通道当前保留不用。

## 项目结构

```text
.
├── apps/                       # 可运行示例入口
├── cmake/                      # 公共 CMake 目标配置
├── src/                        # graphics_math / software_renderer 库源码
├── tests/
│   ├── acceptance/             # 10 个阶段验收入口
│   └── data/                   # 固定测试数据
├── Tools/                      # 跨工程自动化与可视化工具
├── docs/                       # 范围、验收与结构说明
├── output/                     # 受版本控制的阶段报告与参考图
├── UnityMaterialLab/           # 独立 Unity URP 工程
├── CMakeLists.txt
├── README.md
└── ISSUES.md
```

目录职责、依赖方向和新增文件规则见 [项目结构约定](docs/PROJECT_STRUCTURE.md)。

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
- `VertexStage` 保留 OBJ 角点索引，输出完整位置路径、`reciprocalW`、UV、世界法线、世界切线和 `tangentSign`；`RequiresClipping` 只标记待裁剪。
- 缺失 OBJ 法线默认使用三角形几何法线，可通过 `generateMissingNormals` 关闭；该回退是平面法线，不做跨三角形平滑平均。
- 切线按三角形位置与 UV 导数逐角点生成，并针对角点法线正交化；镜像 UV 或反射模型变换会通过 `tangentSign` 保留手性。
- UV 缺失、UV 导数退化或几何基无法定义时 `hasTangent=false`，不会用任意轴伪造切线。
- 片元法线/切线应使用 `RasterSample::interpolatePerspective` 插值，再归一化并通过 `TangentSpace::buildTBN` 重建正交基。
- `Rasterizer` 在像素中心采样并采用 top-left 共享边规则；线性重心坐标用于屏幕深度，`barycentric[i] * reciprocalW[i]` 归一化后用于透视正确属性插值。
- `Rasterizer` 只接收 `FullyInside` 三角形；`FullyOutside` 不产生样本，`RequiresClipping` 必须先经过后续几何裁剪阶段。
- `RasterizerOptions` 默认不剔除；启用背面剔除时，左上原点屏幕坐标默认以顺时针为正面，也可切换为逆时针或前面剔除。
- `Texture2D` 支持 PPM `P3`/`P6`、最大 16 位通道，加载后统一为顶部起始行主序 `[0,1]` RGBA；当前不宣称支持 PNG/JPEG。
- PPM 通道加载时仅做数值归一化；颜色纹理参与光照前应调用 `Shading::srgbToLinear`，不可直接在 sRGB 空间计算光照。
- UV 采样默认使用 OBJ/OpenGL 风格左下原点与 Clamp，可配置 Repeat 或顶部原点；边界 `1.0` 会安全落到最后一个 texel。
- 应先用 `RasterSample::interpolatePerspective` 插值 UV，再调用 `sampleNearest`；直接用线性重心坐标会产生透视纹理形变。
- `Shading::lambertDiffuse` 会归一化法线和光照方向，并拒绝非法反照率、负辐亮度及零方向；它返回未做曝光的线性 HDR 结果。
- `Shading::ggxDirectLighting` 使用从表面指向相机/光源的方向；视线或光线位于表面背面时返回零，粗糙度零端通过最小 `alpha = 1e-4` 保持有限。
- 金属粗糙度工作流对漫反射应用 `(1-F)(1-metallic)` 能量权重；不要再额外叠加一次独立 Lambert 项。
- `Material::sampleMetallicRoughness` 先验证 UV/因子，再分别使用基础色与打包贴图的采样状态；默认因子均为 `1`，未绑定贴图时直接输出因子值。
- 基础色贴图必须按 sRGB 解码，金属粗糙度贴图必须保持线性；对 G/B 数据做伽马转换会改变实际粗糙度和金属度。
- `ImageIO::encodePpmRgb8` 忽略 Alpha，将有限 RGB 夹到 `[0,1]` 并四舍五入为 8 位；`writePpmRgb8` 以二进制 P6 写出且拒绝空路径。
- 发布 checksum 覆盖 PPM 头和全部 RGB 字节；修改光照、材质、色调映射、覆盖规则或量化方式时，必须人工确认图像后显式更新基准。
- `Shading::toDisplayColor` 固定执行曝光 → Reinhard → sRGB 编码；色调映射之前不要截断 HDR，也不要对已经编码的 sRGB 颜色重复编码。
- `Tools/GenerateHandednessPlot.py` 用于生成左右手坐标系示意图，输出位于 `output/handedness.png`。
- 已知问题和后续计划记录在 [ISSUES.md](ISSUES.md) 中。
## Direct-light PBR integration

The Unity BasePass now uses a reusable direct-light PBR entry point with energy-conserving `(1-F)` diffuse weighting, GGX/Smith/Fresnel specular integration and a back-face zero guard. See [Unity Direct-Light PBR Integration](docs/UNITY_DIRECT_LIGHT_PBR_INTEGRATION.md) for the contract, fixed outputs and offline acceptance commands.

## PBR parameter regression

Unity now has a 12-fixture direct-light parameter regression covering Metallic/Roughness sweeps, input clamping and tilted normals. See [Unity PBR 参数回归](docs/UNITY_PBR_PARAMETER_REGRESSION.md) and `UnityMaterialLab/Reports/PbrParameterRegressionValidation.json`.
