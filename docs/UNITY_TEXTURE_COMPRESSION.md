# Unity 贴图压缩

## 结论

Standalone 平台采用按用途区分的块压缩策略：

| 资产 | Importer | 色彩空间 | 格式 | 64x64 全 mip 显存 | 相对 RGBA32 节省 |
| --- | --- | --- | --- | --- | --- |
| BaseColor | Default | sRGB | BC7 | 5,488 B | 74.9% |
| Normal | Normal Map | Linear | BC5 | 5,488 B | 74.9% |
| ORM | Default | Linear | BC1 | 2,744 B | 87.4% |

完整 `64x64 -> 1x1` mip 链有 5,461 个纹素。RGBA32 使用 `5,461 * 4 = 21,844 B`；
BC 格式按每级最少一个 `4x4` 块计费，因此必须按每个 mip 级计算块数，不能只用总纹素数乘 bpp。

## 实现

`TextureCompressionPolicy` 对 Standalone 平台显式覆盖格式、设置 `CompressedHQ` 和质量 `100`，并关闭 Crunch：

- BaseColor：`TextureImporterFormat.BC7`，保留 sRGB。
- Normal：`TextureImporterFormat.BC5`，`NormalMap` 导入且保持 Linear；采样端重建 Z。
- ORM：`TextureImporterFormat.DXT1`（BC1），保持 Linear 且无 Alpha，通道仍为 R=AO、G=roughness、B=metallic。

策略由 `ProjectBootstrap` 在导入时执行，并在 Editor 验收时检查各平台覆盖。

## 质量与对照

[TextureCompressionBoard.png](../UnityMaterialLab/Reports/TextureCompressionBoard.png) 展示格式显存、用途策略与真实 BC1
往返预览。BC1 往返由 Unity 安装中的 `PVRTexTool.exe` 生成，报告记录其平均和最大绝对误差；BC5/BC7
选择基于对应的法线/颜色语义及固定块显存。真实 Unity 导入后的所有格式预览仍需在可用 Editor 会话中确认。

## 常见失败点

- BaseColor 错设为 Linear，会使采样后的光照颜色偏暗或偏亮。
- Normal 错设为 sRGB，或使用 BC1 压缩法线，导致方向误差和高光伪影。
- 将 ORM 当作颜色贴图，破坏 roughness/metallic 的线性数值。
- 忘记平台覆盖，Unity 会选择与目标平台不一致的自动格式。
- 用总纹素数直接计算 BC 贴图全 mip 显存，忽略小 mip 的最小 `4x4` 块分配。

## 验收

```powershell
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\GenerateTextureCompressionBoard.ps1
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\StaticValidate.ps1
```

第一个命令生成 `TextureCompressionBoard.png`、BC1 参考 DDS/PNG 和
`TextureCompressionValidation.json`；第二个命令校验格式策略、色彩空间、显存公式和对照板尺寸。
