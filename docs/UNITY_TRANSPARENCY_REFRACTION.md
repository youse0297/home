# Unity 透明与折射

## 交付内容

- `TA_TransparencyRefraction.hlsl` 提供 IOR 到介电 `F0`、Snell 折射方向、屏幕 UV 偏移、Beer–Lambert 吸收和透明表面合成。
- `TA_TransparentRefraction.shader` 在 URP Transparent 队列中采样 `_CameraOpaqueTexture`，使用直接光 PBR 结果作为表面层。
- `MAT_TransparentRefraction.mat` 提供 IOR `1.5`、厚度 `0.6`、表面不透明度 `0.12` 的可调玻璃样例。
- `RP_MaterialLab_URP.asset` 启用 Opaque Texture，确保 Shader 读取真实的不透明场景色。

## 光学契约

材质将折射率夹到 `[1, 2.5]`，以 `eta = 1 / IOR` 计算空气进入材质的 Snell 折射方向，并以

`F0 = ((IOR - 1) / (IOR + 1))^2`

生成 Schlick Fresnel。透射颜色使用

`T = exp(-max(absorptionCoefficient, 0) * clamp(thickness, 0, 10))`

做 Beer–Lambert 衰减。最终表面权重为 `opacity + (1-opacity)*Fresnel`，保证掠射角收敛到反射表面。

## 渲染状态

Shader 使用 `Queue=Transparent`、`RenderType=Transparent` 和 `ZWrite Off`。由于片元已把采样的背景与表面光照合成为最终颜色，Pass 使用 `Blend One Zero` 覆盖输出；若再次做常规 Alpha 混合，会把同一背景混入两次并削弱折射。

## 验收

从仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\ValidateTransparencyRefraction.ps1
powershell -ExecutionPolicy Bypass -File .\Tools\RunStage1Acceptance.ps1 -SkipConfigure -SkipBuild
```

专项脚本固定 13 个数值夹具（包含 `IOR=1` 零畸变恒等条件），并检查 7 个公共符号、模块纯度、透明渲染状态、场景色采样、材质默认值和 URP Opaque Texture 开关。

## 边界

- `_CameraOpaqueTexture` 只包含透明阶段开始前的不透明内容，不能表现透明物体互相折射。
- 屏幕外内容不可采样，UV 被夹到画面边界，强折射可能出现边缘拉伸。
- 当前厚度由美术参数提供，不通过背面或深度差追踪真实几何厚度。
- Unity Shader 导入和最终画面检查仍需可用的 Editor 许可证。
