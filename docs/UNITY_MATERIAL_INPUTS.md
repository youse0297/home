# Unity 材质输入与实例

## 交付物

- `MAT_PBR_Master.mat`：URP Lit 基础 PBR 主材质，绑定 BaseColor、Normal 和 ORM 输入。
- `MAT_PBR_Dielectric.mat`：介电实例，`metallic=0`、`roughness=0.64`。
- `MAT_PBR_RoughMetal.mat`：粗糙金属实例，`metallic=1`、`roughness=0.72`。
- `MAT_PBR_SmoothMetal.mat`：光滑金属实例，`metallic=1`、`roughness=0.16`。
- `MI_PBR_*.asset`：三个可编辑参数 Profile，保存纹理引用、颜色、法线强度、金属度、粗糙度和遮蔽强度。

## 输入契约

| 输入 | 颜色空间 | 通道/参数 |
| --- | --- | --- |
| BaseColor | sRGB | RGB 基础色，Alpha 预留 |
| Normal | Linear | 切线空间 XYZ，导入类型为 Normal Map |
| ORM | Linear | R=AO，G=roughness，B=metallic，A 未使用 |

Profile 应用到 URP Lit 时使用 `_BaseMap`、`_BumpMap` 和 `_OcclusionMap`；粗糙度按
`smoothness = 1 - roughness` 转换。ORM 的 G/B 保留给后续自定义 PBR 路径，避免把数据贴图误当作 sRGB。

## 验收

```powershell
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\StaticValidate.ps1
```

验收必须确认三个 Profile 的范围为 `metallic/roughness ∈ [0,1]`、`normalScale ∈ [0,2]`，并且每个实例的三张输入贴图引用与 Profile 一致。
