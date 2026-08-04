#include "Material.hpp"

#include <cmath>
#include <stdexcept>

namespace SoftRenderer {
namespace Material {

namespace {

void requireUnitRange(double value, const char* message) {
    if (!std::isfinite(value) || value < 0.0 || value > 1.0) {
        throw std::invalid_argument(message);
    }
}

void requireColorFactor(const Color& color) {
    requireUnitRange(
        color.r,
        "base color factor must be finite and within [0, 1]"
    );
    requireUnitRange(
        color.g,
        "base color factor must be finite and within [0, 1]"
    );
    requireUnitRange(
        color.b,
        "base color factor must be finite and within [0, 1]"
    );
    requireUnitRange(
        color.a,
        "base color factor must be finite and within [0, 1]"
    );
}

Vec3 multiply(const Vec3& first, const Vec3& second) {
    return Vec3(
        first.x * second.x,
        first.y * second.y,
        first.z * second.z
    );
}

} // namespace

MetallicRoughnessSample sampleMetallicRoughness(
    const MetallicRoughnessDefinition& definition,
    const Vec2& uv
) {
    if (!std::isfinite(uv.x) || !std::isfinite(uv.y)) {
        throw std::invalid_argument("material texture coordinates must be finite");
    }
    requireColorFactor(definition.baseColorFactor);
    requireUnitRange(
        definition.metallicFactor,
        "metallic factor must be finite and within [0, 1]"
    );
    requireUnitRange(
        definition.roughnessFactor,
        "roughness factor must be finite and within [0, 1]"
    );

    Vec3 baseColorTextureValue(1.0, 1.0, 1.0);
    double textureAlpha = 1.0;
    if (definition.baseColorTexture != nullptr) {
        const Color sampled = definition.baseColorTexture->sampleNearest(
            uv,
            definition.baseColorSampler
        );
        baseColorTextureValue = Shading::srgbToLinear(
            Vec3(sampled.r, sampled.g, sampled.b)
        );
        textureAlpha = sampled.a;
    }

    double metallic = definition.metallicFactor;
    double roughness = definition.roughnessFactor;
    if (definition.metallicRoughnessTexture != nullptr) {
        const Color sampled =
            definition.metallicRoughnessTexture->sampleNearest(
                uv,
                definition.metallicRoughnessSampler
            );
        roughness *= sampled.g;
        metallic *= sampled.b;
    }

    const Vec3 factor(
        definition.baseColorFactor.r,
        definition.baseColorFactor.g,
        definition.baseColorFactor.b
    );
    return MetallicRoughnessSample{
        Shading::MetallicRoughnessMaterial{
            multiply(factor, baseColorTextureValue),
            metallic,
            roughness
        },
        definition.baseColorFactor.a * textureAlpha
    };
}

} // namespace Material
} // namespace SoftRenderer
