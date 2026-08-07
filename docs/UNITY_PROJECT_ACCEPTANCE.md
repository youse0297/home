# Unity 工程与资产导入验收

## 交付物

- 工程：`UnityMaterialLab/`
- Editor：`2022.3.62f3c1`
- URP：`14.0.12`
- 模型：`SM_CC0_DisplayCrate.obj`，8 个位置、4 个 UV、6 个法线、12 个三角形
- 贴图：`T_CC0_Crate_BaseColor.png`，64×64，自制 CC0 基础色
- 生成内容：5 个材质球、2 个 Prefab、1 个测试场景、Build Settings、960×540 基线截图和 JSON 报告

## 验收命令

静态验收不依赖 Editor 许可证：

```powershell
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\StaticValidate.ps1
```

有可用 Unity 许可证后执行完整导入：

```powershell
powershell -ExecutionPolicy Bypass -File .\UnityMaterialLab\Tools\BuildAndValidate.ps1
```

完整验收必须在日志中出现 `UNITY_ASSET_IMPORT_ACCEPTANCE: PASS`，并生成：

- `Assets/_TA/Prefabs/PF_MaterialBall.prefab`
- `Assets/_TA/Prefabs/PF_CC0_DisplayCrate.prefab`
- `Assets/_TA/Scenes/SCN_MaterialImportLab.unity`
- `Assets/_TA/Documentation/UnityAssetImportBaseline.png`
- `Assets/_TA/Documentation/ImportValidation.json`

## 固定导入口径

模型使用米制、源法线、MikkTSpace 切线、自动第二套 Lightmap UV，禁用源材质/相机/灯光/动画。基础色 PNG 使用 sRGB、MipMap、Repeat、Bilinear、无压缩。所有资产位于 `Assets/_TA`，目录与命名由 Bootstrap 固定，避免素材污染工程根目录。

## 当前验证状态

静态验收已通过：工程版本、URP 版本、资产内容、命名规则、CC0 台账和离线 C# 编译均通过。Unity Editor 运行验收当前为 `BLOCKED_LICENSE`，因为本机许可证日志同时报告 `com.unity.editor.headless` 和 `com.unity.editor.ui` entitlement 缺失；详见 `UnityMaterialLab/Reports/EDITOR_VALIDATION_BLOCKED.md`。
