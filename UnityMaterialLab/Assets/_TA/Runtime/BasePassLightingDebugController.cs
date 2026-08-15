using System;
using UnityEngine;

namespace TA.MaterialLab
{
    public enum BasePassDebugView
    {
        FinalLit = 0,
        BaseColor = 1,
        WorldNormal = 2,
        AmbientOcclusion = 3,
        Roughness = 4,
        Metallic = 5,
        DirectDiffuse = 6,
        DirectSpecular = 7,
        IndirectDiffuse = 8,
        ShadowAttenuation = 9
    }

    [ExecuteAlways]
    public sealed class BasePassLightingDebugController : MonoBehaviour
    {
        private static readonly int DebugViewProperty = Shader.PropertyToID("_DebugView");

        [SerializeField]
        private BasePassDebugView debugView = BasePassDebugView.FinalLit;

        [SerializeField]
        private Renderer[] targetRenderers = Array.Empty<Renderer>();

        private MaterialPropertyBlock propertyBlock;

        public BasePassDebugView DebugView
        {
            get { return debugView; }
            set
            {
                debugView = value;
                Apply();
            }
        }

        public void Apply()
        {
            if (targetRenderers == null || targetRenderers.Length == 0)
                targetRenderers = GetComponentsInChildren<Renderer>(true);
            if (propertyBlock == null)
                propertyBlock = new MaterialPropertyBlock();
            foreach (Renderer targetRenderer in targetRenderers)
            {
                if (targetRenderer == null)
                    continue;
                targetRenderer.GetPropertyBlock(propertyBlock);
                propertyBlock.SetFloat(DebugViewProperty, (float)debugView);
                targetRenderer.SetPropertyBlock(propertyBlock);
                propertyBlock.Clear();
            }
        }

        private void Reset()
        {
            targetRenderers = GetComponentsInChildren<Renderer>(true);
            Apply();
        }

        private void OnEnable()
        {
            Apply();
        }

        private void OnValidate()
        {
            Apply();
        }
    }
}
