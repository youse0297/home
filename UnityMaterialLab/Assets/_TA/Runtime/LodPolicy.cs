using System;
using UnityEngine;

namespace TA.MaterialLab
{
    [Serializable]
    public struct LodLevelDefinition
    {
        public string name;
        public float screenHeight;
        public int vertexCount;
        public int triangleCount;

        public LodLevelDefinition(string name, float screenHeight, int vertexCount, int triangleCount)
        {
            this.name = name;
            this.screenHeight = screenHeight;
            this.vertexCount = vertexCount;
            this.triangleCount = triangleCount;
        }
    }

    public static class LodPolicy
    {
        public const float HighScreenHeight = 0.60f;
        public const float MediumScreenHeight = 0.25f;
        public const float LowScreenHeight = 0.05f;
        public const float CulledScreenHeight = 0.00f;
        public const float CrossFadeDuration = 0.15f;

        public static readonly LodLevelDefinition[] Levels =
        {
            new LodLevelDefinition("High", HighScreenHeight, 544, 1024),
            new LodLevelDefinition("Medium", MediumScreenHeight, 144, 256),
            new LodLevelDefinition("Low", LowScreenHeight, 40, 64)
        };

        public static int ResolveLevel(float screenHeight)
        {
            if (float.IsNaN(screenHeight) || float.IsInfinity(screenHeight) || screenHeight < CulledScreenHeight)
                return 3;
            if (screenHeight >= HighScreenHeight)
                return 0;
            if (screenHeight >= MediumScreenHeight)
                return 1;
            if (screenHeight >= LowScreenHeight)
                return 2;
            return 3;
        }

        public static bool HasMonotonicThresholds()
        {
            return HighScreenHeight > MediumScreenHeight &&
                MediumScreenHeight > LowScreenHeight &&
                LowScreenHeight > CulledScreenHeight;
        }
    }
}
