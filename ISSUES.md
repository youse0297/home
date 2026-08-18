# Issues & TODOs

## ✅ 已修复问题 (Fixed)

| 编号 | 问题描述 | 修复日期 | 备注 |
| :--- | :--- | :--- | :--- |
| #1 | `Vec2` 类缺少 `cross` 成员函数，导致 `VectorUtils::side` 编译失败 | 2026-07-17 | 已在 `Vec2.hpp/cpp` 中添加 `cross` |
| #2 | `Vec3` 类缺少 `cross` 成员函数 | 2026-07-17 | 已在 `Vec3.hpp/cpp` 中添加 `cross` |
| #3 | 使用 `std::setprecision` 未包含 `<iomanip>` 头文件 | 2026-07-17 | 已在 `main.cpp` 中添加 `#include <iomanip>` |
| #4 | 函数名大小写错误：`Angle` 应为 `angle` | 2026-07-17 | 统一使用小写 `angle` |
| #5 | Windows 控制台中文乱码（UTF-8 vs GBK） | 2026-07-17 | 通过 `SetConsoleOutputCP(CP_UTF8)` 解决，或改用英文输出 |
| #6 | 错误的变量类型声明：`Vec4 B = A * I;` 报错（`Mat4` 无法转换为 `Vec4`） | 2026-07-17 | 修正为 `Mat4 B = A * I;`，已补充文档说明 |
| #7 | 变换矩阵工厂函数缺失（平移、缩放、旋转） | 2026-07-18 | 已新增 `Transform` 命名空间和相关函数 |
| #8 | 相机视图矩阵 `Camera::lookAt` 未实现 | 2026-07-20 | 已新增 Camera 命名空间，支持右手系 lookAt 矩阵生成 |
| #9 | 示例依赖非标准 `M_PI`，并直接包含 Windows 头文件 | 2026-07-25 | 已改用内部 `constexpr pi`，Windows 控制台设置增加平台条件编译 |
| #23 | 缺少配合 Camera 模块使用的透视投影矩阵 | 2026-07-24 | 已新增 `Projection.hpp/cpp` 和 `Camera::perspective`，采用右手系、OpenGL 风格 NDC |
| #24 | `Camera::lookAt` 的旋转基向量按列写入且 Z 平移符号错误 | 2026-07-25 | 已按世界到观察空间的行基向量布局修正，并补充退化参数检查 |
| #25 | 缺少完整 MVP、齐次除法、裁剪体判断和视口映射 | 2026-07-25 | 已新增 `Pipeline.hpp/cpp`，支持左上/左下原点和可配置深度范围 |
| #26 | 非均匀缩放下直接用模型矩阵变换法线会破坏垂直关系 | 2026-07-25 | 已新增 `Mat3` 和逆转置法线矩阵，固定错误案例 `T·N ≈ 0.8824` |
| #27 | 缺少正交 TBN 构建与切线/世界空间转换 | 2026-07-25 | 已新增 `TangentSpace.hpp/cpp`，支持 Gram-Schmidt、手性符号和双向映射 |
| #28 | 缺少 Fresnel 基础反射率与视角相关近似 | 2026-07-26 | 已新增 `Fresnel.hpp/cpp`，支持介电材质 `F0`、标量/RGB Schlick 近似和输入校验 |
| #29 | 图形数学阶段缺少统一、可重复执行的综合验收 | 2026-07-26 | 已补齐 4 组固定数值套件、统一 PASS 汇总和 CTest 验收入口，并拒绝非有限数值 |
| #30 | 软渲染器缺少 framebuffer、颜色/深度缓冲、渲染循环与冻结范围 | 2026-07-26 | 已新增 `Framebuffer`、`SoftwareRenderer`、独立骨架验收和范围清单；明确排除阴影、抗锯齿、次表面 |
| #31 | 缺少 OBJ 顶点属性、面索引和异常输入读取 | 2026-07-27 | 已新增 `ObjLoader`，支持四种面格式、正负索引、缺省属性、多边形三角化和结构化 `ObjParseError` |
| #32 | OBJ 网格尚未进入 MVP 顶点阶段并输出屏幕空间三角形 | 2026-07-28 | 已新增 `VertexStage`，保留角点索引与 `1/w`，输出完整坐标并区分三种裁剪状态 |
| #33 | 缺少三角形像素覆盖、重心坐标和透视正确属性插值 | 2026-07-29 | 已新增 `Rasterizer`，实现包围盒、边函数、top-left 规则、双绕序覆盖与透视权重 |
| #34 | 深度缓冲只能存取，缺少遮挡测试、顺序无关验证和基础面剔除 | 2026-07-30 | 已新增严格 `Less` 深度测试、原子片元写入、近远顺序回归及可配置正背面剔除 |
| #35 | 缺少纹理文件加载、UV 寻址及透视正确纹理采样 | 2026-07-31 | 已新增 `Texture2D`，支持 PPM P3/P6、8/16 位通道、Clamp/Repeat 和上下原点约定 |
| #36 | OBJ 法线/UV 索引尚未形成可插值的世界法线、切线与手性数据 | 2026-08-01 | 已扩展 `VertexStage`，支持几何法线回退、UV 导数切线、逆转置变换及镜像/反射手性 |
| #37 | 缺少线性空间 Lambert 漫反射、曝光/色调映射及 sRGB 输入输出转换 | 2026-08-02 | 已新增 `Shading` 与固定验收，贯通纹理、法线、光照、显示变换和 framebuffer 片元路径 |
| #38 | 缺少 GGX 微表面高光、几何遮蔽及金属粗糙度直接光工作流 | 2026-08-03 | 已扩展 `Shading`，加入 GGX NDF、Schlick-GGX Smith、金属度 F0 混合、能量权重和完整片元验收 |
| #39 | GGX 仅接受常量材质参数，缺少纹理通道、因子组合和统一片元材质组装 | 2026-08-05 | 已新增 `Material`，支持 sRGB 基础色、线性 G/B 金属粗糙度贴图、独立采样状态、Alpha 与端到端验收 |
| #40 | 缺少可发布图像写出、三材质回归、整图确定性基准和统一发布门禁 | 2026-08-08 | 已新增 `ImageIO`、`release_acceptance`、P6 产物、代表 RGB/覆盖/深度/FNV checksum 与 12 项 CTest 清单 |
| #41 | 缺少 Unity URP 测试工程、统一资产导入规则、材质球 Prefab 和可复现导入验收 | 2026-08-08 | 已新增 `UnityMaterialLab`、CC0 OBJ/PNG、Editor Bootstrap、静态 C# 编译/结构验收；Editor 运行验收等待本机许可证激活 |
| #42 | 缺少 Unity BaseColor/Normal/ORM 输入契约、基础 PBR 主材质和三个可复用实例 | 2026-08-08 | 已新增 `MaterialInputProfile`、线性 Normal/ORM 输入、PBR 主材质与三个 Profile/材质实例；静态验收覆盖纹理引用、通道约定和参数范围 |
| #43 | 缺少 Unity Metallic/Roughness/Normal Scale 参数边界矩阵、可视对比板和物理合理性结论 | 2026-08-13 | 已新增 11 组固定基准、`MaterialBoundaryMatrix`、Editor 对比场景生成器、静态 PNG 板及公式/范围验收 |
| #44 | 缺少可复用的 Shader Graph File 模式 Custom Function、纹理结构体端口契约及精度变体 | 2026-08-13 | 已新增 `TA_CustomFunctions.hlsl`、`float`/`half` 变体、`UnityTexture2D` 采样、示例子图生成器和静态接口验收 |
| #45 | 缺少可复用的 Unity 材质函数库，UV、法线、通道与颜色逻辑散落在单一节点 | 2026-08-13 | 已新增 4 个 HLSL 模块、6 个精度变体函数、聚合入口、固定数值基准、示例清单和静态验收 |
| #46 | 缺少按贴图语义选择的 Standalone 压缩格式、显存对照和质量留痕 | 2026-08-13 | 已新增 BaseColor=BC7、Normal=BC5、ORM=BC1 策略、BC1 实际往返误差、显存矩阵和对照截图 |
| #47 | 缺少可复现的 LOD 屏幕阈值、切换样本和场景记录 | 2026-08-14 | 已新增三档 `LodPolicy`、四个固定切换样本、LODGroup CrossFade 场景生成器、JSON 基准与 1440x900 对比图 |
| #48 | 缺少可重复的 Unity RenderDoc 截帧入口、GPU 事件书签和工具状态记录 | 2026-08-14 | 已新增 URP marker Renderer Feature、固定 1280x720 捕获配置、六个 `RD/*` 书签、RenderDoc readiness 检查和 `.rdc` 归档说明；真实捕获待本机安装 RenderDoc 并激活 Unity 许可证 |
| #49 | 缺少 URP Forward BasePass 的表面通道、直接/间接光与阴影衰减拆解视图 | 2026-08-16 | 已新增 10 档调试 Shader、MaterialPropertyBlock 控制器、对照场景生成器、固定 GGX/SH 数值板与加法不变量验收 |
| #50 | 阶段 1 的 CPU 发布门禁与 Unity 离线/运行门禁分散，缺少统一结论和阻塞证据 | 2026-08-16 | 已新增 `RunStage1Acceptance.ps1`，统一执行构建、CTest、Unity 离线报告与外部工具检查，输出 JSON/Markdown 总报告并区分 PASS、CONDITIONAL_PASS、FAIL |
| #51 | C++ 库、演示入口、验收程序和工具脚本混放在 `src/`，顶层 CMake 重复维护目标配置 | 2026-08-16 | 已拆分 `src/apps/tests/acceptance/cmake/Tools` 职责，建立分层 CMake、稳定目标别名、统一编译选项和项目结构约定 |
| #52 | BasePass 的 BRDF、光照合成和调试视图内联在单个 Shader，缺少 Renderer 侧 HLSL 模块边界与稳定聚合入口 | 2026-08-16 | 已建立 Types/Common/BRDF/Lighting/DebugViews 五层源码库、`TA_` 公共接口、聚合头、机器可读契约和专项静态验收 |
| #53 | Renderer Shader 仍直接调用 UV、纹理宏、法线解包、叉积与 TBN 变换，缺少统一的向量和采样接口 | 2026-08-17 | 已新增 Vector/Sampling 模块、跨平台纹理参数宏封装、平台法线解包、镜像手性 TBN、9 组数值基准和 BasePass 实际接入 |
| #54 | BasePass 仍在消费端直接组装 BaseColor、Normal、ORM、AO、粗糙度和金属度，缺少统一的简化 PBR 输入层 | 2026-08-18 | 已新增 `TA_PBRInputConfig`/`TA_PBRInputData`、采样与材质边界组装、`TA_BuildSurfaceData`、3 组固定边界样例和 BasePass 委托验收 |

## 🔴 待解决 / 待验证 (Open)

| 编号 | 问题描述 | 优先级 | 状态 |
| :--- | :--- | :--- | :--- |
| #10 | 未实现 `cross` 的 `constexpr` 或 `noexcept` 优化 | 低 | 考虑加入 |
| #11 | 投影函数在 `b` 为零向量时返回零向量，但调用方可能未检查 | 低 | 可添加日志或断言 |
| #12 | Mat4 的 `operator<<` 输出格式可能不统一（跨平台显示） | 低 | 可改进 |
| #13 | `rotationAxis` 未检查轴是否归一化，可能导致非单位旋转 | 中 | 可增加断言或自动归一化 |
| #14 | `Camera::lookAt` 未支持左手系切换，当前固定为右手系 | 中 | 可结合 `g_handedness` 适配 |

## 💡 未来改进建议 (Future Enhancements)

| 编号 | 建议 | 优先级 | 备注 |
| :--- | :--- | :--- | :--- |
| #15 | 将 `Vec2` 和 `Vec3` 合并为模板类 `Vec<T, N>`，减少代码重复 | 中 | 需重构项目结构 |
| #16 | 添加四元数支持 | 中 | 可用于平滑插值 |
| #17 | 添加单元测试（如 Google Test） | 高 | 提高可靠性 |
| #18 | 增加 `std::hash` 支持，便于作为 `unordered_map` 键 | 低 | 可选 |
| #19 | 提供 `lerp`（线性插值）、反射等高级几何函数 | 中 | 可放入 `VectorUtils` |
| #20 | 添加正交投影矩阵 | 中 | 与现有透视投影共同完善图形学功能 |
| #21 | 支持 Mat4 与 Vec3 的直接运算（自动提升为 Vec4） | 低 | 可增加重载 |
| #22 | 添加变换组合的缓存或优化（避免重复构建矩阵） | 低 | 性能优化 |

## 📌 注意事项

- 当前坐标系默认为右手系，可通过 `g_handedness` 全局变量切换。
- 使用 `Vec2Utils::side` 或 `Vec3Utils::side` 时，请确保 `g_handedness` 设置正确。
- 所有输出示例均以 `std::fixed << std::setprecision(4)` 格式化，如需不同精度可调整。
- **矩阵存储为列主序**（Column-Major），与 OpenGL 一致。`Mat4 * Vec4` 为列向量乘法，`Vec4 * Mat4` 为行向量乘法（左乘）。
- `Mat4` 默认构造函数生成**零矩阵**，使用单位矩阵请调用 `Mat4::identity()`。
- 变换组合顺序：`T * R * S` 表示先缩放、再旋转、最后平移（应用顺序从右向左）。
- `Transform::rotationAxis` 需要轴向量归一化，否则会产生非标准旋转。
- `Camera::lookAt` 当前仅支持右手系，相机看向 -Z 方向，forward 向量为 eye - target。
- `Camera::perspective` 当前使用右手系和 OpenGL 风格 NDC（Z 范围 `[-1, 1]`），且要求 `0 < zNear < zFar`。
- `Pipeline::composeMVP` 返回 `Projection * View * Model`，与列向量乘法约定一致。
- 默认视口采用左上角原点，NDC 深度 `[-1, 1]` 映射到屏幕深度 `[0, 1]`。
- 固定基准为 1280×720 视口，测试顶点最终屏幕坐标应为 `(712, 360, 0.8889)`。
- 法线矩阵只使用模型矩阵左上 3×3 线性部分，并计算其逆转置；零缩放会被视为奇异矩阵。
- TBN 的列依次为切线、副切线、法线；固定基准要求 `T·N = 0` 且 `det(TBN) = 1`。
- Fresnel 基准使用空气到玻璃的折射率 `1.0 → 1.5`，应得到 `F0 = 0.04`；Schlick 近似在掠射角趋近 `1.0`。
- 软渲染器 framebuffer 使用左上原点、行主序 RGBA 和 `[0, 1]` 深度；当前骨架不包含光栅化与深度比较。
- OBJ 加载结果使用零基索引；负索引相对当前属性池解析，缺省 UV/法线通过哨兵值保留，解析异常携带来源和行号。
- 顶点阶段缓存共享位置的变换结果，输出完整 MVP 路径、屏幕坐标与 `1/w`，仅做保守裁剪分类。
- 光栅化阶段以像素中心采样，使用 top-left 规则消除共享边重复覆盖，并分别输出线性重心权重和透视正确权重。
- `RequiresClipping` 三角形必须在几何裁剪后再进入 `Rasterizer`；当前阶段不会隐式修改拓扑。
- 深度缓冲使用 `[0, 1]` 和严格 `Less`；`writeFragment` 保证测试通过时颜色与深度同时提交，遮挡结果不依赖近远三角形绘制顺序。
- 面剔除默认关闭；启用背面剔除时默认顺时针为正面，也可配置逆时针正面或前面剔除。
- 纹理加载当前明确支持 PPM P3/P6（含 16 位大端通道），统一归一化到 `[0,1]` RGBA；PNG/JPEG 不在本阶段范围。
- UV 默认左下原点和 Clamp，可配置 Repeat/顶部原点；纹理查询使用光栅样本的透视正确权重。
- `VertexStage` 输出可选 UV、单位世界法线/切线和 `tangentSign`；缺失法线默认使用每三角形几何法线，UV 无效时不生成切线。
- 非均匀缩放下法线使用逆转置、切线使用模型线性部分；镜像 UV 与反射变换的组合手性在世界空间重新判定。
- 片元法线与切线需透视插值后重新归一化、正交化，不能直接插值并使用顶点 TBN 矩阵。
- 颜色纹理参与光照前需从 sRGB 解码到线性空间；Lambert 结果保持 HDR，显示前再按 EV 曝光、Reinhard 色调映射并编码回 sRGB。
- 方向光接口使用“表面指向光源”的方向，观察方向使用“表面指向相机”；简化 GGX 已采用感知粗糙度、Schlick-GGX Smith 和金属度 F0 混合。
- GGX 的零粗糙度通过 `alpha = max(roughness², 1e-4)` 保持数值稳定；当前仅覆盖单方向光，不包含阴影或 IBL。
- `Material` 使用非持有纹理指针；基础色纹理执行 sRGB 解码，金属粗糙度贴图保持线性并采用 G=粗糙度、B=金属度约定。
- 基础色与金属粗糙度纹理可使用独立采样状态；当前保留打包贴图 R/A 通道，不执行 Alpha 裁剪或混合。
- v1.0 发布图固定为 `96×32` 三材质法线梯度场景，覆盖 `1872` 像素，完整 PPM FNV-1a64 为 `0x6e50ef105c6d04c`。
- 发布门禁要求 CMake Debug 构建成功、CTest `12/12` 通过、P6 写出逐字节一致；详细记录见 `docs/RELEASE_ACCEPTANCE.md`。
- Unity 导入工程固定 Editor `2022.3.62f3c1`、URP `14.0.12`，源模型/贴图命名分别使用 `SM_`/`T_`，材质/Prefab/场景使用 `MAT_`/`PF_`/`SCN_`。
- Unity 材质输入固定 BaseColor=sRGB、Normal/ORM=Linear；ORM 通道为 R=AO、G=roughness、B=metallic，三个实例 Profile 的 `metallic/roughness` 范围为 `[0,1]`。
- Unity 参数边界固定 Metallic `0/0.5/1`、Roughness `0/0.25/0.5/0.75/1`、Normal Scale `0/1/2`；中间金属度只表示过渡，Normal Scale `2` 为验证上限。
- Unity Editor 批处理会分别检查 `com.unity.editor.headless`，普通 Editor 会检查 `com.unity.editor.ui`；两者均缺失时只能报告静态验收 PASS 和运行验收 BLOCKED_LICENSE。

## 如何贡献

如果你发现了新的问题或有改进建议，请在本文件中添加一条记录，或直接在代码仓库中提 Issue / PR。

---

*最后更新：2026-08-08*
