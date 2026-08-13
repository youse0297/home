#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace TA.MaterialLab.Editor
{
    public static class RenderDocCaptureBootstrap
    {
        private const string Root = "Assets/_TA";
        private const string RendererPath = Root + "/Settings/RD_MaterialLab_Forward.asset";
        private const string PipelinePath = Root + "/Settings/RP_MaterialLab_URP.asset";
        private const string ScenePath = Root + "/Scenes/SCN_MaterialImportLab.unity";
        private const string ManifestPath = Root + "/Documentation/RenderDocCaptureManifest.json";
        private const string ReportPath = Root + "/Documentation/RenderDocCapturePreparation.json";

        [Serializable]
        private sealed class CaptureManifest
        {
            public string status;
            public string captureStatus;
            public string scene;
            public string renderer;
            public string pipeline;
            public int width;
            public int height;
            public int targetFrameRate;
            public int vSyncCount;
            public float renderScale;
            public int msaaSamples;
            public bool hdr;
            public List<MarkerRecord> markers = new List<MarkerRecord>();
            public List<string> bookmarks = new List<string>();
            public List<string> captureSteps = new List<string>();
        }

        [Serializable]
        private sealed class MarkerRecord
        {
            public string name;
            public int renderPassEvent;
        }

        [MenuItem("TA/Material Lab/Prepare RenderDoc Capture")]
        public static void Prepare()
        {
            EnsureFolders();
            ConfigureCaptureSettings();
            AttachMarkerFeature();
            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(ScenePath, true)
            };
            Scene scene = SceneManager.GetActiveScene();
            if (scene.path != ScenePath)
                scene = EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);
            Camera camera = Camera.main ?? UnityEngine.Object.FindObjectOfType<Camera>();
            if (camera != null)
            {
                camera.allowHDR = true;
                camera.useOcclusionCulling = false;
                camera.targetDisplay = 0;
            }
            WriteManifest();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            Debug.Log("RENDERDOC_CAPTURE_PREPARED: PASS");
        }

        private static void EnsureFolders()
        {
            if (!AssetDatabase.IsValidFolder(Root + "/Documentation"))
                AssetDatabase.CreateFolder(Root, "Documentation");
        }

        private static void ConfigureCaptureSettings()
        {
            PlayerSettings.defaultScreenWidth = 1280;
            PlayerSettings.defaultScreenHeight = 720;
            PlayerSettings.runInBackground = true;
            QualitySettings.vSyncCount = 0;
            Application.targetFrameRate = 30;
            QualitySettings.maxQueuedFrames = 1;
            RenderPipelineAsset pipeline = AssetDatabase.LoadAssetAtPath<RenderPipelineAsset>(PipelinePath);
            if (pipeline != null)
            {
                UniversalRenderPipelineAsset urp = pipeline as UniversalRenderPipelineAsset;
                if (urp != null)
                {
                    urp.renderScale = 1.0f;
                    urp.msaaSampleCount = 1;
                    urp.supportsHDR = true;
                    EditorUtility.SetDirty(urp);
                }
            }
        }

        private static void AttachMarkerFeature()
        {
            ScriptableRendererData rendererData = AssetDatabase.LoadAssetAtPath<ScriptableRendererData>(RendererPath);
            if (rendererData == null)
                throw new InvalidOperationException("Renderer data is unavailable: " + RendererPath);
            RenderDocCaptureFeature feature = rendererData.rendererFeatures
                .OfType<RenderDocCaptureFeature>()
                .FirstOrDefault();
            if (feature == null)
            {
                feature = ScriptableObject.CreateInstance<RenderDocCaptureFeature>();
                feature.name = RenderDocCaptureFeature.FeatureName;
                AssetDatabase.AddObjectToAsset(feature, rendererData);
                rendererData.rendererFeatures.Add(feature);
            }
            feature.SetActive(true);
            feature.Create();
            rendererData.SetDirty();
            EditorUtility.SetDirty(rendererData);
        }

        private static void WriteManifest()
        {
            CaptureManifest manifest = new CaptureManifest
            {
                status = "PREPARED",
                captureStatus = "PENDING_CAPTURE",
                scene = ScenePath,
                renderer = RendererPath,
                pipeline = PipelinePath,
                width = 1280,
                height = 720,
                targetFrameRate = 30,
                vSyncCount = 0,
                renderScale = 1.0f,
                msaaSamples = 1,
                hdr = true,
                bookmarks = new List<string>
                {
                    "RD/Frame/Begin",
                    "RD/Opaque/Boundary",
                    "RD/Lighting/Forward",
                    "RD/Transparent/Boundary",
                    "RD/PostFX/Boundary",
                    "RD/Frame/End"
                },
                captureSteps = new List<string>
                {
                    "Open the project with Unity 2022.3.62f3c1 and activate a valid license.",
                    "Run TA/Material Lab/Prepare RenderDoc Capture.",
                    "Launch the scene at 1280x720 with VSync disabled and capture one stable frame.",
                    "Save the capture as Reports/RenderDoc/MaterialLab_Frame_0001.rdc.",
                    "Use the six RD bookmarks to inspect Opaque, Lighting, Transparent and PostFX boundaries."
                }
            };
            foreach (RenderDocMarkerDefinition marker in RenderDocCaptureFeature.MarkerDefinitions)
            {
                manifest.markers.Add(new MarkerRecord
                {
                    name = marker.name,
                    renderPassEvent = (int)marker.renderPassEvent
                });
            }
            string absoluteManifestPath = Path.Combine(
                Directory.GetParent(Application.dataPath).FullName,
                ManifestPath
            );
            string absoluteReportPath = Path.Combine(
                Directory.GetParent(Application.dataPath).FullName,
                ReportPath
            );
            string json = JsonUtility.ToJson(manifest, true);
            File.WriteAllText(absoluteManifestPath, json);
            File.WriteAllText(absoluteReportPath, json);
            AssetDatabase.ImportAsset(ManifestPath, ImportAssetOptions.ForceSynchronousImport);
            AssetDatabase.ImportAsset(ReportPath, ImportAssetOptions.ForceSynchronousImport);
        }
    }
}
#endif
