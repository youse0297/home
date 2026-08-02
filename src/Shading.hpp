#pragma once

#include "Framebuffer.hpp"
#include "Vec3.hpp"

namespace SoftRenderer {
namespace Shading {

struct DirectionalLight {
    Vec3 directionToLight = Vec3(0.0, 0.0, 1.0);
    Vec3 radiance = Vec3(1.0, 1.0, 1.0);
};

Vec3 lambertDiffuse(
    const Vec3& linearAlbedo,
    const Vec3& normal,
    const DirectionalLight& light
);

Vec3 applyExposure(const Vec3& hdrColor, double exposureStops);
Vec3 reinhardToneMap(const Vec3& exposedColor);
Vec3 srgbToLinear(const Vec3& srgbColor);
Vec3 linearToSrgb(const Vec3& linearColor);

Color toDisplayColor(
    const Vec3& hdrColor,
    double exposureStops,
    double alpha = 1.0
);

} // namespace Shading
} // namespace SoftRenderer
