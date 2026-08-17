# Unity 向量与采样工具函数

本日程项为 Renderer 侧 HLSL 源码库补齐向量、切线空间和纹理采样工具，并让 `TA_BasePassLightingDecomposition.shader` 实际消费这些接口。目标是统一空间变换与 Unity 纹理宏的调用方式，不改变原有 BasePass 的材质输入或光照结果。

## 向量工具

`Assets/_TA/Shaders/Library/TA_Vector.hlsl` 提供：

| 函数 | 作用 |
| --- | --- |
| `TA_SafeNormalize` | 使用固定分母下限避免零向量产生 NaN；零输入保持零 |
| `TA_EncodeNormalWS` | 归一化世界法线并映射到 `[0, 1]` 调试颜色 |
| `TA_BuildBitangentWS` | 按 `tangentSign * cross(normal, tangent)` 保留镜像 UV 手性 |
| `TA_BuildTangentToWorld` | 以 Tangent、Bitangent、Normal 三行构造 TBN |
| `TA_TransformTangentToWorld` | 使用 `mul(vectorTS, tangentToWorld)` 转换并安全归一化 |

切线 `w` 同时包含网格切线手性与 `GetOddNegativeScale()`，因此负缩放和镜像 UV 不应在工具函数外再次翻转副切线。输入法线与切线来自 Unity `GetVertexNormalInputs`；工具函数不替代顶点阶段的逆转置法线处理。

## 采样工具

`Assets/_TA/Shaders/Library/TA_Sampling.hlsl` 提供：

| 函数 | 作用 |
| --- | --- |
| `TA_TransformUV` | 应用 Unity `_ST` 的 `uv * scale + offset` |
| `TA_SampleTexture2D` | 通过 `SAMPLE_TEXTURE2D` 执行普通采样 |
| `TA_SampleTexture2DLod` | 通过 `SAMPLE_TEXTURE2D_LOD` 执行显式 mip 采样 |
| `TA_SampleNormalTS` | 采样后委托 `UnpackNormalScale` 处理平台法线编码和强度 |
| `TA_SampleORM` | 采样并将 R=AO、G=roughness、B=metallic 限制到 `[0, 1]` |

纹理参数必须使用 `TEXTURE2D_PARAM` 与 `TEXTURE2D_ARGS`，不能直接写死 `Texture2D`/`SamplerState` 参数，因为 GLES2 会把纹理与采样器折叠为单一 `sampler2D`。消费 Shader 必须先包含 URP `Core.hlsl`，再包含 `TA_ShaderLibrary.hlsl`，以提供纹理宏和 `UnpackNormalScale`。

这些函数不负责颜色空间转换。BaseColor 是否按 sRGB 解码、Normal 是否按 Normal Map 导入、ORM 是否保持 Linear，仍由 Unity 纹理导入设置决定。

## BasePass 接入

BasePass 当前统一使用：

```hlsl
output.uv = TA_TransformUV(input.uv, _BaseMap_ST);
half4 baseSample = TA_SampleTexture2D(TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap), input.uv);
half3 normalTS = TA_SampleNormalTS(TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), input.uv, _BumpScale);
half3 normalWS = TA_TransformTangentToWorld(normalTS, input.normalWS, input.tangentWS);
half3 orm = TA_SampleORM(TEXTURE2D_ARGS(_ORMMap, sampler_ORMMap), input.uv);
```

采样工具只收口读取与解码；AO 强度、粗糙度下限、金属度缩放和 BaseColor Tint 仍属于表面材质组装职责。

## 验收

在 `UnityMaterialLab` 目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateVectorSamplingUtilities.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateHlslSourceLibrary.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

专项契约位于 `Assets/_TA/Documentation/VectorSamplingUtilities.json`。9 组固定样例覆盖安全归一化、法线编码、正/负手性副切线、TBN、切线向量转换、UV ST 与 ORM 限制；源码检查覆盖 10 个公共函数、Unity 纹理宏、平台法线解包和 BasePass 接线。报告写入 `Reports/VectorSamplingUtilitiesValidation.json`。

静态 `PASS` 不能替代 Unity Editor shader 编译。最终运行验收仍需检查 BasePass 无编译错误、法线方向正确、镜像 UV 无翻转且各调试视图与原基准一致。
