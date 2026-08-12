# Shader Graph Custom Function 节点

## 交付物

- HLSL 文件：`UnityMaterialLab/Assets/_TA/ShaderGraph/TA_CustomFunctions.hlsl`
- 端口契约：`UnityMaterialLab/Assets/_TA/Documentation/ShaderGraphCustomFunctionContract.json`
- 示例生成器：`UnityMaterialLab/Assets/_TA/Editor/ShaderGraphCustomFunctionBootstrap.cs`

在 Unity 中执行 `TA/Material Lab/Create Custom Function Example`，会生成
`Assets/_TA/ShaderGraph/SG_CustomFunctionExample.shadersubgraph`。该子图保存一个
File 模式的 Custom Function 节点；函数名填 `TA_SampleMaterialInputs`，不要手动追加
`_float` 或 `_half`。

## 端口契约

| 方向 | 名称 | 类型 | 说明 |
| --- | --- | --- | --- |
| 输入 | `BaseColorTex` | Texture2D | sRGB 基础色 |
| 输入 | `NormalTex` | Texture2D | Linear 切线空间法线 |
| 输入 | `OrmTex` | Texture2D | Linear；R=AO、G=roughness、B=metallic |
| 输入 | `UV` | Vector2 | 采样坐标 |
| 输入 | `Metallic` | Float | 钳制到 `[0, 1]` |
| 输入 | `Roughness` | Float | 钳制到 `[0, 1]` |
| 输入 | `NormalScale` | Float | 钳制到 `[0, 2]` |
| 输出 | `BaseColor` | Vector4 | 基础色采样结果 |
| 输出 | `NormalTS` | Vector3 | 缩放并归一化后的切线空间法线 |
| 输出 | `ORM` | Vector3 | AO/roughness/metallic 三通道 |
| 输出 | `Parameters` | Vector3 | `metallic, roughness, normalScale / 2` |

`TA_SanitizeMaterial` 是供调试或只需标量/向量输入时使用的最小节点。两个函数均定义了
`_float` 与 `_half` 版本，适配 Shader Graph 自动附加的精度后缀。

## 纹理接口

URP 14.0.12 的 File 模式 Custom Function 接收 `UnityTexture2D`，纹理采样必须使用：

```hlsl
SAMPLE_TEXTURE2D(Texture.tex, Texture.samplerstate, UV)
```

避免把旧式裸 `Texture2D` 签名、`sampler2D` 或函数名中的精度后缀混入节点配置；这些写法会
导致端口不匹配、精度变体缺失或 Shader Graph 编译警告。

## 验收

运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\StaticValidate.ps1
```

静态验收确认 HLSL 防重包含、File 模式纹理结构体、`float`/`half` 变体、标量边界、零长度
法线回退，以及标量/向量/纹理端口契约。Editor 可用时，再执行菜单生成子图并观察 Console 中的
`TA_SHADER_GRAPH_CUSTOM_FUNCTION: PASS`。
