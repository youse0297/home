using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace TA.MaterialLab
{
    [Serializable]
    public struct RenderDocMarkerDefinition
    {
        public string name;
        public RenderPassEvent renderPassEvent;

        public RenderDocMarkerDefinition(string name, RenderPassEvent renderPassEvent)
        {
            this.name = name;
            this.renderPassEvent = renderPassEvent;
        }
    }

    public sealed class RenderDocCaptureFeature : ScriptableRendererFeature
    {
        public const string FeatureName = "RD_RenderDocCaptureMarkers";
        public const string BeginMarker = "RD/Frame/Begin";
        public const string OpaqueMarker = "RD/Opaque/Boundary";
        public const string LightingMarker = "RD/Lighting/Forward";
        public const string TransparentMarker = "RD/Transparent/Boundary";
        public const string PostFxMarker = "RD/PostFX/Boundary";
        public const string EndMarker = "RD/Frame/End";

        [SerializeField]
        private bool markersEnabled = true;

        private MarkerPass[] markerPasses;

        public static RenderDocMarkerDefinition[] MarkerDefinitions
        {
            get
            {
                return new[]
                {
                    new RenderDocMarkerDefinition(BeginMarker, RenderPassEvent.BeforeRendering),
                    new RenderDocMarkerDefinition(OpaqueMarker, RenderPassEvent.BeforeRenderingOpaques),
                    new RenderDocMarkerDefinition(LightingMarker, RenderPassEvent.AfterRenderingOpaques),
                    new RenderDocMarkerDefinition(TransparentMarker, RenderPassEvent.AfterRenderingTransparents),
                    new RenderDocMarkerDefinition(PostFxMarker, RenderPassEvent.AfterRenderingPostProcessing),
                    new RenderDocMarkerDefinition(EndMarker, RenderPassEvent.AfterRendering)
                };
            }
        }

        public override void Create()
        {
            RenderDocMarkerDefinition[] definitions = MarkerDefinitions;
            markerPasses = new MarkerPass[definitions.Length];
            for (int index = 0; index < definitions.Length; index++)
                markerPasses[index] = new MarkerPass(definitions[index]);
        }

        public override void AddRenderPasses(
            ScriptableRenderer renderer,
            ref RenderingData renderingData
        )
        {
            if (!markersEnabled || markerPasses == null)
                return;
            foreach (MarkerPass markerPass in markerPasses)
                renderer.EnqueuePass(markerPass);
        }

        private sealed class MarkerPass : ScriptableRenderPass
        {
            private readonly string markerName;

            public MarkerPass(RenderDocMarkerDefinition definition)
            {
                markerName = definition.name;
                renderPassEvent = definition.renderPassEvent;
                base.profilingSampler = new ProfilingSampler(markerName);
            }

            public override void Execute(
                ScriptableRenderContext context,
                ref RenderingData renderingData
            )
            {
                CommandBuffer commandBuffer = CommandBufferPool.Get(markerName);
                using (new ProfilingScope(commandBuffer, base.profilingSampler))
                {
                }
                context.ExecuteCommandBuffer(commandBuffer);
                CommandBufferPool.Release(commandBuffer);
            }
        }
    }
}
