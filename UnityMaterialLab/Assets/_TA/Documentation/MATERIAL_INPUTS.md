# PBR Material Inputs

The material input contract is shared by the master material and all three instance profiles:

| Input | Asset | Color space | Channel contract |
| --- | --- | --- | --- |
| BaseColor | `T_CC0_Crate_BaseColor.png` | sRGB | RGB color, A reserved for alpha |
| Normal | `T_PBR_Normal.png` | Linear | Tangent-space XYZ normal, imported as Normal Map |
| ORM | `T_PBR_ORM.png` | Linear | R = AO, G = roughness, B = metallic, A unused |

`MAT_PBR_Master.mat` is the URP Lit material contract. `MAT_PBR_Dielectric.mat`,
`MAT_PBR_RoughMetal.mat`, and `MAT_PBR_SmoothMetal.mat` are independent material
instances created from that contract. Their editable parameters are stored in the
matching `MI_PBR_*.asset` profiles and applied by `MaterialInputProfile.ApplyTo`.

The current URP Lit fallback consumes ORM R (AO) through `_OcclusionMap` and keeps the
G/B channels in the shared input asset for the custom PBR path. Roughness is exposed
as a parameter and converted to URP Lit smoothness with `smoothness = 1 - roughness`.

Common failures:

- Marking Normal or ORM as sRGB changes vector/data values during sampling.
- Swapping ORM G/B makes roughness and metallic instances look unrelated to their profiles.
- Editing a shared master asset when an instance override was intended changes all three instances.
- Leaving textures unassigned silently falls back to white/flat data and hides import failures.
