# CPU 软渲染器 v1.0 发布验收

## 发布结论

v1.0 发布门禁定义为：Debug 构建成功、CTest `12/12` 通过、三组材质基准图满足固定覆盖率/代表色/checksum，并成功写出 P6 RGB8 文件。本轮验收日期为 2026-08-08，目标平台为 Windows x64 + MSVC，结论为 **PASS**。

## 构建与运行

在项目根目录执行：

```powershell
cmake -S . -B build
cmake --build build --config Debug --parallel
ctest --test-dir build -C Debug --output-on-failure
./build/Debug/release_acceptance.exe ./build/release_acceptance.ppm
```

发布图输出到 `build/release_acceptance.ppm`。最后一条命令应输出 `Software renderer release acceptance: PASS` 并以退出码 `0` 结束。

## 工作原理

发布场景使用一张内存 OBJ 网格构成三栏矩形，每栏由两个共享边三角形组成。四角法线在片元阶段做透视正确插值并重新归一化，使同一栏内形成连续高光梯度。

片元路径固定为：OBJ 装配 → MVP/视口变换 → top-left 光栅覆盖 → 深度测试 → UV/法线透视插值 → sRGB 基础色与线性 G/B 金属粗糙度采样 → 简化 GGX 直接光 → `-1 EV` → Reinhard → sRGB → framebuffer → P6 RGB8。

P6 导出会把有限 RGB 通道夹到 `[0,1]`，再使用四舍五入量化到 `[0,255]`；Alpha 不写入 PPM。整图字节（包含 PPM 头）使用 FNV-1a 64 位校验，锁定可发布输出。

## 材质回归

| 区域 | 基础色纹理 | 金属度 | 粗糙度 | 中心 RGB8 |
| --- | --- | ---: | ---: | --- |
| 左：哑光介电 | `(204,64,32)` sRGB | `0` | `1.0` | `(157,60,35)` |
| 中：粗糙金属 | `(230,170,50)` sRGB | `1` | `166/255` | `(174,138,43)` |
| 右：光滑金属 | `(230,170,50)` sRGB | `1` | `51/255` | `(151,115,32)` |

固定画布为 `96×32`，材质覆盖 `1872` 个像素，写入深度为 `0.5 ± 1e-12`，背景 RGB8 为 `(5,6,8)`，整图 FNV-1a64 为 `0x6e50ef105c6d04c`。

## CTest 门禁

发布要求以下 12 个测试全部通过：

1. `graphics_math_acceptance`
2. `software_renderer_skeleton_acceptance`
3. `obj_vertex_data_acceptance`
4. `vertex_shading_stage_acceptance`
5. `triangle_rasterizer_acceptance`
6. `depth_buffer_acceptance`
7. `texture_sampling_acceptance`
8. `surface_attributes_acceptance`
9. `diffuse_exposure_acceptance`
10. `ggx_brdf_acceptance`
11. `material_workflow_acceptance`
12. `release_acceptance`

## 发布边界

v1.0 是单样本、单方向光、最近邻纹理和简化直接光 PBR 基线。阴影、抗锯齿、IBL、Alpha 裁剪/混合、PNG/JPEG、mipmap 和次表面散射不属于本次发布承诺。
