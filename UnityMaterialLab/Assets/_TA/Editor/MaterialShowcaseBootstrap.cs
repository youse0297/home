#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace TA.MaterialLab.Editor
{
    public static class MaterialShowcaseBootstrap
    {
        private const string Root = "Assets/_TA";
        private const string BasePassShaderName = "TA/BasePass Lighting Decomposition";
        private const string TransparentShaderName = "TA/Transparent Refraction";
        private const string ScenePath = Root + "/Scenes/SCN_MaterialShowcase.unity";
        private const string MaterialRoot = Root + "/Materials/Showcase";
        private const string ReportPath = Root + "/Documentation/MaterialShowcase.json";
        private const string BaseColorPath = Root + "/Art/Textures/T_CC0_Crate_BaseColor.png";
        private const string NormalPath = Root + "/Art/Textures/T_PBR_Normal.png";
        private const string OrmPath = Root + "/Art/Textures/T_PBR_ORM.png";

        private sealed class ShowcaseDefinition
        {
            public string Id;
            public string Label;
            public string Module;
            public PrimitiveType Primitive;
            public bool Transparent;
            public Action<Material> Configure;
        }

        [Serializable]
        private sealed class ShowcaseReport
        {
            public string status;
            public string version;
            public string scene;
            public string camera;
            public string lighting;
            public string generatedAtUtc;
            public List<ShowcaseRecord> showcases = new List<ShowcaseRecord>();
            public List<string> validationChecklist = new List<string>();
        }

        [Serializable]
        private sealed class ShowcaseRecord
        {
            public string id;
            public string label;
            public string module;
            public string material;
            public string primitive;
        }

        [MenuItem("TA/Material Lab/Build Material Showcase")]
        public static void Build()
        {
            EnsureFolder(MaterialRoot);
            Shader basePassShader = RequireShader(BasePassShaderName);
            Shader transparentShader = RequireShader(TransparentShaderName);
            List<ShowcaseDefinition> definitions = CreateDefinitions();
            Dictionary<string, Material> materials = CreateMaterials(
                definitions,
                basePassShader,
                transparentShader
            );
            BuildScene(definitions, materials);
            WriteReport(definitions, "EDITOR_SCENE_GENERATED");
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            Debug.Log("UNITY_MATERIAL_SHOWCASE: PASS");
        }

        private static Shader RequireShader(string shaderName)
        {
            Shader shader = Shader.Find(shaderName);
            if (shader == null || !shader.isSupported)
                throw new InvalidOperationException("Showcase shader is unavailable: " + shaderName);
            return shader;
        }

        private static void EnsureFolder(string folder)
        {
            string[] parts = folder.Split('/');
            string current = parts[0];
            for (int index = 1; index < parts.Length; index++)
            {
                string next = current + "/" + parts[index];
                if (!AssetDatabase.IsValidFolder(next))
                    AssetDatabase.CreateFolder(current, parts[index]);
                current = next;
            }
        }

        private static List<ShowcaseDefinition> CreateDefinitions()
        {
            return new List<ShowcaseDefinition>
            {
                new ShowcaseDefinition
                {
                    Id = "BASE_PBR",
                    Label = "Base PBR",
                    Module = "TA_MaterialInterface",
                    Primitive = PrimitiveType.Sphere,
                    Configure = material =>
                    {
                        material.SetColor("_BaseColor", new Color(0.82f, 0.34f, 0.12f, 1.0f));
                        material.SetFloat("_RoughnessScale", 0.55f);
                        material.SetFloat("_MetallicScale", 0.0f);
                    }
                },
                new ShowcaseDefinition
                {
                    Id = "LAYERED_NORMAL",
                    Label = "Layered Normal",
                    Module = "TA_NormalBlend",
                    Primitive = PrimitiveType.Sphere,
                    Configure = material =>
                    {
                        material.SetTexture("_DetailNormalMap", LoadTexture(NormalPath));
                        material.SetTextureScale("_DetailNormalMap", new Vector2(4.0f, 4.0f));
                        material.SetTexture("_MacroNormalMap", LoadTexture(NormalPath));
                        material.SetTextureScale("_MacroNormalMap", new Vector2(0.5f, 0.5f));
                        material.SetFloat("_DetailNormalWeight", 0.65f);
                        material.SetFloat("_MacroNormalWeight", 0.35f);
                        material.SetFloat("_ProceduralMaskStrength", 0.75f);
                    }
                },
                new ShowcaseDefinition
                {
                    Id = "EDGE_WEAR",
                    Label = "Edge Wear",
                    Module = "TA_EdgeWear",
                    Primitive = PrimitiveType.Cube,
                    Configure = material =>
                    {
                        material.SetColor("_BaseColor", new Color(0.12f, 0.24f, 0.52f, 1.0f));
                        material.SetColor("_EdgeWearColor", new Color(1.0f, 0.42f, 0.08f, 1.0f));
                        material.SetFloat("_EdgeWearThreshold", 0.58f);
                        material.SetFloat("_EdgeWearSoftness", 0.24f);
                        material.SetFloat("_EdgeWearStrength", 0.85f);
                        material.SetFloat("_EdgeWearRoughnessBoost", 0.35f);
                    }
                },
                new ShowcaseDefinition
                {
                    Id = "SNOW_COVER",
                    Label = "Snow Cover",
                    Module = "TA_SnowCover",
                    Primitive = PrimitiveType.Capsule,
                    Configure = material =>
                    {
                        material.SetColor("_BaseColor", new Color(0.16f, 0.22f, 0.18f, 1.0f));
                        material.SetFloat("_SnowCoverage", 0.72f);
                        material.SetFloat("_SnowNormalThreshold", 0.48f);
                        material.SetFloat("_SnowNormalSoftness", 0.22f);
                        material.SetFloat("_SnowRoughness", 0.84f);
                        material.SetFloat("_SnowHeightBlend", 0.35f);
                        material.SetFloat("_SnowHeightStart", 0.3f);
                        material.SetFloat("_SnowHeightFade", 1.4f);
                    }
                },
                new ShowcaseDefinition
                {
                    Id = "ANISOTROPIC_METAL",
                    Label = "Anisotropic Metal",
                    Module = "TA_Anisotropy",
                    Primitive = PrimitiveType.Sphere,
                    Configure = material =>
                    {
                        material.SetColor("_BaseColor", new Color(0.72f, 0.34f, 0.08f, 1.0f));
                        material.SetFloat("_RoughnessScale", 0.42f);
                        material.SetFloat("_MetallicScale", 1.0f);
                        material.SetFloat("_Anisotropy", 0.72f);
                        material.SetFloat("_AnisotropyRotation", 0.35f);
                    }
                },
                new ShowcaseDefinition
                {
                    Id = "TRANSPARENT_REFRACTION",
                    Label = "Transparent Refraction",
                    Module = "TA_TransparencyRefraction",
                    Primitive = PrimitiveType.Sphere,
                    Transparent = true,
                    Configure = material =>
                    {
                        material.SetColor("_BaseColor", new Color(0.20f, 0.65f, 0.80f, 1.0f));
                        material.SetFloat("_RoughnessScale", 0.25f);
                        material.SetFloat("_Opacity", 0.12f);
                        material.SetFloat("_IndexOfRefraction", 1.5f);
                        material.SetFloat("_Thickness", 0.6f);
                        material.SetColor("_AbsorptionCoefficient", new Color(0.08f, 0.025f, 0.01f, 1.0f));
                        material.SetFloat("_RefractionStrength", 0.025f);
                    }
                }
            };
        }

        private static Dictionary<string, Material> CreateMaterials(
            IEnumerable<ShowcaseDefinition> definitions,
            Shader basePassShader,
            Shader transparentShader
        )
        {
            Dictionary<string, Material> materials = new Dictionary<string, Material>();
            Texture2D baseColor = LoadTexture(BaseColorPath);
            Texture2D normal = LoadTexture(NormalPath);
            Texture2D orm = LoadTexture(OrmPath);
            foreach (ShowcaseDefinition definition in definitions)
            {
                string materialPath = MaterialPath(definition.Id);
                Material material = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
                Shader shader = definition.Transparent ? transparentShader : basePassShader;
                if (material == null)
                {
                    material = new Material(shader) { name = "MAT_Showcase_" + definition.Id };
                    AssetDatabase.CreateAsset(material, materialPath);
                }
                else
                {
                    material.shader = shader;
                }

                material.SetTexture("_BaseMap", baseColor);
                material.SetTexture("_BumpMap", normal);
                material.SetTexture("_ORMMap", orm);
                material.SetColor("_BaseColor", Color.white);
                material.SetFloat("_BumpScale", 1.0f);
                material.SetFloat("_AOStrength", 1.0f);
                material.SetFloat("_RoughnessScale", 1.0f);
                material.SetFloat("_MetallicScale", 0.0f);
                if (!definition.Transparent)
                    ResetOpaqueExtensions(material);
                definition.Configure(material);
                EditorUtility.SetDirty(material);
                materials.Add(definition.Id, material);
            }
            return materials;
        }

        private static void ResetOpaqueExtensions(Material material)
        {
            material.SetTexture("_DetailNormalMap", LoadTexture(NormalPath));
            material.SetTexture("_MacroNormalMap", LoadTexture(NormalPath));
            material.SetFloat("_DetailNormalWeight", 0.0f);
            material.SetFloat("_MacroNormalWeight", 0.0f);
            material.SetFloat("_ProceduralMaskStrength", 0.0f);
            material.SetFloat("_EdgeWearStrength", 0.0f);
            material.SetFloat("_SnowCoverage", 0.0f);
            material.SetFloat("_Anisotropy", 0.0f);
            material.SetFloat("_AnisotropyRotation", 0.0f);
            material.SetFloat("_DisplacementAmplitude", 0.0f);
            material.SetFloat("_WaveAmplitude", 0.0f);
            material.SetFloat("_WindAmplitude", 0.0f);
            material.SetFloat("_DebugView", 0.0f);
        }

        private static Texture2D LoadTexture(string path)
        {
            Texture2D texture = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            if (texture == null)
                throw new InvalidOperationException("Showcase texture is unavailable: " + path);
            return texture;
        }

        private static void BuildScene(
            IList<ShowcaseDefinition> definitions,
            IReadOnlyDictionary<string, Material> materials
        )
        {
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.085f, 0.10f, 0.14f, 1.0f);

            GameObject root = new GameObject("SHOWCASE_MaterialModules");
            for (int index = 0; index < definitions.Count; index++)
            {
                int column = index % 3;
                int row = index / 3;
                Vector3 position = new Vector3((column - 1) * 3.7f, 1.55f - row * 3.5f, 0.0f);
                CreateStand(root.transform, definitions[index], position, materials[definitions[index].Id]);
            }
            CreateBackdrop(root.transform);
            CreateCamera();
            CreateLighting();

            EditorSceneManager.SaveScene(scene, ScenePath);
            List<EditorBuildSettingsScene> buildScenes = new List<EditorBuildSettingsScene>(EditorBuildSettings.scenes);
            if (!buildScenes.Exists(item => item.path == ScenePath))
                buildScenes.Add(new EditorBuildSettingsScene(ScenePath, true));
            EditorBuildSettings.scenes = buildScenes.ToArray();
        }

        private static void CreateStand(
            Transform parent,
            ShowcaseDefinition definition,
            Vector3 position,
            Material material
        )
        {
            GameObject stand = new GameObject("STAND_" + definition.Id);
            stand.transform.SetParent(parent, false);
            stand.transform.localPosition = position;

            GameObject sample = GameObject.CreatePrimitive(definition.Primitive);
            sample.name = "GEO_" + definition.Id;
            sample.transform.SetParent(stand.transform, false);
            sample.transform.localPosition = new Vector3(0.0f, 0.25f, 0.0f);
            sample.transform.localScale = definition.Primitive == PrimitiveType.Cube
                ? new Vector3(1.55f, 1.55f, 1.55f)
                : Vector3.one * 1.65f;
            sample.GetComponent<MeshRenderer>().sharedMaterial = material;

            GameObject pedestal = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            pedestal.name = "GEO_Pedestal_" + definition.Id;
            pedestal.transform.SetParent(stand.transform, false);
            pedestal.transform.localPosition = new Vector3(0.0f, -0.92f, 0.0f);
            pedestal.transform.localScale = new Vector3(1.15f, 0.12f, 1.15f);

            GameObject labelObject = new GameObject("TXT_" + definition.Id);
            labelObject.transform.SetParent(stand.transform, false);
            labelObject.transform.localPosition = new Vector3(0.0f, -1.55f, -0.05f);
            TextMesh label = labelObject.AddComponent<TextMesh>();
            label.text = definition.Label + "\n" + definition.Module;
            label.anchor = TextAnchor.MiddleCenter;
            label.alignment = TextAlignment.Center;
            label.fontSize = 48;
            label.characterSize = 0.037f;
            label.color = new Color(0.86f, 0.91f, 0.98f, 1.0f);
        }

        private static void CreateBackdrop(Transform parent)
        {
            GameObject backdrop = GameObject.CreatePrimitive(PrimitiveType.Cube);
            backdrop.name = "ENV_ShowcaseBackdrop";
            backdrop.transform.SetParent(parent, false);
            backdrop.transform.localPosition = new Vector3(0.0f, -0.4f, 2.8f);
            backdrop.transform.localScale = new Vector3(12.5f, 7.7f, 0.2f);
        }

        private static void CreateCamera()
        {
            GameObject cameraObject = new GameObject("CAM_MaterialShowcase");
            cameraObject.tag = "MainCamera";
            Camera camera = cameraObject.AddComponent<Camera>();
            cameraObject.transform.position = new Vector3(0.0f, 0.1f, -13.8f);
            cameraObject.transform.LookAt(new Vector3(0.0f, -0.1f, 0.0f));
            camera.fieldOfView = 43.0f;
            camera.nearClipPlane = 0.1f;
            camera.farClipPlane = 50.0f;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.018f, 0.026f, 0.045f, 1.0f);
            camera.allowHDR = true;
        }

        private static void CreateLighting()
        {
            GameObject keyObject = new GameObject("LGT_Showcase_Key");
            Light key = keyObject.AddComponent<Light>();
            key.type = LightType.Directional;
            key.color = new Color(1.0f, 0.90f, 0.78f, 1.0f);
            key.intensity = 2.8f;
            key.shadows = LightShadows.Soft;
            keyObject.transform.rotation = Quaternion.Euler(36.0f, -32.0f, 0.0f);
            RenderSettings.sun = key;

            GameObject rimObject = new GameObject("LGT_Showcase_Rim");
            Light rim = rimObject.AddComponent<Light>();
            rim.type = LightType.Point;
            rim.color = new Color(0.28f, 0.58f, 1.0f, 1.0f);
            rim.intensity = 7.0f;
            rim.range = 18.0f;
            rimObject.transform.position = new Vector3(-5.0f, 3.2f, -2.0f);
        }

        private static void WriteReport(IEnumerable<ShowcaseDefinition> definitions, string status)
        {
            ShowcaseReport report = new ShowcaseReport
            {
                status = status,
                version = "1.0.0",
                scene = ScenePath,
                camera = "CAM_MaterialShowcase; 43 degree FOV; fixed 16:9 framing",
                lighting = "Linear color; flat ambient; one directional key and one point rim",
                generatedAtUtc = DateTime.UtcNow.ToString("O"),
                validationChecklist = new List<string>
                {
                    "All six stands are visible in one camera frame",
                    "Every stand has a unique material asset and module label",
                    "Opaque stands use TA/BasePass Lighting Decomposition with FinalLit output",
                    "Transparent stand uses TA/Transparent Refraction and URP Opaque Texture",
                    "No stand enables displacement, wave or wind without a matching dense mesh and shadow pass",
                    "Runtime screenshot must be saved separately from the offline reference board"
                }
            };
            foreach (ShowcaseDefinition definition in definitions)
            {
                report.showcases.Add(new ShowcaseRecord
                {
                    id = definition.Id,
                    label = definition.Label,
                    module = definition.Module,
                    material = MaterialPath(definition.Id),
                    primitive = definition.Primitive.ToString()
                });
            }
            string absolutePath = Path.Combine(Directory.GetParent(Application.dataPath).FullName, ReportPath);
            File.WriteAllText(absolutePath, JsonUtility.ToJson(report, true));
            AssetDatabase.ImportAsset(ReportPath, ImportAssetOptions.ForceSynchronousImport);
        }

        private static string MaterialPath(string id)
        {
            return MaterialRoot + "/MAT_Showcase_" + id + ".mat";
        }
    }
}
#endif
