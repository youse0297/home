#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEngine;

namespace TA.MaterialLab.Editor
{
    public static class ShaderGraphCustomFunctionBootstrap
    {
        private const string Root = "Assets/_TA";
        private const string HlslPath = Root + "/ShaderGraph/TA_CustomFunctions.hlsl";
        private const string OutputPath = Root + "/ShaderGraph/SG_CustomFunctionExample.shadersubgraph";

        [MenuItem("TA/Material Lab/Create Custom Function Example")]
        public static void CreateExample()
        {
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            if (!File.Exists(ToAbsolutePath(HlslPath)))
                throw new FileNotFoundException("Custom Function HLSL source is missing", HlslPath);

            Type graphDataType = FindType("UnityEditor.ShaderGraph.GraphData");
            Type outputNodeType = FindType("UnityEditor.ShaderGraph.SubGraphOutputNode");
            Type customNodeType = FindType("UnityEditor.ShaderGraph.CustomFunctionNode");
            Type slotType = FindType("UnityEditor.ShaderGraph.MaterialSlot");
            Type slotDirectionType = FindType("UnityEditor.Graphing.SlotType");
            Type shaderStageType = FindType("UnityEditor.ShaderGraph.ShaderStageCapability");
            Type vector1Type = FindType("UnityEditor.ShaderGraph.Vector1MaterialSlot");
            Type vector2Type = FindType("UnityEditor.ShaderGraph.Vector2MaterialSlot");
            Type vector3Type = FindType("UnityEditor.ShaderGraph.Vector3MaterialSlot");
            Type vector4Type = FindType("UnityEditor.ShaderGraph.Vector4MaterialSlot");
            Type texture2DType = FindType("UnityEditor.ShaderGraph.Texture2DInputMaterialSlot");
            Type hlslSourceType = FindType("UnityEditor.ShaderGraph.Drawing.HlslSourceType");
            Type concreteSlotType = FindType("UnityEditor.ShaderGraph.ConcreteSlotValueType");
            Type fileUtilitiesType = FindType("UnityEditor.ShaderGraph.FileUtilities");

            object graph = Activator.CreateInstance(graphDataType);
            graphDataType.GetProperty("isSubGraph").SetValue(graph, true);
            graphDataType.GetProperty("path").SetValue(graph, "_TA/ShaderGraph");

            object outputNode = Activator.CreateInstance(outputNodeType);
            graphDataType.GetMethod("AddNode").Invoke(graph, new[] { outputNode });
            graphDataType.GetProperty("outputNode").SetValue(graph, outputNode);
            MethodInfo addOutput = outputNodeType.GetMethod("AddSlot", new[] { concreteSlotType });
            foreach (string outputType in new[] { "Vector4", "Vector3", "Vector3", "Vector3" })
                addOutput.Invoke(outputNode, new[] { Enum.Parse(concreteSlotType, outputType) });

            object customNode = Activator.CreateInstance(customNodeType);
            customNodeType.GetProperty("sourceType").SetValue(customNode, Enum.Parse(hlslSourceType, "File"));
            customNodeType.GetProperty("functionName").SetValue(customNode, "TA_SampleMaterialInputs");
            customNodeType.GetProperty("functionSource").SetValue(customNode, AssetDatabase.AssetPathToGUID(HlslPath));
            graphDataType.GetMethod("AddNode").Invoke(graph, new[] { customNode });

            MethodInfo addSlot = customNodeType.GetMethod("AddSlot", new[] { slotType, typeof(bool) });
            object allStages = Enum.Parse(shaderStageType, "All");
            object input = Enum.Parse(slotDirectionType, "Input");
            object output = Enum.Parse(slotDirectionType, "Output");
            AddTextureSlot(customNode, addSlot, texture2DType, 1, "BaseColorTex", allStages);
            AddTextureSlot(customNode, addSlot, texture2DType, 2, "NormalTex", allStages);
            AddTextureSlot(customNode, addSlot, texture2DType, 3, "OrmTex", allStages);
            AddVector2Slot(customNode, addSlot, vector2Type, 4, "UV", input, allStages, new Vector2(0.5f, 0.5f));
            AddVector1Slot(customNode, addSlot, vector1Type, 5, "Metallic", input, allStages, 0.0f);
            AddVector1Slot(customNode, addSlot, vector1Type, 6, "Roughness", input, allStages, 0.5f);
            AddVector1Slot(customNode, addSlot, vector1Type, 7, "NormalScale", input, allStages, 1.0f);
            AddVector4Slot(customNode, addSlot, vector4Type, 8, "BaseColor", output, allStages);
            AddVector3Slot(customNode, addSlot, vector3Type, 9, "NormalTS", output, allStages);
            AddVector3Slot(customNode, addSlot, vector3Type, 10, "ORM", output, allStages);
            AddVector3Slot(customNode, addSlot, vector3Type, 11, "Parameters", output, allStages);

            MethodInfo getSlotReference = customNodeType.GetMethod("GetSlotReference");
            MethodInfo connect = graphDataType.GetMethod("Connect");
            for (int index = 0; index < 4; index++)
            {
                object sourceSlot = getSlotReference.Invoke(customNode, new object[] { 8 + index });
                object destinationSlot = getSlotReference.Invoke(outputNode, new object[] { 1 + index });
                connect.Invoke(graph, new[] { sourceSlot, destinationSlot });
            }

            MethodInfo write = fileUtilitiesType.GetMethod("WriteShaderGraphToDisk", BindingFlags.Public | BindingFlags.Static);
            if (write == null || write.Invoke(null, new[] { ToAbsolutePath(OutputPath), graph }) == null)
                throw new InvalidOperationException("Shader Graph serialization failed");

            AssetDatabase.ImportAsset(OutputPath, ImportAssetOptions.ForceSynchronousImport);
            Debug.Log("TA_SHADER_GRAPH_CUSTOM_FUNCTION: PASS " + OutputPath);
        }

        private static void AddTextureSlot(object customNode, MethodInfo addSlot, Type slotClass, int id, string name, object stages)
        {
            object slot = Activator.CreateInstance(slotClass, id, name, name, stages, false);
            addSlot.Invoke(customNode, new[] { slot, (object)true });
        }

        private static void AddVector1Slot(object customNode, MethodInfo addSlot, Type slotClass, int id, string name, object direction, object stages, float value)
        {
            object slot = Activator.CreateInstance(slotClass, id, name, name, direction, value, stages, null, false);
            addSlot.Invoke(customNode, new[] { slot, (object)true });
        }

        private static void AddVector2Slot(object customNode, MethodInfo addSlot, Type slotClass, int id, string name, object direction, object stages, Vector2 value)
        {
            object slot = Activator.CreateInstance(slotClass, id, name, name, direction, value, stages, null, null, false, false);
            addSlot.Invoke(customNode, new[] { slot, (object)true });
        }

        private static void AddVector3Slot(object customNode, MethodInfo addSlot, Type slotClass, int id, string name, object direction, object stages)
        {
            object slot = Activator.CreateInstance(slotClass, id, name, name, direction, Vector3.zero, stages, null, null, null, false);
            addSlot.Invoke(customNode, new[] { slot, (object)true });
        }

        private static void AddVector4Slot(object customNode, MethodInfo addSlot, Type slotClass, int id, string name, object direction, object stages)
        {
            object slot = Activator.CreateInstance(slotClass, id, name, name, direction, Vector4.zero, stages, null, null, null, null, false);
            addSlot.Invoke(customNode, new[] { slot, (object)true });
        }

        private static Type FindType(string fullName)
        {
            Type type = AppDomain.CurrentDomain.GetAssemblies()
                .Select(assembly => assembly.GetType(fullName, false))
                .FirstOrDefault(candidate => candidate != null);
            if (type == null)
                throw new InvalidOperationException("Shader Graph type not loaded: " + fullName);
            return type;
        }

        private static string ToAbsolutePath(string assetPath)
        {
            string projectRoot = Directory.GetParent(Application.dataPath).FullName;
            return Path.Combine(projectRoot, assetPath.Replace('/', Path.DirectorySeparatorChar));
        }
    }
}
#endif
