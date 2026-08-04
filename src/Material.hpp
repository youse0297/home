#pragma once

#include "Shading.hpp"
#include "Texture2D.hpp"
#include "Vec2.hpp"

namespace SoftRenderer {
namespace Material {

struct MetallicRoughnessDefinition {
    Color baseColorFactor = Color{1.0, 1.0, 1.0, 1.0};
    double metallicFactor = 1.0;
    double roughnessFactor = 1.0;
    const Texture2D* baseColorTexture = nullptr;
    const Texture2D* metallicRoughnessTexture = nullptr;
    SamplerState baseColorSampler{};
    SamplerState metallicRoughnessSampler{};
};

struct MetallicRoughnessSample {
    Shading::MetallicRoughnessMaterial shading;
    double alpha = 1.0;
};

MetallicRoughnessSample sampleMetallicRoughness(
    const MetallicRoughnessDefinition& definition,
    const Vec2& uv
);

} // namespace Material
} // namespace SoftRenderer
