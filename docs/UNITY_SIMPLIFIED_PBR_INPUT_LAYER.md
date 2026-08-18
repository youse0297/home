# Unity 简化 PBR 输入层

本日程项把 BaseColor、Normal、ORM 三张贴图和材质缩放参数组装为稳定的 PBR 输入，位于 `UnityMaterialLab/Assets/_TA/Shaders/Library/TA_PBRInput.hlsl`。它连接采样工具与光照层，避免每个 Renderer Shader 重复实现颜色、Alpha、AO、粗糙度和金属度边界。

## 接口

`TA_PBRInputConfig` 固定材质侧配置：

| 字段 | 含义 | 约束来源 |
| --- | --- | --- |
| `baseColorTint` | BaseColor RGB 与 Alpha 乘子 | Material 属性 |
| `normalScale` | 法线贴图强度 | `[0, 2]` 属性范围 |
| `ambientOcclusionStrength` | ORM.R 与 1 的混合强度 | `[0, 1]` 并在函数内 saturate |
| `roughnessScale` | ORM.G 缩放 | `[0, 1]` 属性范围 |
| `metallicScale` | ORM.B 缩放 | `[0, 1]` 属性范围 |

`TA_PBRInputData` 输出 `baseColor`、`alpha`、`normalTS`、`ambientOcclusion`、`roughness` 和 `metallic`。两个公共入口是：

- `TA_SamplePBRInput`：绑定三张纹理，调用共享采样工具并应用输入策略。
- `TA_BuildSurfaceData`：接收世界法线，归一化后生成光照层使用的 `TA_SurfaceData`。

## 固定策略

```text
BaseColor = saturate(BaseMap.rgb * BaseColorTint.rgb)
Alpha = BaseMap.a * BaseColorTint.a
AO = lerp(1, saturate(ORM.R), saturate(AOStrength))
Roughness = max(saturate(ORM.G * RoughnessScale), 0.045)
Metallic = saturate(ORM.B * MetallicScale)
```

法线不在 PBR 输入层重复解码：`TA_SampleNormalTS` 继续委托 Unity `UnpackNormalScale`，随后由 `TA_TransformTangentToWorld` 与 `TA_BuildSurfaceData` 处理空间转换和归一化。这样可保留 BC5、ASTC 和 DXT5nm 等平台编码差异。

## 消费方式

BasePass 只填写配置并传入纹理参数：

```hlsl
TA_PBRInputConfig pbrConfig;
pbrConfig.baseColorTint = _BaseColor;
pbrConfig.normalScale = _BumpScale;
pbrConfig.ambientOcclusionStrength = _AOStrength;
pbrConfig.roughnessScale = _RoughnessScale;
pbrConfig.metallicScale = _MetallicScale;

TA_PBRInputData pbrInput = TA_SamplePBRInput(
    TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap),
    TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap),
    TEXTURE2D_ARGS(_ORMMap, sampler_ORMMap),
    input.uv,
    pbrConfig);
TA_SurfaceData surface = TA_BuildSurfaceData(pbrInput, normalWS);
```

输入层不负责光照、曝光、色调映射、sRGB 输出或 Alpha 裁剪；这些职责仍属于消费 Shader 和后续渲染阶段。

## 验收

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidatePbrInputLayer.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

契约位于 `Assets/_TA/Documentation/PbrInputLayer.json`，包含正常输入、越界钳制和零缩放/粗糙度下限三组固定样例。报告写入 `Reports/PbrInputLayerValidation.json`，并检查 BasePass 不再直接赋值 `TA_SurfaceData` 的材质字段。

Unity Editor 运行时 shader 编译仍需有效许可证；离线 `PASS` 证明的是输入策略、源码接线和固定公式，不替代最终场景验收。
