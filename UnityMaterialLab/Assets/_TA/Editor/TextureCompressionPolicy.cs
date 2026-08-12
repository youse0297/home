#if UNITY_EDITOR
using UnityEditor;

namespace TA.MaterialLab.Editor
{
    public enum TextureCompressionProfile
    {
        BaseColor,
        Normal,
        PackedData
    }

    public static class TextureCompressionPolicy
    {
        public const string StandalonePlatform = "Standalone";

        public static void ApplyStandalone(TextureImporter importer, TextureCompressionProfile profile)
        {
            importer.textureCompression = TextureImporterCompression.CompressedHQ;
            importer.compressionQuality = 100;

            TextureImporterPlatformSettings settings = importer.GetPlatformTextureSettings(StandalonePlatform);
            settings.name = StandalonePlatform;
            settings.overridden = true;
            settings.maxTextureSize = 256;
            settings.textureCompression = TextureImporterCompression.CompressedHQ;
            settings.compressionQuality = 100;
            settings.crunchedCompression = false;
            settings.format = GetExpectedFormat(profile);
            importer.SetPlatformTextureSettings(settings);
        }

        public static bool HasExpectedStandaloneFormat(
            TextureImporter importer,
            TextureCompressionProfile profile
        )
        {
            TextureImporterPlatformSettings settings = importer.GetPlatformTextureSettings(StandalonePlatform);
            return settings.overridden &&
                settings.format == GetExpectedFormat(profile) &&
                settings.compressionQuality == 100 &&
                !settings.crunchedCompression;
        }

        public static TextureImporterFormat GetExpectedFormat(TextureCompressionProfile profile)
        {
            switch (profile)
            {
                case TextureCompressionProfile.BaseColor:
                    return TextureImporterFormat.BC7;
                case TextureCompressionProfile.Normal:
                    return TextureImporterFormat.BC5;
                case TextureCompressionProfile.PackedData:
                    return TextureImporterFormat.DXT1;
                default:
                    throw new System.ArgumentOutOfRangeException(nameof(profile), profile, null);
            }
        }
    }
}
#endif
