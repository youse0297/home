#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using TA.MaterialLab;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace TA.MaterialLab.Editor
{
    public static class BasePassLightingBootstrap
    {
        private const string Root = "Assets/_TA";
        private const string ShaderName = "TA/BasePass Lighting Decomposition";
        private const string ScenePath = Root + "/BasePass/SCN_BasePassLightingDecomposition.unity";
        private const string MaterialPath = Root + "/Materials/MAT_BasePassLightingDecomposition.mat";
        private const string BaseColorPath = Root + "/Art/Textures/T_CC0_Crate_BaseColor.png";
        private const string NormalPath = Root + "/Art/Textures/T_PBR_Normal.png";
        private const string OrmPath = Root + "/Art/Textures/T_PBR_ORM.png";
        private const string ReportPath = Root + "/Documentation/BasePassLightingDecomposition.json";

        [Serializable]
        private sealed class DecompositionReport
        {
            public string status;
            public string version;
            public string renderPath;
            public string shader;
            public string material;
            public string scene;
            public string colorSpace;
            public string generatedAtUtc;
            public List<DebugViewRecord> debugViews = new List<DebugViewRecord>();
            public List<string> invariants = new List<string>();
        }

        [Serializable]
        private sealed class DebugViewRecord
        {
            public int id;
            public string name;
            public string category;
            public string output;
        }

        [MenuItem("TA/Material Lab/Build BasePass Lighting Decomposition")]
        public static void Build()
        {
            EnsureFolder(Root, "BasePass");
            Shader shader = Shader.Find(ShaderName);
            if (shader == null || !shader.isSupported)
                throw new InvalidOperationException("BasePass decomposition shader is unavailable: " + ShaderName);
            Material material = CreateMaterial(shader);
            BuildScene(material);
            WriteReport("EDITOR_SCENE_GENERATED");
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            Debug.Log("TA_BASEPASS_LIGHTING_DECOMPOSITION: PASS");
        }

        private static void EnsureFolder(string parent, string child)
        {
            string path = parent + "/" + child;
            if (!AssetDatabase.IsValidFolder(path))
                AssetDatabase.CreateFolder(parent, child);
        }

        private static Material CreateMaterial(Shader shader)
        {
            Material material = AssetDatabase.LoadAssetAtPath<Material>(MaterialPath);
            if (material == null)
            {
                material = new Material(shader) { name = "MAT_BasePassLightingDecomposition" };
                AssetDatabase.CreateAsset(material, MaterialPath);
            }
            else
            {
                material.shader = shader;
            }

            material.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(BaseColorPath));
            material.SetTexture("_BumpMap", AssetDatabase.LoadAssetAtPath<Texture2D>(NormalPath));
            material.SetTexture("_ORMMap", AssetDatabase.LoadAssetAtPath<Texture2D>(OrmPath));
            material.SetColor("_BaseColor", Color.white);
            material.SetFloat("_BumpScale", 1.0f);
            material.SetFloat("_AOStrength", 1.0f);
            material.SetFloat("_RoughnessScale", 1.0f);
            material.SetFloat("_MetallicScale", 1.0f);
            material.SetFloat("_DebugView", 0.0f);
            EditorUtility.SetDirty(material);
            return material;
        }

        private static void BuildScene(Material material)
        {
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.08f, 0.10f, 0.14f, 1.0f);

            GameObject samplesRoot = new GameObject("GEO_BasePassLightingSamples");
            BasePassDebugView[] debugViews = (BasePassDebugView[])Enum.GetValues(
                typeof(BasePassDebugView)
            );
            for (int index = 0; index < debugViews.Length; index++)
            {
                int column = index % 5;
                int row = index / 5;
                Vector3 position = new Vector3((column - 2) * 2.35f, 2.1f - row * 3.0f, 0.0f);
                CreateSample(samplesRoot.transform, debugViews[index], position, material);
            }

            GameObject cameraObject = new GameObject("CAM_BasePassLighting");
            cameraObject.tag = "MainCamera";
            Camera camera = cameraObject.AddComponent<Camera>();
            cameraObject.transform.position = new Vector3(0.0f, 1.2f, -14.5f);
            cameraObject.transform.LookAt(new Vector3(0.0f, 0.6f, 0.0f));
            camera.fieldOfView = 42.0f;
            camera.nearClipPlane = 0.1f;
            camera.farClipPlane = 50.0f;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.025f, 0.035f, 0.055f, 1.0f);
            camera.allowHDR = true;

            GameObject lightObject = new GameObject("LGT_BasePass_Key");
            Light light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(1.0f, 0.92f, 0.82f, 1.0f);
            light.intensity = 3.0f;
            light.shadows = LightShadows.Soft;
            lightObject.transform.rotation = Quaternion.Euler(38.0f, -32.0f, 0.0f);
            RenderSettings.sun = light;

            EditorSceneManager.SaveScene(scene, ScenePath);
            List<EditorBuildSettingsScene> buildScenes = new List<EditorBuildSettingsScene>(
                EditorBuildSettings.scenes
            );
            if (!buildScenes.Exists(item => item.path == ScenePath))
                buildScenes.Add(new EditorBuildSettingsScene(ScenePath, true));
            EditorBuildSettings.scenes = buildScenes.ToArray();
        }

        private static void CreateSample(
            Transform parent,
            BasePassDebugView debugView,
            Vector3 position,
            Material material
        )
        {
            GameObject sampleRoot = new GameObject("VIEW_" + debugView);
            sampleRoot.transform.SetParent(parent, false);
            sampleRoot.transform.localPosition = position;

            GameObject sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sphere.name = "GEO_" + debugView;
            sphere.transform.SetParent(sampleRoot.transform, false);
            sphere.GetComponent<MeshRenderer>().sharedMaterial = material;
            BasePassLightingDebugController controller =
                sphere.AddComponent<BasePassLightingDebugController>();
            controller.DebugView = debugView;

            GameObject labelObject = new GameObject("TXT_" + debugView);
            labelObject.transform.SetParent(sampleRoot.transform, false);
            labelObject.transform.localPosition = new Vector3(0.0f, -0.82f, 0.0f);
            TextMesh label = labelObject.AddComponent<TextMesh>();
            label.text = ((int)debugView) + "  " + debugView;
            label.anchor = TextAnchor.MiddleCenter;
            label.alignment = TextAlignment.Center;
            label.fontSize = 48;
            label.characterSize = 0.045f;
            label.color = new Color(0.86f, 0.90f, 0.96f, 1.0f);
        }

        private static void WriteReport(string status)
        {
            DecompositionReport report = new DecompositionReport
            {
                status = status,
                version = "1.0.0",
                renderPath = "URP Forward / UniversalForward",
                shader = ShaderName,
                material = MaterialPath,
                scene = ScenePath,
                colorSpace = "Linear HDR; display transform is applied by URP",
                generatedAtUtc = DateTime.UtcNow.ToString("O"),
                invariants = new List<string>
                {
                    "FinalLit = DirectDiffuse + DirectSpecular + IndirectDiffuse",
                    "BaseColor is sampled as sRGB and consumed as linear by Unity",
                    "Normal, AO, roughness and metallic data textures are sampled as linear",
                    "Debug views do not apply fog, exposure or tone mapping in the material pass"
                }
            };
            foreach (BasePassDebugView debugView in Enum.GetValues(typeof(BasePassDebugView)))
                report.debugViews.Add(CreateDebugViewRecord(debugView));
            string absolutePath = Path.Combine(
                Directory.GetParent(Application.dataPath).FullName,
                ReportPath
            );
            File.WriteAllText(absolutePath, JsonUtility.ToJson(report, true));
            AssetDatabase.ImportAsset(ReportPath, ImportAssetOptions.ForceSynchronousImport);
        }

        private static DebugViewRecord CreateDebugViewRecord(BasePassDebugView debugView)
        {
            string category = (int)debugView == 0
                ? "Composite"
                : (int)debugView <= 5 ? "Surface" : "Lighting";
            string output;
            switch (debugView)
            {
                case BasePassDebugView.FinalLit:
                    output = "DirectDiffuse + DirectSpecular + IndirectDiffuse";
                    break;
                case BasePassDebugView.WorldNormal:
                    output = "NormalWS * 0.5 + 0.5";
                    break;
                case BasePassDebugView.ShadowAttenuation:
                    output = "MainLight.shadowAttenuation";
                    break;
                default:
                    output = debugView.ToString();
                    break;
            }
            return new DebugViewRecord
            {
                id = (int)debugView,
                name = debugView.ToString(),
                category = category,
                output = output
            };
        }
    }
}
#endif
