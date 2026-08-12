using System;
using System.Collections.Generic;
using UnityEngine;

namespace TA.MaterialLab
{
    public static class MaterialBoundaryMatrix
    {
        public const float DielectricF0 = 0.04f;
        public const float MinimumGgxAlpha = 0.0001f;

        public enum Parameter
        {
            Metallic,
            Roughness,
            NormalScale
        }

        [Serializable]
        public sealed class Case
        {
            public string id;
            public Parameter parameter;
            public float value;
            public float metallic;
            public float roughness;
            public float normalScale;
            public float smoothness;
            public float ggxAlpha;
            public float dielectricWeight;
            public string conclusion;
        }

        public static IReadOnlyList<Case> CreateCases()
        {
            List<Case> cases = new List<Case>();
            AddMetallicCases(cases);
            AddRoughnessCases(cases);
            AddNormalCases(cases);
            return cases;
        }

        public static float ToSmoothness(float roughness)
        {
            return 1.0f - Mathf.Clamp01(roughness);
        }

        public static float ToGgxAlpha(float roughness)
        {
            float perceptualRoughness = Mathf.Clamp01(roughness);
            return Mathf.Max(
                perceptualRoughness * perceptualRoughness,
                MinimumGgxAlpha
            );
        }

        public static float DielectricWeight(float metallic)
        {
            return 1.0f - Mathf.Clamp01(metallic);
        }

        public static bool IsPhysicallyValid(Case item)
        {
            if (item == null)
            {
                return false;
            }
            return IsFinite(item.value) &&
                   IsFinite(item.metallic) &&
                   IsFinite(item.roughness) &&
                   IsFinite(item.normalScale) &&
                   IsFinite(item.smoothness) &&
                   IsFinite(item.ggxAlpha) &&
                   IsFinite(item.dielectricWeight) &&
                   item.metallic >= 0.0f && item.metallic <= 1.0f &&
                   item.roughness >= 0.0f && item.roughness <= 1.0f &&
                   item.normalScale >= 0.0f && item.normalScale <= 2.0f &&
                   item.smoothness >= 0.0f && item.smoothness <= 1.0f &&
                   item.ggxAlpha >= MinimumGgxAlpha && item.ggxAlpha <= 1.0f &&
                   item.dielectricWeight >= 0.0f && item.dielectricWeight <= 1.0f;
        }

        private static void AddMetallicCases(List<Case> cases)
        {
            AddCase(cases, "M00", Parameter.Metallic, 0.0f, 0.0f, 0.45f, 1.0f,
                "Dielectric endpoint; diffuse contribution is preserved.");
            AddCase(cases, "M05", Parameter.Metallic, 0.5f, 0.5f, 0.45f, 1.0f,
                "Transition sample; diffuse weight is halved.");
            AddCase(cases, "M10", Parameter.Metallic, 1.0f, 1.0f, 0.45f, 1.0f,
                "Metal endpoint; dielectric diffuse contribution reaches zero.");
        }

        private static void AddRoughnessCases(List<Case> cases)
        {
            AddCase(cases, "R00", Parameter.Roughness, 0.0f, 0.0f, 0.0f, 1.0f,
                "Mirror-like endpoint; GGX alpha uses the numerical floor.");
            AddCase(cases, "R025", Parameter.Roughness, 0.25f, 0.0f, 0.25f, 1.0f,
                "Narrow highlight with alpha 0.0625.");
            AddCase(cases, "R05", Parameter.Roughness, 0.5f, 0.0f, 0.5f, 1.0f,
                "Midpoint reference with alpha 0.25.");
            AddCase(cases, "R075", Parameter.Roughness, 0.75f, 0.0f, 0.75f, 1.0f,
                "Broad highlight with alpha 0.5625.");
            AddCase(cases, "R10", Parameter.Roughness, 1.0f, 0.0f, 1.0f, 1.0f,
                "Fully rough endpoint; smoothness is zero.");
        }

        private static void AddNormalCases(List<Case> cases)
        {
            AddCase(cases, "N00", Parameter.NormalScale, 0.0f, 0.0f, 0.45f, 0.0f,
                "Normal map disabled; geometry normal remains the reference.");
            AddCase(cases, "N10", Parameter.NormalScale, 1.0f, 0.0f, 0.45f, 1.0f,
                "Authored tangent-space normal strength.");
            AddCase(cases, "N20", Parameter.NormalScale, 2.0f, 0.0f, 0.45f, 2.0f,
                "Upper validation limit; stronger values risk shading distortion.");
        }

        private static void AddCase(
            ICollection<Case> cases,
            string id,
            Parameter parameter,
            float value,
            float metallic,
            float roughness,
            float normalScale,
            string conclusion
        )
        {
            cases.Add(new Case
            {
                id = id,
                parameter = parameter,
                value = value,
                metallic = metallic,
                roughness = roughness,
                normalScale = normalScale,
                smoothness = ToSmoothness(roughness),
                ggxAlpha = ToGgxAlpha(roughness),
                dielectricWeight = DielectricWeight(metallic),
                conclusion = conclusion
            });
        }

        private static bool IsFinite(float value)
        {
            return !float.IsNaN(value) && !float.IsInfinity(value);
        }
    }
}
