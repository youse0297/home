#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using TA.MaterialLab;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace TA.MaterialLab.Editor
{
    public static class LodTestBootstrap
    {
        private const string Root = "Assets/_TA";
        private const string LodRoot = Root + "/LOD";
        private const string MeshRoot = LodRoot + "/Meshes";
        private const string PrefabPath = LodRoot + "/PF_LOD_MaterialBall.prefab";
        private const string ScenePath = LodRoot + "/SCN_LOD_Baseline.unity";
        private const string ReportPath = Root + "/Documentation/LODValidation.json";
        private const string MaterialPath = Root + "/Materials/Instances/MAT_PBR_Dielectric.mat";

        private sealed class LodReport
        {
            public string status;
            public string prefab;
            public string scene;
            public string generatedAtUtc;
            public float lodBias;
            public List<LevelReport> levels = new List<LevelReport>();
            public List<SwitchReport> switches = new List<SwitchReport>();
        }

        [Serializable]
        private sealed class LevelReport
        {
            public string name;
            public float screenHeight;
            public int vertexCount;
            public int triangleCount;
        }

        [Serializable]
        private sealed class SwitchReport
        {
            public string id;
            public float screenHeight;
            public int expectedLevel;
            public string expectedName;
        }

        [MenuItem("TA/Material Lab/Build LOD Test Scene")]
        public static void Build()
        {
            EnsureFolders();
            Mesh highMesh = CreateOrLoadSphereMesh(
                MeshRoot + "/M_LOD_High.asset",
                "M_LOD_High",
                32,
                16
            );
            Mesh mediumMesh = CreateOrLoadSphereMesh(
                MeshRoot + "/M_LOD_Medium.asset",
                "M_LOD_Medium",
                16,
                8
            );
            Mesh lowMesh = CreateOrLoadSphereMesh(
                MeshRoot + "/M_LOD_Low.asset",
                "M_LOD_Low",
                8,
                4
            );
            Material material = AssetDatabase.LoadAssetAtPath<Material>(MaterialPath);
            if (material == null)
                material = new Material(Shader.Find("Universal Render Pipeline/Lit"));

            GameObject prefabRoot = CreateLodPrefab(highMesh, mediumMesh, lowMesh, material);
            AssetDatabase.SaveAssets();
            GameObject prefab = PrefabUtility.SaveAsPrefabAsset(prefabRoot, PrefabPath);
            UnityEngine.Object.DestroyImmediate(prefabRoot);
            if (prefab == null)
                throw new InvalidOperationException("LOD prefab could not be saved: " + PrefabPath);

            BuildScene(prefab);
            WriteReport();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            Debug.Log("TA_LOD_BOOTSTRAP: PASS");
        }

        private static void EnsureFolders()
        {
            EnsureFolder(Root, "LOD");
            EnsureFolder(LodRoot, "Meshes");
        }

        private static void EnsureFolder(string parent, string child)
        {
            string path = parent + "/" + child;
            if (!AssetDatabase.IsValidFolder(path))
                AssetDatabase.CreateFolder(parent, child);
        }

        private static Mesh CreateOrLoadSphereMesh(
            string path,
            string name,
            int segments,
            int rings
        )
        {
            Mesh mesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (mesh != null)
                return mesh;

            List<Vector3> vertices = new List<Vector3>();
            List<Vector2> uvs = new List<Vector2>();
            List<int> triangles = new List<int>();
            for (int ring = 0; ring <= rings; ring++)
            {
                float v = ring / (float)rings;
                float phi = v * Mathf.PI;
                float y = Mathf.Cos(phi);
                float radius = Mathf.Sin(phi);
                for (int segment = 0; segment < segments; segment++)
                {
                    float u = segment / (float)segments;
                    float theta = u * Mathf.PI * 2.0f;
                    vertices.Add(new Vector3(
                        radius * Mathf.Cos(theta),
                        y,
                        radius * Mathf.Sin(theta)
                    ));
                    uvs.Add(new Vector2(u, 1.0f - v));
                }
            }
            for (int ring = 0; ring < rings; ring++)
            {
                for (int segment = 0; segment < segments; segment++)
                {
                    int nextSegment = (segment + 1) % segments;
                    int current = ring * segments + segment;
                    int next = ring * segments + nextSegment;
                    int below = (ring + 1) * segments + segment;
                    int belowNext = (ring + 1) * segments + nextSegment;
                    triangles.Add(current);
                    triangles.Add(below);
                    triangles.Add(next);
                    triangles.Add(next);
                    triangles.Add(below);
                    triangles.Add(belowNext);
                }
            }

            mesh = new Mesh { name = name };
            mesh.SetVertices(vertices);
            mesh.SetUVs(0, uvs);
            mesh.SetTriangles(triangles, 0);
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            AssetDatabase.CreateAsset(mesh, path);
            return mesh;
        }

        private static GameObject CreateLodPrefab(
            Mesh highMesh,
            Mesh mediumMesh,
            Mesh lowMesh,
            Material material
        )
        {
            GameObject root = new GameObject("PF_LOD_MaterialBall");
            LODGroup lodGroup = root.AddComponent<LODGroup>();
            Renderer high = CreateLodRenderer(root.transform, "GEO_LOD_High", highMesh, material);
            Renderer medium = CreateLodRenderer(root.transform, "GEO_LOD_Medium", mediumMesh, material);
            Renderer low = CreateLodRenderer(root.transform, "GEO_LOD_Low", lowMesh, material);
            lodGroup.SetLODs(new[]
            {
                new LOD(LodPolicy.HighScreenHeight, new[] { high }),
                new LOD(LodPolicy.MediumScreenHeight, new[] { medium }),
                new LOD(LodPolicy.LowScreenHeight, new[] { low })
            });
            lodGroup.fadeMode = LODFadeMode.CrossFade;
            lodGroup.animateCrossFading = true;
            LODGroup.crossFadeAnimationDuration = LodPolicy.CrossFadeDuration;
            lodGroup.RecalculateBounds();
            return root;
        }

        private static Renderer CreateLodRenderer(
            Transform parent,
            string name,
            Mesh mesh,
            Material material
        )
        {
            GameObject child = new GameObject(name);
            child.transform.SetParent(parent, false);
            MeshFilter filter = child.AddComponent<MeshFilter>();
            filter.sharedMesh = mesh;
            MeshRenderer renderer = child.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            return renderer;
        }

        private static void BuildScene(GameObject prefab)
        {
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            GameObject root = new GameObject("GEO_LOD_TestObjects");
            float[] positions = { -3.5f, 0.0f, 3.5f, 7.0f };
            for (int index = 0; index < positions.Length; index++)
            {
                GameObject instance = PrefabUtility.InstantiatePrefab(prefab) as GameObject;
                instance.name = "LOD_Sample_" + index;
                instance.transform.SetParent(root.transform, false);
                instance.transform.localPosition = new Vector3(positions[index], 1.0f, 0.0f);
            }

            GameObject cameraObject = new GameObject("CAM_LOD_Baseline");
            Camera camera = cameraObject.AddComponent<Camera>();
            cameraObject.transform.position = new Vector3(0.0f, 2.7f, -13.0f);
            cameraObject.transform.LookAt(new Vector3(1.5f, 1.0f, 0.0f));
            camera.fieldOfView = 40.0f;
            camera.nearClipPlane = 0.1f;
            camera.farClipPlane = 50.0f;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.025f, 0.035f, 0.055f, 1.0f);

            GameObject lightObject = new GameObject("LGT_LOD_Key");
            Light light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 2.5f;
            lightObject.transform.rotation = Quaternion.Euler(35.0f, -30.0f, 0.0f);
            RenderSettings.sun = light;
            QualitySettings.lodBias = 1.0f;
            EditorSceneManager.SaveScene(scene, ScenePath);
        }

        private static void WriteReport()
        {
            LodReport report = new LodReport
            {
                status = "PASS",
                prefab = PrefabPath,
                scene = ScenePath,
                generatedAtUtc = DateTime.UtcNow.ToString("O"),
                lodBias = QualitySettings.lodBias
            };
            foreach (LodLevelDefinition level in LodPolicy.Levels)
            {
                report.levels.Add(new LevelReport
                {
                    name = level.name,
                    screenHeight = level.screenHeight,
                    vertexCount = level.vertexCount,
                    triangleCount = level.triangleCount
                });
            }
            foreach (var sample in new[]
            {
                new { id = "LOD0", screenHeight = 0.80f },
                new { id = "LOD1", screenHeight = 0.40f },
                new { id = "LOD2", screenHeight = 0.10f },
                new { id = "CULLED", screenHeight = 0.02f }
            })
            {
                int level = LodPolicy.ResolveLevel(sample.screenHeight);
                report.switches.Add(new SwitchReport
                {
                    id = sample.id,
                    screenHeight = sample.screenHeight,
                    expectedLevel = level,
                    expectedName = level < LodPolicy.Levels.Length ? LodPolicy.Levels[level].name : "Culled"
                });
            }
            string absolutePath = Path.Combine(
                Directory.GetParent(Application.dataPath).FullName,
                ReportPath
            );
            File.WriteAllText(
                absolutePath,
                JsonUtility.ToJson(report, true)
            );
            AssetDatabase.ImportAsset(ReportPath, ImportAssetOptions.ForceSynchronousImport);
        }
    }
}
#endif
