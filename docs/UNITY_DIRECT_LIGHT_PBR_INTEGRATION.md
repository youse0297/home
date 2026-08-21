# Unity Direct-Light PBR Integration

This schedule item completes the direct-light path used by the URP `UniversalForward` BasePass. The renderer-facing HLSL now exposes a reusable `TA_EvaluateDirectLighting` entry point and keeps the total-light wrapper focused on indirect diffuse and final decomposition.

## Contract

Source: `UnityMaterialLab/Assets/_TA/Shaders/Library/TA_Lighting.hlsl`

- `TA_DirectLightingBreakdown` contains `directDiffuse` and `directSpecular`.
- `TA_EvaluateDirectLighting` normalizes the world-space directions, clamps all dot products, sanitizes roughness/metallic/base color/radiance, and returns zero for back-facing view or light directions.
- Diffuse uses the energy-conserving weight `(1 - F_Schlick) * (1 - metallic) * BaseColor / PI`.
- Specular uses `D_GGX * V_SmithGGXCorrelated * F_Schlick`, followed by `NdotL * radiance`.
- `TA_EvaluateLighting` delegates direct components to this entry point, then adds SH indirect diffuse:

```text
FinalLit = DirectDiffuse + DirectSpecular + IndirectDiffuse
```

The direct-light contract is recorded in `UnityMaterialLab/Assets/_TA/Documentation/DirectLightPbrIntegration.json`. It is deliberately independent of URP `Light` types; the BasePass adapts `Light.color`, attenuation and directions into `TA_LightingInput`.

## Offline acceptance

Run from `UnityMaterialLab`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\ValidateDirectLightPbrIntegration.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\GenerateBasePassLightingBoard.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\StaticValidate.ps1
```

The validator checks the normal BasePass fixture, the back-face zero guard, public symbols, component composition and BasePass wiring. The board is an analytic linear-HDR baseline; it is not a Unity frame capture or RenderDoc `.rdc`.

For the fixed fixture, the energy-conserving direct components are:

```text
DirectDiffuse  = (0.17575764, 0.04479811, 0.01891492)
DirectSpecular = (0.10084746, 0.02988181, 0.01750756)
```
