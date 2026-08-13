# Unity LOD 基础

本日程项固定一个可复现的三档几何 LOD 基准，并用屏幕相对高度检查切换。

## 策略

`screenHeight` 表示渲染器包围盒在相机视口高度中的相对占比，不是世界空间距离。当前策略为：

| LOD | 阈值（含） | 顶点 | 三角形 |
| --- | ---: | ---: | ---: |
| High | `0.60` | 544 | 1024 |
| Medium | `0.25` | 144 | 256 |
| Low | `0.05` | 40 | 64 |
| Culled | `<0.05` | 不渲染 | 不渲染 |

阈值必须严格递减。`QualitySettings.lodBias=1.0` 作为固定基准；交叉淡化使用 `0.15 s`。`lodBias` 会整体缩放屏幕阈值，项目若改变它，必须重新记录对比结果。

## 生成与检查

打开 Unity 后执行菜单 `TA/Material Lab/Build LOD Test Scene`，生成：

- `Assets/_TA/LOD/PF_LOD_MaterialBall.prefab`
- `Assets/_TA/LOD/SCN_LOD_Baseline.unity`
- `Assets/_TA/Documentation/LODValidation.json`

场景放置四个固定样本，分别以 `0.80/0.40/0.10/0.02` 的屏幕高度预期命中 High、Medium、Low 和 Culled。生成器会使用 `LODGroup.SetLODs`、`LODFadeMode.CrossFade` 和同一份 `LodPolicy`，避免手工 Inspector 参数漂移。

未激活 Unity 许可证时，可运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\GenerateLodBoard.ps1
powershell -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

前者生成 `Reports/LODComparisonBoard.png` 与 `Reports/LODValidationReport.json`；后者检查阈值单调性、四个切换样本、网格计数、交叉淡化设置和 Unity 程序集离线编译。

## 常见失败点

- 把距离阈值当成 `screenHeight`，导致不同分辨率或 FOV 下切换漂移。
- LOD 阈值未递减，或把 `0` 误当成一个可渲染 LOD。
- 修改 `lodBias` 后仍沿用旧截图和旧数值。
- 只替换 `MeshFilter`，没有通过 `LODGroup.SetLODs` 更新渲染器列表。
- 低模没有重新计算法线/包围盒，切换时出现阴影跳变或提前剔除。
