# Unity 材质参数边界验证

## 验收范围

固定验证 Metallic、Roughness 和 Normal Scale 三类参数，共 11 个样例：

| 参数 | 固定值 | 物理/数值检查 |
| --- | --- | --- |
| Metallic | `0`、`0.5`、`1` | 介电漫反射权重 `1-metallic` 分别为 `1`、`0.5`、`0` |
| Roughness | `0`、`0.25`、`0.5`、`0.75`、`1` | `smoothness=1-r`；`alpha=max(r², 1e-4)`，结果有限且单调 |
| Normal Scale | `0`、`1`、`2` | 分别表示关闭法线贴图、原始强度、验证上限，禁止负值和大于 `2` |

机器可读基准位于 `Assets/_TA/Documentation/MaterialBoundaryMatrix.json`，静态对比板位于
`Reports/MaterialBoundaryBoard.png`。Unity Editor 可用时，`MaterialBoundaryValidator` 还会生成
11 个 `MAT_Boundary_*.mat`、`SCN_MaterialBoundaryBoard.unity`、1200×720 场景截图和结构化报告。

## 结论

1. **Metallic**：`0` 和 `1` 是均质介电/金属端点；`0.5` 可用于遮罩过渡、氧化或混合边缘，不应默认解释为均质“半金属”。
2. **Roughness**：`0` 不能直接让 GGX `alpha` 为零，本工程固定使用 `1e-4` 下限；随着粗糙度升高，`alpha` 从 `0.0001` 单调增加到 `1`，高光应逐渐变宽。
3. **Normal Scale**：`0` 保留几何法线，`1` 使用美术原始强度，`2` 是压力测试上限；更高值会放大切线空间误差并产生不稳定的掠射角高光。
4. 所有 11 个固定样例均落在公开 Profile 范围内，公式结果有限，没有负平滑度、超范围金属度或零分母风险。

## 验收命令

```powershell
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\StaticValidate.ps1
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\GenerateBoundaryBoard.ps1
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\ValidateMaterialBoundaries.ps1
```

前两条不需要 Unity Editor 许可证。第三条要求日志包含
`UNITY_MATERIAL_BOUNDARY_ACCEPTANCE: PASS`；许可证不可用时，静态 PASS 不替代场景运行验收。
