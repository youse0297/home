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

        [Header("Instance parameters")]
        [ColorUsage(true, true)]
        public Color baseColorTint = Color.white;

        [Range(0.0f, 2.0f)]
        public float normalScale = 1.0f;

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
            SetTextureIfSupported(material, "_OcclusionMap", orm);
            SetTextureIfSupported(material, "_ORMMap", orm);
            SetColorIfSupported(material, "_BaseColor", baseColorTint);
            SetColorIfSupported(material, "_Color", baseColorTint);
            SetFloatIfSupported(material, "_BumpScale", normalScale);
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
                   metallic >= 0.0f && metallic <= 1.0f &&
                   roughness >= 0.0f && roughness <= 1.0f &&
                   occlusionStrength >= 0.0f && occlusionStrength <= 1.0f &&
                   alpha >= 0.0f && alpha <= 1.0f;
        }

        public void ClampToValidRanges()
        {
            normalScale = ClampFinite(normalScale, MinimumNormalScale, MaximumNormalScale, 1.0f);
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
