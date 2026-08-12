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

## Latest Attempt

- `2026-08-13` 执行 `ShaderGraphCustomFunctionBootstrap.CreateExample` 时，Editor 批处理超过两分钟无日志且未生成子图，已终止挂起进程。
- 本次未覆盖或改写现有 Unity 资产；真实 Shader Graph 导入/编译仍需在可正常启动的 Editor 会话中完成。

## Unblock Procedure

1. Sign in and activate `2022.3.62f3c1` in Tuanjie Hub on this machine.
2. Run `Tools/BuildAndValidate.ps1` from the project root.
3. Run `TA/Material Lab/Create Custom Function Example` and require `TA_SHADER_GRAPH_CUSTOM_FUNCTION: PASS` in Console.
4. Require `UNITY_ASSET_IMPORT_ACCEPTANCE: PASS` in `Logs/material-lab-validation.log`.
5. Inspect `Assets/_TA/Documentation/UnityAssetImportBaseline.png`, `ImportValidation.json` and `Assets/_TA/ShaderGraph/SG_CustomFunctionExample.shadersubgraph`.
