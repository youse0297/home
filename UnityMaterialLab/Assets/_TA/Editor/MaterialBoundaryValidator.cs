#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using TA.MaterialLab;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace TA.MaterialLab.Editor
{
    public static class MaterialBoundaryValidator
    {
        private const string Root = "Assets/_TA";
        private const string MaterialsPath = Root + "/Materials/Boundary";
        private const string ScenePath = Root + "/Scenes/SCN_MaterialBoundaryBoard.unity";
        private const string ScreenshotPath = Root + "/Documentation/MaterialBoundaryBoard.png";
        private const string ReportPath = Root + "/Documentation/MaterialBoundaryValidation.json";
        private const string BaseColorPath = Root + "/Art/Textures/T_CC0_Crate_BaseColor.png";
        private const string NormalPath = Root + "/Art/Textures/T_PBR_Normal.png";
        private const string OrmPath = Root + "/Art/Textures/T_PBR_ORM.png";

        [Serializable]
        private sealed class CaseRecord
        {
            public string id;
            public string parameter;
            public float value;
            public float metallic;
            public float roughness;
            public float normalScale;
            public float smoothness;
            public float ggxAlpha;
            public float dielectricWeight;
            public bool physicallyValid;
            public string conclusion;
        }

        [Serializable]
        private sealed class BoundaryReport
        {
            public string status;
            public string editorVersion;
            public string scene;
            public int caseCount;
            public int metallicCaseCount;
            public int roughnessCaseCount;
            public int normalCaseCount;
            public int screenshotWidth;
            public int screenshotHeight;
            public string generatedAtUtc;
            public List<CaseRecord> cases = new List<CaseRecord>();
            public List<string> checks = new List<string>();
            public List<string> errors = new List<string>();
        }

        [MenuItem("TA/Material Lab/Build Material Boundary Board")]
        public static void Build()
        {
            try
            {
                ProjectBootstrap.Build();
                EnsureFolder(MaterialsPath);
                IReadOnlyList<MaterialBoundaryMatrix.Case> cases =
                    MaterialBoundaryMatrix.CreateCases();
                Dictionary<string, Material> materials = CreateMaterials(cases);
                Camera camera = CreateScene(cases, materials);
                CaptureBoard(camera);
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
                ValidateInternal();
                Debug.Log("UNITY_MATERIAL_BOUNDARY_BUILD: PASS");
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                throw;
            }
        }

        [MenuItem("TA/Material Lab/Validate Material Boundaries")]
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

        private static Dictionary<string, Material> CreateMaterials(
            IEnumerable<MaterialBoundaryMatrix.Case> cases
        )
        {
            Shader shader = Shader.Find("Universal Render Pipeline/Lit");
            if (shader == null || !shader.isSupported)
            {
                throw new BuildFailedException("URP Lit shader is unavailable.");
            }
            Texture2D baseColor = AssetDatabase.LoadAssetAtPath<Texture2D>(BaseColorPath);
            Texture2D normal = AssetDatabase.LoadAssetAtPath<Texture2D>(NormalPath);
            Texture2D orm = AssetDatabase.LoadAssetAtPath<Texture2D>(OrmPath);
            if (baseColor == null || normal == null || orm == null)
            {
                throw new BuildFailedException("Material boundary inputs are unavailable.");
            }

            Dictionary<string, Material> materials = new Dictionary<string, Material>();
            foreach (MaterialBoundaryMatrix.Case item in cases)
            {
                string path = MaterialsPath + "/MAT_Boundary_" + item.id + ".mat";
                Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
                if (material == null)
                {
                    material = new Material(shader);
                    material.name = Path.GetFileNameWithoutExtension(path);
                    AssetDatabase.CreateAsset(material, path);
                }
                material.shader = shader;
                material.SetTexture("_BaseMap", baseColor);
                material.SetTexture("_BumpMap", normal);
                material.SetTexture("_OcclusionMap", orm);
                material.SetColor("_BaseColor", Color.white);
                material.SetFloat("_Metallic", item.metallic);
                material.SetFloat("_Smoothness", item.smoothness);
                material.SetFloat("_BumpScale", item.normalScale);
                material.SetFloat("_OcclusionStrength", 1.0f);
                material.EnableKeyword("_NORMALMAP");
                material.EnableKeyword("_OCCLUSIONMAP");
                EditorUtility.SetDirty(material);
                materials.Add(item.id, material);
            }
            return materials;
        }

        private static Camera CreateScene(
            IReadOnlyList<MaterialBoundaryMatrix.Case> cases,
            IReadOnlyDictionary<string, Material> materials
        )
        {
            Scene scene = EditorSceneManager.NewScene(
                NewSceneSetup.EmptyScene,
                NewSceneMode.Single
            );
            GameObject board = new GameObject("GEO_MaterialBoundaryBoard");
            CreateRow(
                board.transform,
                cases.Where(item => item.parameter == MaterialBoundaryMatrix.Parameter.Metallic),
                materials,
                "ROW_Metallic",
                2.2f
            );
            CreateRow(
                board.transform,
                cases.Where(item => item.parameter == MaterialBoundaryMatrix.Parameter.Roughness),
                materials,
                "ROW_Roughness",
                0.0f
            );
            CreateRow(
                board.transform,
                cases.Where(item => item.parameter == MaterialBoundaryMatrix.Parameter.NormalScale),
                materials,
                "ROW_NormalScale",
                -2.2f
            );

            GameObject environment = new GameObject("ENV_BoundaryLighting");
            CreateDirectionalLight(environment.transform);
            CreateFillLight(environment.transform);
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.24f, 0.29f, 0.37f);
            RenderSettings.ambientEquatorColor = new Color(0.09f, 0.10f, 0.12f);
            RenderSettings.ambientGroundColor = new Color(0.025f, 0.022f, 0.02f);

            GameObject cameraObject = new GameObject("CAM_MaterialBoundaryBoard");
            Camera camera = cameraObject.AddComponent<Camera>();
            cameraObject.transform.position = new Vector3(0.0f, 0.2f, -14.0f);
            cameraObject.transform.LookAt(Vector3.zero);
            camera.fieldOfView = 40.0f;
            camera.nearClipPlane = 0.1f;
            camera.farClipPlane = 50.0f;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.018f, 0.024f, 0.038f, 1.0f);
            camera.allowHDR = true;

            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = EditorBuildSettings.scenes
                .Where(item => item.path != ScenePath)
                .Concat(new[] { new EditorBuildSettingsScene(ScenePath, true) })
                .ToArray();
            return camera;
        }

        private static void CreateRow(
            Transform parent,
            IEnumerable<MaterialBoundaryMatrix.Case> cases,
            IReadOnlyDictionary<string, Material> materials,
            string rowName,
            float y
        )
        {
            MaterialBoundaryMatrix.Case[] rowCases = cases.ToArray();
            GameObject row = new GameObject(rowName);
            row.transform.SetParent(parent, false);
            float spacing = 1.75f;
            float start = -spacing * (rowCases.Length - 1) * 0.5f;
            for (int index = 0; index < rowCases.Length; ++index)
            {
                MaterialBoundaryMatrix.Case item = rowCases[index];
                GameObject sphere = GameObject.CreatePrimitive(PrimitiveType.Sphere);
                sphere.name = "GEO_Boundary_" + item.id;
                sphere.transform.SetParent(row.transform, false);
                sphere.transform.localPosition = new Vector3(start + spacing * index, y, 0.0f);
                sphere.transform.localScale = Vector3.one * 1.25f;
                UnityEngine.Object.DestroyImmediate(sphere.GetComponent<Collider>());
                sphere.GetComponent<MeshRenderer>().sharedMaterial = materials[item.id];
            }
        }

        private static void CreateDirectionalLight(Transform parent)
        {
            GameObject lightObject = new GameObject("LGT_Key_Directional");
            lightObject.transform.SetParent(parent, false);
            lightObject.transform.rotation = Quaternion.Euler(42.0f, -34.0f, 0.0f);
            Light light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(1.0f, 0.92f, 0.80f);
            light.intensity = 3.0f;
            light.shadows = LightShadows.Soft;
            RenderSettings.sun = light;
        }

        private static void CreateFillLight(Transform parent)
        {
            GameObject lightObject = new GameObject("LGT_Fill_Point");
            lightObject.transform.SetParent(parent, false);
            lightObject.transform.position = new Vector3(-4.0f, 1.5f, -4.0f);
            Light light = lightObject.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = new Color(0.32f, 0.46f, 0.72f);
            light.intensity = 7.0f;
            light.range = 18.0f;
            light.shadows = LightShadows.None;
        }

        private static void CaptureBoard(Camera camera)
        {
            const int width = 1200;
            const int height = 720;
            RenderTexture target = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32);
            Texture2D screenshot = new Texture2D(width, height, TextureFormat.RGB24, false, false);
            RenderTexture previous = RenderTexture.active;
            try
            {
                camera.targetTexture = target;
                camera.Render();
                RenderTexture.active = target;
                screenshot.ReadPixels(new Rect(0, 0, width, height), 0, 0);
                screenshot.Apply();
                File.WriteAllBytes(ToAbsoluteAssetPath(ScreenshotPath), screenshot.EncodeToPNG());
            }
            finally
            {
                camera.targetTexture = null;
                RenderTexture.active = previous;
                target.Release();
                UnityEngine.Object.DestroyImmediate(target);
                UnityEngine.Object.DestroyImmediate(screenshot);
            }
            AssetDatabase.ImportAsset(ScreenshotPath, ImportAssetOptions.ForceSynchronousImport);
            TextureImporter importer = AssetImporter.GetAtPath(ScreenshotPath) as TextureImporter;
            if (importer == null)
            {
                throw new BuildFailedException("Boundary screenshot importer is unavailable.");
            }
            importer.sRGBTexture = true;
            importer.mipmapEnabled = false;
            importer.npotScale = TextureImporterNPOTScale.None;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.SaveAndReimport();
        }

        private static void ValidateInternal()
        {
            IReadOnlyList<MaterialBoundaryMatrix.Case> cases =
                MaterialBoundaryMatrix.CreateCases();
            BoundaryReport report = new BoundaryReport
            {
                editorVersion = Application.unityVersion,
                scene = ScenePath,
                caseCount = cases.Count,
                metallicCaseCount = cases.Count(item =>
                    item.parameter == MaterialBoundaryMatrix.Parameter.Metallic),
                roughnessCaseCount = cases.Count(item =>
                    item.parameter == MaterialBoundaryMatrix.Parameter.Roughness),
                normalCaseCount = cases.Count(item =>
                    item.parameter == MaterialBoundaryMatrix.Parameter.NormalScale),
                generatedAtUtc = DateTime.UtcNow.ToString("O")
            };
            Check(report.caseCount == 11, "Boundary matrix contains 11 cases", report);
            Check(report.metallicCaseCount == 3, "Metallic row contains 3 cases", report);
            Check(report.roughnessCaseCount == 5, "Roughness row contains 5 cases", report);
            Check(report.normalCaseCount == 3, "Normal scale row contains 3 cases", report);
            MaterialInputProfile probe = ScriptableObject.CreateInstance<MaterialInputProfile>();
            try
            {
                probe.metallic = -0.25f;
                probe.roughness = 1.25f;
                probe.normalScale = 3.0f;
                probe.occlusionStrength = float.NaN;
                probe.alpha = float.PositiveInfinity;
                probe.ClampToValidRanges();
                Check(
                    probe.HasValidParameters() &&
                    Math.Abs(probe.metallic - 0.0f) < 0.00001f &&
                    Math.Abs(probe.roughness - 1.0f) < 0.00001f &&
                    Math.Abs(probe.normalScale - 2.0f) < 0.00001f &&
                    Math.Abs(probe.occlusionStrength - 1.0f) < 0.00001f &&
                    Math.Abs(probe.alpha - 1.0f) < 0.00001f,
                    "Out-of-range and non-finite profile values are sanitized",
                    report
                );
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(probe);
            }

            foreach (MaterialBoundaryMatrix.Case item in cases)
            {
                bool physicallyValid = MaterialBoundaryMatrix.IsPhysicallyValid(item);
                Check(physicallyValid, "Physical ranges are valid: " + item.id, report);
                Check(
                    Math.Abs(item.smoothness - (1.0f - item.roughness)) < 0.00001f,
                    "Smoothness conversion is valid: " + item.id,
                    report
                );
                Check(
                    Math.Abs(item.ggxAlpha - MaterialBoundaryMatrix.ToGgxAlpha(item.roughness)) <
                    0.00001f,
                    "GGX alpha conversion is valid: " + item.id,
                    report
                );
                string materialPath = MaterialsPath + "/MAT_Boundary_" + item.id + ".mat";
                Material material = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
                Check(material != null, "Boundary material exists: " + item.id, report);
                if (material != null)
                {
                    Check(
                        Math.Abs(material.GetFloat("_Metallic") - item.metallic) < 0.00001f,
                        "Metallic value matches: " + item.id,
                        report
                    );
                    Check(
                        Math.Abs(material.GetFloat("_Smoothness") - item.smoothness) < 0.00001f,
                        "Smoothness value matches: " + item.id,
                        report
                    );
                    Check(
                        Math.Abs(material.GetFloat("_BumpScale") - item.normalScale) < 0.00001f,
                        "Normal scale matches: " + item.id,
                        report
                    );
                }
                report.cases.Add(new CaseRecord
                {
                    id = item.id,
                    parameter = item.parameter.ToString(),
                    value = item.value,
                    metallic = item.metallic,
                    roughness = item.roughness,
                    normalScale = item.normalScale,
                    smoothness = item.smoothness,
                    ggxAlpha = item.ggxAlpha,
                    dielectricWeight = item.dielectricWeight,
                    physicallyValid = physicallyValid,
                    conclusion = item.conclusion
                });
            }

            Scene scene = EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);
            Check(scene.IsValid() && scene.isLoaded, "Boundary comparison scene opens", report);
            Check(GameObject.Find("ROW_Metallic") != null, "Metallic row exists", report);
            Check(GameObject.Find("ROW_Roughness") != null, "Roughness row exists", report);
            Check(GameObject.Find("ROW_NormalScale") != null, "Normal scale row exists", report);
            Check(
                cases.All(item => GameObject.Find("GEO_Boundary_" + item.id) != null),
                "All boundary spheres exist",
                report
            );

            Texture2D screenshot = AssetDatabase.LoadAssetAtPath<Texture2D>(ScreenshotPath);
            if (screenshot != null)
            {
                report.screenshotWidth = screenshot.width;
                report.screenshotHeight = screenshot.height;
            }
            Check(
                screenshot != null && screenshot.width == 1200 && screenshot.height == 720,
                "Boundary board screenshot is 1200x720",
                report
            );
            report.status = report.errors.Count == 0 ? "PASS" : "FAIL";
            File.WriteAllText(ToAbsoluteAssetPath(ReportPath), JsonUtility.ToJson(report, true));
            AssetDatabase.ImportAsset(ReportPath, ImportAssetOptions.ForceSynchronousImport);
            AssetDatabase.SaveAssets();
            if (report.errors.Count > 0)
            {
                throw new BuildFailedException(
                    "Material boundary validation failed:\n" + string.Join("\n", report.errors)
                );
            }
            Debug.Log("UNITY_MATERIAL_BOUNDARY_ACCEPTANCE: PASS");
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

        private static void Check(
            bool condition,
            string description,
            BoundaryReport report
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
    }
}
#endif
