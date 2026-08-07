#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace TA.MaterialLab.Editor
{
    public static class ProjectBootstrap
    {
        private const string Root = "Assets/_TA";
        private const string ModelPath = Root + "/Art/Models/SM_CC0_DisplayCrate.obj";
        private const string TexturePath = Root + "/Art/Textures/T_CC0_Crate_BaseColor.png";
        private const string PipelinePath = Root + "/Settings/RP_MaterialLab_URP.asset";
        private const string RendererPath = Root + "/Settings/RD_MaterialLab_Forward.asset";
        private const string BallPrefabPath = Root + "/Prefabs/PF_MaterialBall.prefab";
        private const string CratePrefabPath = Root + "/Prefabs/PF_CC0_DisplayCrate.prefab";
        private const string ScenePath = Root + "/Scenes/SCN_MaterialImportLab.unity";
        private const string ScreenshotPath = Root + "/Documentation/UnityAssetImportBaseline.png";
        private const string ReportPath = Root + "/Documentation/ImportValidation.json";

        private const string DielectricMaterialPath = Root + "/Materials/MAT_Baseline_Dielectric.mat";
        private const string RoughMetalMaterialPath = Root + "/Materials/MAT_Baseline_RoughMetal.mat";
        private const string SmoothMetalMaterialPath = Root + "/Materials/MAT_Baseline_SmoothMetal.mat";
        private const string CrateMaterialPath = Root + "/Materials/MAT_CC0_DisplayCrate.mat";
        private const string FloorMaterialPath = Root + "/Materials/MAT_Environment_Floor.mat";

        [Serializable]
        private sealed class ValidationReport
        {
            public string status;
            public string editorVersion;
            public string renderPipeline;
            public string scene;
            public int importedMeshCount;
            public int importedVertexCount;
            public int screenshotWidth;
            public int screenshotHeight;
            public string generatedAtUtc;
            public List<string> checks = new List<string>();
            public List<string> errors = new List<string>();
        }

        [MenuItem("TA/Material Lab/Build Test Scene")]
        public static void Build()
        {
            try
            {
                EnsureFolders();
                ConfigureProject();
                AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
                ConfigureImporters();
                RenderPipelineAsset pipeline = CreatePipeline();
                Dictionary<string, Material> materials = CreateMaterials();
                CreatePrefabs(materials);
                Camera camera = CreateScene(materials);
                CaptureBaseline(camera);
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
                ValidateInternal();
                Debug.Log("UNITY_PROJECT_BOOTSTRAP: PASS");
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                throw;
            }
        }

        [MenuItem("TA/Material Lab/Validate Project")]
        public static void Validate()
        {
            try
            {
                AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
                ValidateInternal();
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                throw;
            }
        }

        private static void EnsureFolders()
        {
            string[] folders =
            {
                Root,
                Root + "/Art",
                Root + "/Art/Models",
                Root + "/Art/Textures",
                Root + "/Documentation",
                Root + "/Editor",
                Root + "/Materials",
                Root + "/Prefabs",
                Root + "/Scenes",
                Root + "/Settings"
            };
            foreach (string folder in folders)
            {
                EnsureFolder(folder);
            }
        }

        private static void EnsureFolder(string folder)
        {
            string[] parts = folder.Split('/');
            string current = parts[0];
            for (int index = 1; index < parts.Length; ++index)
            {
                string next = current + "/" + parts[index];
                if (!AssetDatabase.IsValidFolder(next))
                {
                    AssetDatabase.CreateFolder(current, parts[index]);
                }
                current = next;
            }
        }

        private static void ConfigureProject()
        {
            PlayerSettings.companyName = "TA Learning Lab";
            PlayerSettings.productName = "Unity Material Lab";
            PlayerSettings.colorSpace = ColorSpace.Linear;
            EditorSettings.serializationMode = SerializationMode.ForceText;
            EditorSettings.defaultBehaviorMode = EditorBehaviorMode.Mode3D;
            EditorSettings.spritePackerMode = SpritePackerMode.Disabled;
            AssetDatabase.SaveAssets();
        }

        private static void ConfigureImporters()
        {
            AssetDatabase.ImportAsset(
                ModelPath,
                ImportAssetOptions.ForceUpdate |
                ImportAssetOptions.ForceSynchronousImport
            );
            ModelImporter modelImporter = AssetImporter.GetAtPath(ModelPath) as ModelImporter;
            if (modelImporter == null)
            {
                throw new BuildFailedException("Model importer is unavailable: " + ModelPath);
            }
            modelImporter.globalScale = 1.0f;
            modelImporter.useFileScale = true;
            modelImporter.importNormals = ModelImporterNormals.Import;
            modelImporter.importTangents = ModelImporterTangents.CalculateMikk;
            modelImporter.generateSecondaryUV = true;
            modelImporter.materialImportMode = ModelImporterMaterialImportMode.None;
            modelImporter.importAnimation = false;
            modelImporter.importCameras = false;
            modelImporter.importLights = false;
            modelImporter.isReadable = false;
            modelImporter.meshCompression = ModelImporterMeshCompression.Off;
            modelImporter.SaveAndReimport();
            AssetDatabase.SetLabels(
                AssetDatabase.LoadMainAssetAtPath(ModelPath),
                new[] { "TA", "ImportedAsset", "CC0", "Model" }
            );

            AssetDatabase.ImportAsset(
                TexturePath,
                ImportAssetOptions.ForceUpdate |
                ImportAssetOptions.ForceSynchronousImport
            );
            TextureImporter textureImporter =
                AssetImporter.GetAtPath(TexturePath) as TextureImporter;
            if (textureImporter == null)
            {
                throw new BuildFailedException("Texture importer is unavailable: " + TexturePath);
            }
            textureImporter.textureType = TextureImporterType.Default;
            textureImporter.sRGBTexture = true;
            textureImporter.alphaSource = TextureImporterAlphaSource.None;
            textureImporter.mipmapEnabled = true;
            textureImporter.wrapMode = TextureWrapMode.Repeat;
            textureImporter.filterMode = FilterMode.Bilinear;
            textureImporter.textureCompression = TextureImporterCompression.Uncompressed;
            textureImporter.maxTextureSize = 256;
            textureImporter.SaveAndReimport();
            AssetDatabase.SetLabels(
                AssetDatabase.LoadMainAssetAtPath(TexturePath),
                new[] { "TA", "ImportedAsset", "CC0", "BaseColor" }
            );
        }

        private static RenderPipelineAsset CreatePipeline()
        {
            Type rendererDataType = FindType(
                "UnityEngine.Rendering.Universal.UniversalRendererData"
            );
            Type pipelineType = FindType(
                "UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset"
            );
            ScriptableObject rendererData =
                AssetDatabase.LoadAssetAtPath<ScriptableObject>(RendererPath);
            if (rendererData == null)
            {
                rendererData = ScriptableObject.CreateInstance(rendererDataType);
                rendererData.name = "RD_MaterialLab_Forward";
                AssetDatabase.CreateAsset(rendererData, RendererPath);
            }

            RenderPipelineAsset pipeline =
                AssetDatabase.LoadAssetAtPath<RenderPipelineAsset>(PipelinePath);
            if (pipeline == null)
            {
                MethodInfo createMethod = pipelineType
                    .GetMethods(BindingFlags.Public | BindingFlags.Static)
                    .FirstOrDefault(method =>
                        method.Name == "Create" &&
                        method.GetParameters().Length == 1
                    );
                if (createMethod == null)
                {
                    throw new BuildFailedException(
                        "URP asset factory method is unavailable."
                    );
                }
                pipeline = createMethod.Invoke(
                    null,
                    new object[] { rendererData }
                ) as RenderPipelineAsset;
                if (pipeline == null)
                {
                    throw new BuildFailedException("URP asset creation failed.");
                }
                pipeline.name = "RP_MaterialLab_URP";
                AssetDatabase.CreateAsset(pipeline, PipelinePath);
            }
            GraphicsSettings.renderPipelineAsset = pipeline;
            QualitySettings.renderPipeline = pipeline;
            EditorUtility.SetDirty(pipeline);
            AssetDatabase.SaveAssets();
            return pipeline;
        }

        private static Dictionary<string, Material> CreateMaterials()
        {
            Shader shader = Shader.Find("Universal Render Pipeline/Lit");
            if (shader == null || !shader.isSupported)
            {
                throw new BuildFailedException("URP Lit shader is unavailable or unsupported.");
            }
            Texture2D crateTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(TexturePath);
            if (crateTexture == null)
            {
                throw new BuildFailedException("Imported crate texture is unavailable.");
            }

            return new Dictionary<string, Material>
            {
                {
                    "dielectric",
                    CreateMaterial(
                        DielectricMaterialPath,
                        shader,
                        new Color(0.56f, 0.13f, 0.06f, 1.0f),
                        0.0f,
                        0.18f,
                        null
                    )
                },
                {
                    "roughMetal",
                    CreateMaterial(
                        RoughMetalMaterialPath,
                        shader,
                        new Color(0.82f, 0.54f, 0.13f, 1.0f),
                        1.0f,
                        0.34f,
                        null
                    )
                },
                {
                    "smoothMetal",
                    CreateMaterial(
                        SmoothMetalMaterialPath,
                        shader,
                        new Color(0.82f, 0.54f, 0.13f, 1.0f),
                        1.0f,
                        0.82f,
                        null
                    )
                },
                {
                    "crate",
                    CreateMaterial(
                        CrateMaterialPath,
                        shader,
                        Color.white,
                        0.0f,
                        0.42f,
                        crateTexture
                    )
                },
                {
                    "floor",
                    CreateMaterial(
                        FloorMaterialPath,
                        shader,
                        new Color(0.16f, 0.18f, 0.21f, 1.0f),
                        0.0f,
                        0.12f,
                        null
                    )
                }
            };
        }

        private static Material CreateMaterial(
            string path,
            Shader shader,
            Color baseColor,
            float metallic,
            float smoothness,
            Texture2D baseMap
        )
        {
            Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                material = new Material(shader);
                material.name = Path.GetFileNameWithoutExtension(path);
                AssetDatabase.CreateAsset(material, path);
            }
            material.shader = shader;
            material.SetColor("_BaseColor", baseColor);
            material.SetFloat("_Metallic", metallic);
            material.SetFloat("_Smoothness", smoothness);
            material.SetTexture("_BaseMap", baseMap);
            EditorUtility.SetDirty(material);
            return material;
        }

        private static void CreatePrefabs(Dictionary<string, Material> materials)
        {
            GameObject ballRoot = new GameObject("PF_MaterialBall");
            GameObject sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sphere.name = "GEO_MaterialBall";
            sphere.transform.SetParent(ballRoot.transform, false);
            UnityEngine.Object.DestroyImmediate(sphere.GetComponent<Collider>());
            sphere.GetComponent<MeshRenderer>().sharedMaterial = materials["dielectric"];
            PrefabUtility.SaveAsPrefabAsset(ballRoot, BallPrefabPath);
            UnityEngine.Object.DestroyImmediate(ballRoot);

            GameObject modelAsset = AssetDatabase.LoadAssetAtPath<GameObject>(ModelPath);
            if (modelAsset == null)
            {
                throw new BuildFailedException("Imported crate model is unavailable.");
            }
            GameObject crateRoot = new GameObject("PF_CC0_DisplayCrate");
            GameObject crateGeometry = UnityEngine.Object.Instantiate(modelAsset);
            crateGeometry.name = "GEO_CC0_DisplayCrate";
            crateGeometry.transform.SetParent(crateRoot.transform, false);
            AssignMaterial(crateGeometry, materials["crate"]);
            PrefabUtility.SaveAsPrefabAsset(crateRoot, CratePrefabPath);
            UnityEngine.Object.DestroyImmediate(crateRoot);
            AssetDatabase.SaveAssets();
        }

        private static Camera CreateScene(Dictionary<string, Material> materials)
        {
            Scene scene = EditorSceneManager.NewScene(
                NewSceneSetup.EmptyScene,
                NewSceneMode.Single
            );
            GameObject geometryRoot = new GameObject("GEO_TestObjects");
            GameObject environmentRoot = new GameObject("ENV_Lighting");
            GameObject cameraRoot = new GameObject("CAM_Main");

            GameObject floor = GameObject.CreatePrimitive(PrimitiveType.Plane);
            floor.name = "GEO_Floor";
            floor.transform.SetParent(geometryRoot.transform, false);
            floor.transform.localScale = new Vector3(0.85f, 1.0f, 0.45f);
            floor.GetComponent<MeshRenderer>().sharedMaterial = materials["floor"];

            GameObject ballPrefab = AssetDatabase.LoadAssetAtPath<GameObject>(BallPrefabPath);
            CreateMaterialBall(
                ballPrefab,
                geometryRoot.transform,
                "GEO_MatBall_01_Dielectric",
                new Vector3(-2.7f, 1.0f, 0.0f),
                materials["dielectric"]
            );
            CreateMaterialBall(
                ballPrefab,
                geometryRoot.transform,
                "GEO_MatBall_02_RoughMetal",
                new Vector3(-0.9f, 1.0f, 0.0f),
                materials["roughMetal"]
            );
            CreateMaterialBall(
                ballPrefab,
                geometryRoot.transform,
                "GEO_MatBall_03_SmoothMetal",
                new Vector3(0.9f, 1.0f, 0.0f),
                materials["smoothMetal"]
            );

            GameObject cratePrefab = AssetDatabase.LoadAssetAtPath<GameObject>(CratePrefabPath);
            GameObject crate = PrefabUtility.InstantiatePrefab(cratePrefab) as GameObject;
            crate.name = "GEO_FreeAsset_CC0_Crate";
            crate.transform.SetParent(geometryRoot.transform, false);
            crate.transform.localPosition = new Vector3(2.8f, 0.65f, 0.0f);
            crate.transform.localRotation = Quaternion.Euler(0.0f, -22.0f, 0.0f);
            crate.transform.localScale = Vector3.one * 1.3f;

            GameObject sunObject = new GameObject("LGT_Key_Directional");
            sunObject.transform.SetParent(environmentRoot.transform, false);
            sunObject.transform.rotation = Quaternion.Euler(38.0f, -32.0f, 0.0f);
            Light sun = sunObject.AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.color = new Color(1.0f, 0.93f, 0.82f);
            sun.intensity = 3.2f;
            sun.shadows = LightShadows.Soft;
            RenderSettings.sun = sun;
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.22f, 0.29f, 0.38f);
            RenderSettings.ambientEquatorColor = new Color(0.11f, 0.12f, 0.14f);
            RenderSettings.ambientGroundColor = new Color(0.035f, 0.03f, 0.028f);

            Camera camera = cameraRoot.AddComponent<Camera>();
            cameraRoot.transform.position = new Vector3(0.0f, 2.5f, -9.0f);
            cameraRoot.transform.LookAt(new Vector3(0.0f, 0.9f, 0.0f));
            camera.fieldOfView = 42.0f;
            camera.nearClipPlane = 0.1f;
            camera.farClipPlane = 50.0f;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.025f, 0.035f, 0.055f, 1.0f);
            camera.allowHDR = true;

            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(ScenePath, true)
            };
            AssetDatabase.SaveAssets();
            return camera;
        }

        private static void CreateMaterialBall(
            GameObject prefab,
            Transform parent,
            string name,
            Vector3 position,
            Material material
        )
        {
            if (prefab == null)
            {
                throw new BuildFailedException("Material ball prefab is unavailable.");
            }
            GameObject instance = PrefabUtility.InstantiatePrefab(prefab) as GameObject;
            instance.name = name;
            instance.transform.SetParent(parent, false);
            instance.transform.localPosition = position;
            AssignMaterial(instance, material);
        }

        private static void AssignMaterial(GameObject root, Material material)
        {
            foreach (Renderer renderer in root.GetComponentsInChildren<Renderer>(true))
            {
                renderer.sharedMaterial = material;
            }
        }

        private static void CaptureBaseline(Camera camera)
        {
            const int width = 960;
            const int height = 540;
            RenderTexture renderTexture = new RenderTexture(
                width,
                height,
                24,
                RenderTextureFormat.ARGB32
            );
            Texture2D screenshot = new Texture2D(
                width,
                height,
                TextureFormat.RGB24,
                false,
                false
            );
            RenderTexture previous = RenderTexture.active;
            try
            {
                camera.targetTexture = renderTexture;
                camera.Render();
                RenderTexture.active = renderTexture;
                screenshot.ReadPixels(new Rect(0, 0, width, height), 0, 0);
                screenshot.Apply();
                File.WriteAllBytes(
                    ToAbsoluteAssetPath(ScreenshotPath),
                    screenshot.EncodeToPNG()
                );
            }
            finally
            {
                camera.targetTexture = null;
                RenderTexture.active = previous;
                renderTexture.Release();
                UnityEngine.Object.DestroyImmediate(renderTexture);
                UnityEngine.Object.DestroyImmediate(screenshot);
            }
            AssetDatabase.ImportAsset(
                ScreenshotPath,
                ImportAssetOptions.ForceUpdate |
                ImportAssetOptions.ForceSynchronousImport
            );
        }

        private static void ValidateInternal()
        {
            ValidationReport report = new ValidationReport
            {
                editorVersion = Application.unityVersion,
                scene = ScenePath,
                generatedAtUtc = DateTime.UtcNow.ToString("O")
            };
            Check(
                Application.unityVersion == "2022.3.62f3c1",
                "Editor version matches 2022.3.62f3c1",
                report
            );
            RenderPipelineAsset pipeline =
                AssetDatabase.LoadAssetAtPath<RenderPipelineAsset>(PipelinePath);
            report.renderPipeline = pipeline == null ? "<missing>" : pipeline.name;
            Check(pipeline != null, "URP pipeline asset exists", report);
            Check(
                GraphicsSettings.renderPipelineAsset == pipeline,
                "URP pipeline is active",
                report
            );

            ModelImporter modelImporter = AssetImporter.GetAtPath(ModelPath) as ModelImporter;
            Check(modelImporter != null, "Model importer exists", report);
            if (modelImporter != null)
            {
                Check(
                    Math.Abs(modelImporter.globalScale - 1.0f) < 0.0001f,
                    "Model scale is one meter",
                    report
                );
                Check(
                    modelImporter.materialImportMode == ModelImporterMaterialImportMode.None,
                    "Source materials are disabled",
                    report
                );
                Check(modelImporter.generateSecondaryUV, "Lightmap UV generation is enabled", report);
            }

            Mesh[] meshes = AssetDatabase.LoadAllAssetsAtPath(ModelPath)
                .OfType<Mesh>()
                .ToArray();
            report.importedMeshCount = meshes.Length;
            report.importedVertexCount = meshes.Sum(mesh => mesh.vertexCount);
            Check(meshes.Length > 0, "Imported model contains a mesh", report);
            foreach (Mesh mesh in meshes)
            {
                Check(
                    mesh.normals != null && mesh.normals.Length == mesh.vertexCount,
                    "Imported mesh contains normals",
                    report
                );
                Check(
                    mesh.uv != null && mesh.uv.Length == mesh.vertexCount,
                    "Imported mesh contains primary UVs",
                    report
                );
                Check(
                    mesh.uv2 != null && mesh.uv2.Length == mesh.vertexCount,
                    "Imported mesh contains generated lightmap UVs",
                    report
                );
            }

            TextureImporter textureImporter =
                AssetImporter.GetAtPath(TexturePath) as TextureImporter;
            Check(textureImporter != null, "Texture importer exists", report);
            if (textureImporter != null)
            {
                Check(textureImporter.sRGBTexture, "Base color texture uses sRGB", report);
                Check(textureImporter.mipmapEnabled, "Base color mipmaps are enabled", report);
                Check(
                    textureImporter.textureCompression == TextureImporterCompression.Uncompressed,
                    "Baseline texture compression is disabled",
                    report
                );
            }

            string[] requiredAssets =
            {
                BallPrefabPath,
                CratePrefabPath,
                DielectricMaterialPath,
                RoughMetalMaterialPath,
                SmoothMetalMaterialPath,
                CrateMaterialPath,
                FloorMaterialPath,
                ScenePath,
                ScreenshotPath
            };
            foreach (string assetPath in requiredAssets)
            {
                Check(
                    AssetDatabase.LoadMainAssetAtPath(assetPath) != null,
                    "Required asset exists: " + assetPath,
                    report
                );
            }

            Scene scene = EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);
            Check(scene.IsValid() && scene.isLoaded, "Material test scene opens", report);
            string[] requiredObjects =
            {
                "GEO_TestObjects",
                "ENV_Lighting",
                "CAM_Main",
                "GEO_MatBall_01_Dielectric",
                "GEO_MatBall_02_RoughMetal",
                "GEO_MatBall_03_SmoothMetal",
                "GEO_FreeAsset_CC0_Crate"
            };
            foreach (string objectName in requiredObjects)
            {
                Check(GameObject.Find(objectName) != null, "Scene object exists: " + objectName, report);
            }
            Check(
                EditorBuildSettings.scenes.Any(item => item.enabled && item.path == ScenePath),
                "Material test scene is enabled in Build Settings",
                report
            );

            Texture2D screenshot = AssetDatabase.LoadAssetAtPath<Texture2D>(ScreenshotPath);
            if (screenshot != null)
            {
                report.screenshotWidth = screenshot.width;
                report.screenshotHeight = screenshot.height;
            }
            Check(
                screenshot != null && screenshot.width == 960 && screenshot.height == 540,
                "Baseline screenshot is 960x540",
                report
            );

            report.status = report.errors.Count == 0 ? "PASS" : "FAIL";
            File.WriteAllText(
                ToAbsoluteAssetPath(ReportPath),
                JsonUtility.ToJson(report, true)
            );
            AssetDatabase.ImportAsset(
                ReportPath,
                ImportAssetOptions.ForceUpdate |
                ImportAssetOptions.ForceSynchronousImport
            );
            AssetDatabase.SaveAssets();
            if (report.errors.Count > 0)
            {
                throw new BuildFailedException(
                    "Unity asset import validation failed:\n" +
                    string.Join("\n", report.errors)
                );
            }
            Debug.Log("UNITY_ASSET_IMPORT_ACCEPTANCE: PASS");
        }

        private static void Check(
            bool condition,
            string description,
            ValidationReport report
        )
        {
            if (condition)
            {
                report.checks.Add(description);
            }
            else
            {
                report.errors.Add(description);
            }
        }

        private static string ToAbsoluteAssetPath(string assetPath)
        {
            return Path.Combine(
                Directory.GetParent(Application.dataPath).FullName,
                assetPath.Replace('/', Path.DirectorySeparatorChar)
            );
        }

        private static Type FindType(string fullName)
        {
            foreach (System.Reflection.Assembly assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                Type type = assembly.GetType(fullName, false);
                if (type != null)
                {
                    return type;
                }
            }
            throw new BuildFailedException("Required Unity type is unavailable: " + fullName);
        }
    }
}
#endif
