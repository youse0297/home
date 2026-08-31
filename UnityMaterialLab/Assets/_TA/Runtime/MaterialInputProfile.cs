using UnityEngine;

namespace TA.MaterialLab
{
    [CreateAssetMenu(
        fileName = "MI_PBR_Instance",
        menuName = "TA/Material Lab/PBR Material Input Profile"
    )]
    public sealed class MaterialInputProfile : ScriptableObject
    {
        public const string OrmChannelContract = "R=AO; G=roughness; B=metallic; A=unused";
        public const float MinimumNormalScale = 0.0f;
        public const float MaximumNormalScale = 2.0f;

        [Header("Texture inputs")]
        public Texture2D baseColor;
        public Texture2D normal;
        public Texture2D orm;

        [Header("Optional normal layers")]
        public Texture2D detailNormal;
        public Texture2D macroNormal;

        [Header("Instance parameters")]
        [ColorUsage(true, true)]
        public Color baseColorTint = Color.white;

        [Range(0.0f, 2.0f)]
        public float normalScale = 1.0f;

        [Range(0.0f, 2.0f)]
        public float detailNormalScale = 1.0f;

        [Range(0.0f, 1.0f)]
        public float detailNormalWeight;

        [Range(0.0f, 2.0f)]
        public float macroNormalScale = 1.0f;

        [Range(0.0f, 1.0f)]
        public float macroNormalWeight;

        [Header("Procedural mask")]
        public Vector2 proceduralMaskScale = new Vector2(4.0f, 4.0f);
        public Vector2 proceduralMaskOffset;

        [Range(-3.1415927f, 3.1415927f)]
        public float proceduralMaskRotation;

        [Range(-16.0f, 16.0f)]
        public float proceduralMaskTimeScale;

        [Range(-6.2831853f, 6.2831853f)]
        public float proceduralMaskPhase;

        [Range(0.0f, 4.0f)]
        public float proceduralMaskContrast = 1.0f;

        [Range(0.0f, 1.0f)]
        public float proceduralMaskStrength;

        [Header("Edge wear")]
        [ColorUsage(true, true)]
        public Color edgeWearColor = Color.white;

        [Range(0.0f, 1.0f)]
        public float edgeWearThreshold = 0.65f;

        [Range(0.001f, 1.0f)]
        public float edgeWearSoftness = 0.2f;

        [Range(0.0f, 1.0f)]
        public float edgeWearStrength;

        [Range(0.0f, 1.0f)]
        public float edgeWearRoughnessBoost = 0.25f;

        [Range(0.0f, 1.0f)]
        public float metallic;

        [Range(0.0f, 1.0f)]
        public float roughness = 0.5f;

        [Range(0.0f, 1.0f)]
        public float occlusionStrength = 1.0f;

        [Range(0.0f, 1.0f)]
        public float alpha = 1.0f;

        public void ApplyTo(Material material)
        {
            if (material == null)
            {
                return;
            }
            ClampToValidRanges();

            SetTextureIfSupported(material, "_BaseMap", baseColor);
            SetTextureIfSupported(material, "_BumpMap", normal);
            SetTextureIfSupported(material, "_DetailNormalMap", detailNormal);
            SetTextureIfSupported(material, "_MacroNormalMap", macroNormal);
            SetTextureIfSupported(material, "_OcclusionMap", orm);
            SetTextureIfSupported(material, "_ORMMap", orm);
            SetColorIfSupported(material, "_BaseColor", baseColorTint);
            SetColorIfSupported(material, "_Color", baseColorTint);
            SetFloatIfSupported(material, "_BumpScale", normalScale);
            SetFloatIfSupported(material, "_DetailNormalScale", detailNormalScale);
            SetFloatIfSupported(material, "_DetailNormalWeight", detailNormalWeight);
            SetFloatIfSupported(material, "_MacroNormalScale", macroNormalScale);
            SetFloatIfSupported(material, "_MacroNormalWeight", macroNormalWeight);
            SetVectorIfSupported(
                material,
                "_ProceduralMaskScale",
                new Vector4(proceduralMaskScale.x, proceduralMaskScale.y, 0.0f, 0.0f)
            );
            SetVectorIfSupported(
                material,
                "_ProceduralMaskOffset",
                new Vector4(proceduralMaskOffset.x, proceduralMaskOffset.y, 0.0f, 0.0f)
            );
            SetFloatIfSupported(material, "_ProceduralMaskRotation", proceduralMaskRotation);
            SetFloatIfSupported(material, "_ProceduralMaskTimeScale", proceduralMaskTimeScale);
            SetFloatIfSupported(material, "_ProceduralMaskPhase", proceduralMaskPhase);
            SetFloatIfSupported(material, "_ProceduralMaskContrast", proceduralMaskContrast);
            SetFloatIfSupported(material, "_ProceduralMaskStrength", proceduralMaskStrength);
            SetColorIfSupported(material, "_EdgeWearColor", edgeWearColor);
            SetFloatIfSupported(material, "_EdgeWearThreshold", edgeWearThreshold);
            SetFloatIfSupported(material, "_EdgeWearSoftness", edgeWearSoftness);
            SetFloatIfSupported(material, "_EdgeWearStrength", edgeWearStrength);
            SetFloatIfSupported(material, "_EdgeWearRoughnessBoost", edgeWearRoughnessBoost);
            SetFloatIfSupported(material, "_Metallic", metallic);
            SetFloatIfSupported(material, "_Smoothness", 1.0f - roughness);
            SetFloatIfSupported(material, "_OcclusionStrength", occlusionStrength);
            SetFloatIfSupported(material, "_Cutoff", alpha);
        }

        public bool HasValidParameters()
        {
            return IsFinite(normalScale) &&
                   IsFinite(metallic) &&
                   IsFinite(roughness) &&
                   IsFinite(occlusionStrength) &&
                   IsFinite(alpha) &&
                   normalScale >= MinimumNormalScale &&
                   normalScale <= MaximumNormalScale &&
                   IsFinite(detailNormalScale) &&
                   IsFinite(detailNormalWeight) &&
                   IsFinite(macroNormalScale) &&
                   IsFinite(macroNormalWeight) &&
                   detailNormalScale >= MinimumNormalScale &&
                   detailNormalScale <= MaximumNormalScale &&
                   detailNormalWeight >= 0.0f && detailNormalWeight <= 1.0f &&
                   macroNormalScale >= MinimumNormalScale &&
                   macroNormalScale <= MaximumNormalScale &&
                   macroNormalWeight >= 0.0f && macroNormalWeight <= 1.0f &&
                   IsFinite(proceduralMaskScale.x) && IsFinite(proceduralMaskScale.y) &&
                   IsFinite(proceduralMaskOffset.x) && IsFinite(proceduralMaskOffset.y) &&
                   IsFinite(proceduralMaskRotation) &&
                   IsFinite(proceduralMaskTimeScale) &&
                   IsFinite(proceduralMaskPhase) &&
                   IsFinite(proceduralMaskContrast) &&
                   IsFinite(proceduralMaskStrength) &&
                   proceduralMaskScale.x >= 0.0f && proceduralMaskScale.x <= 64.0f &&
                   proceduralMaskScale.y >= 0.0f && proceduralMaskScale.y <= 64.0f &&
                   proceduralMaskRotation >= -3.1415927f && proceduralMaskRotation <= 3.1415927f &&
                   proceduralMaskTimeScale >= -16.0f && proceduralMaskTimeScale <= 16.0f &&
                   proceduralMaskPhase >= -6.2831853f && proceduralMaskPhase <= 6.2831853f &&
                   proceduralMaskContrast >= 0.0f && proceduralMaskContrast <= 4.0f &&
                   proceduralMaskStrength >= 0.0f && proceduralMaskStrength <= 1.0f &&
                   IsFinite(edgeWearColor.r) && IsFinite(edgeWearColor.g) &&
                   IsFinite(edgeWearColor.b) && IsFinite(edgeWearColor.a) &&
                   IsFinite(edgeWearThreshold) && IsFinite(edgeWearSoftness) &&
                   IsFinite(edgeWearStrength) && IsFinite(edgeWearRoughnessBoost) &&
                   edgeWearColor.r >= 0.0f && edgeWearColor.g >= 0.0f &&
                   edgeWearColor.b >= 0.0f && edgeWearColor.a >= 0.0f &&
                   edgeWearThreshold >= 0.0f && edgeWearThreshold <= 1.0f &&
                   edgeWearSoftness >= 0.001f && edgeWearSoftness <= 1.0f &&
                   edgeWearStrength >= 0.0f && edgeWearStrength <= 1.0f &&
                   edgeWearRoughnessBoost >= 0.0f && edgeWearRoughnessBoost <= 1.0f &&
                   metallic >= 0.0f && metallic <= 1.0f &&
                   roughness >= 0.0f && roughness <= 1.0f &&
                   occlusionStrength >= 0.0f && occlusionStrength <= 1.0f &&
                   alpha >= 0.0f && alpha <= 1.0f;
        }

        public void ClampToValidRanges()
        {
            normalScale = ClampFinite(normalScale, MinimumNormalScale, MaximumNormalScale, 1.0f);
            detailNormalScale = ClampFinite(detailNormalScale, MinimumNormalScale, MaximumNormalScale, 1.0f);
            detailNormalWeight = ClampFinite(detailNormalWeight, 0.0f, 1.0f, 0.0f);
            macroNormalScale = ClampFinite(macroNormalScale, MinimumNormalScale, MaximumNormalScale, 1.0f);
            macroNormalWeight = ClampFinite(macroNormalWeight, 0.0f, 1.0f, 0.0f);
            proceduralMaskScale.x = ClampFinite(proceduralMaskScale.x, 0.0f, 64.0f, 4.0f);
            proceduralMaskScale.y = ClampFinite(proceduralMaskScale.y, 0.0f, 64.0f, 4.0f);
            proceduralMaskOffset.x = ClampFinite(proceduralMaskOffset.x, -4096.0f, 4096.0f, 0.0f);
            proceduralMaskOffset.y = ClampFinite(proceduralMaskOffset.y, -4096.0f, 4096.0f, 0.0f);
            proceduralMaskRotation = ClampFinite(proceduralMaskRotation, -3.1415927f, 3.1415927f, 0.0f);
            proceduralMaskTimeScale = ClampFinite(proceduralMaskTimeScale, -16.0f, 16.0f, 0.0f);
            proceduralMaskPhase = ClampFinite(proceduralMaskPhase, -6.2831853f, 6.2831853f, 0.0f);
            proceduralMaskContrast = ClampFinite(proceduralMaskContrast, 0.0f, 4.0f, 1.0f);
            proceduralMaskStrength = ClampFinite(proceduralMaskStrength, 0.0f, 1.0f, 0.0f);
            edgeWearColor.r = ClampFinite(edgeWearColor.r, 0.0f, float.MaxValue, 1.0f);
            edgeWearColor.g = ClampFinite(edgeWearColor.g, 0.0f, float.MaxValue, 1.0f);
            edgeWearColor.b = ClampFinite(edgeWearColor.b, 0.0f, float.MaxValue, 1.0f);
            edgeWearColor.a = ClampFinite(edgeWearColor.a, 0.0f, float.MaxValue, 1.0f);
            edgeWearThreshold = ClampFinite(edgeWearThreshold, 0.0f, 1.0f, 0.65f);
            edgeWearSoftness = ClampFinite(edgeWearSoftness, 0.001f, 1.0f, 0.2f);
            edgeWearStrength = ClampFinite(edgeWearStrength, 0.0f, 1.0f, 0.0f);
            edgeWearRoughnessBoost = ClampFinite(edgeWearRoughnessBoost, 0.0f, 1.0f, 0.25f);
            metallic = ClampFinite(metallic, 0.0f, 1.0f, 0.0f);
            roughness = ClampFinite(roughness, 0.0f, 1.0f, 0.5f);
            occlusionStrength = ClampFinite(occlusionStrength, 0.0f, 1.0f, 1.0f);
            alpha = ClampFinite(alpha, 0.0f, 1.0f, 1.0f);
        }

        private void OnValidate()
        {
            ClampToValidRanges();
        }

        private static void SetTextureIfSupported(
            Material material,
            string propertyName,
            Texture texture
        )
        {
            if (material.HasProperty(propertyName))
            {
                material.SetTexture(propertyName, texture);
            }
        }

        private static void SetColorIfSupported(
            Material material,
            string propertyName,
            Color value
        )
        {
            if (material.HasProperty(propertyName))
            {
                material.SetColor(propertyName, value);
            }
        }

        private static void SetFloatIfSupported(
            Material material,
            string propertyName,
            float value
        )
        {
            if (material.HasProperty(propertyName))
            {
                material.SetFloat(propertyName, value);
            }
        }

        private static void SetVectorIfSupported(
            Material material,
            string propertyName,
            Vector4 value
        )
        {
            if (material.HasProperty(propertyName))
            {
                material.SetVector(propertyName, value);
            }
        }

        private static float ClampFinite(float value, float minimum, float maximum, float fallback)
        {
            return IsFinite(value) ? Mathf.Clamp(value, minimum, maximum) : fallback;
        }

        private static bool IsFinite(float value)
        {
            return !float.IsNaN(value) && !float.IsInfinity(value);
        }
    }
}
