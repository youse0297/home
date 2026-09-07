# Unity Editor Validation Blocked

## Status

Editor runtime validation is blocked by the local Unity/Tuanjie license state, not by a detected project compile or asset-structure failure.

## Evidence

- Editor: `F:\unity\2022.3.62f3c1\Editor\Unity.exe`
- Batch log (local, ignored): `UnityMaterialLab/Logs/material-lab-build.log`
- Interactive log (local, ignored): `UnityMaterialLab/Logs/material-lab-build-interactive.log`
- Batch entitlement error: `com.unity.editor.headless was not found`
- Interactive entitlement error: `com.unity.editor.ui was not found`
- Final message: `No valid Unity Editor license found. Please activate your license.`

## Completed Without Editor Runtime

- Unity project/version and URP package manifest
- Directory and naming conventions
- CC0 OBJ and PNG source assets with license ledger
- Deterministic model/texture importer configuration
- URP pipeline/material/prefab/scene/screenshot bootstrap code
- Offline C# compilation against the installed `UnityEngine` and `UnityEditor` assemblies
- Static project and source-asset validation report
- Shader Graph Custom Function HLSL、端口契约和示例子图生成器的离线 C# / 静态接口验收
- BasePass 10 档表面/光照拆解 Shader、控制器、场景生成器和离线加法不变量验收
- 阶段 1 总验收中的 CPU `12/12`、Unity `158` 项静态检查和全部离线报告
- 六模块材质展板生成器、源码库输入输出文档、1600×900 离线参考图和专项静态验收
- HLSL v1.0 发布包已从两文件空工程骨架完成迁移，18 个验证器和 116 项结构检查通过，Windows SDK `fxc /WX /Ges` 编译 0 warning

## Latest Attempt

- `2026-08-16` 执行 `BasePassLightingBootstrap.Build` 时，Editor 批处理超过两分钟无日志且未生成材质或场景，已终止挂起进程。
- `2026-09-07` 执行 `MaterialShowcaseBootstrap.Build` 时，Editor 批处理超过一分钟仍无日志，符合相同许可证阻塞表现；已终止本次挂起进程，未生成或伪造场景与运行截图。
- `2026-09-07` HLSL 专项验收已用独立编译器验证可移植语法与模块调用，但该证据不冒充 Unity URP variant 编译；Editor 许可证恢复后仍需完成发布包导入和 Console 检查。
- 本次未覆盖或改写现有 Unity 资产；真实 Shader 导入/编译、BasePass 对照场景和 Shader Graph 子图仍需在可正常启动的 Editor 会话中完成。

## Unblock Procedure

1. Sign in and activate `2022.3.62f3c1` in Tuanjie Hub on this machine.
2. Run `Tools/BuildAndValidate.ps1` from the project root.
3. Run `TA/Material Lab/Create Custom Function Example` and require `TA_SHADER_GRAPH_CUSTOM_FUNCTION: PASS` in Console.
4. Run `TA/Material Lab/Build BasePass Lighting Decomposition` and inspect all ten debug views.
5. Require `UNITY_ASSET_IMPORT_ACCEPTANCE: PASS` in `Logs/material-lab-validation.log`.
6. Run `TA/Material Lab/Build Material Showcase`, inspect all six stands, and save `Assets/_TA/Documentation/MaterialShowcaseRuntime.png`.
7. Inspect `Assets/_TA/Documentation/UnityAssetImportBaseline.png`, `ImportValidation.json`, `Assets/_TA/ShaderGraph/SG_CustomFunctionExample.shadersubgraph`, `Assets/_TA/BasePass/SCN_BasePassLightingDecomposition.unity` and `Assets/_TA/Scenes/SCN_MaterialShowcase.unity`.
8. Import `Releases/TA_HLSL_MaterialLibrary_v1.0.0.zip` into a clean URP project and require zero Shader import errors in Console.
