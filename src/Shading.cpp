#include "Shading.hpp"

#include "Fresnel.hpp"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace SoftRenderer {
namespace Shading {

namespace {

constexpr double kPi = 3.14159265358979323846;
constexpr double kDirectionEpsilon = 1e-12;
constexpr double kMinimumGgxAlpha = 1e-4;

bool isFinite(const Vec3& value) {
    return std::isfinite(value.x) &&
           std::isfinite(value.y) &&
           std::isfinite(value.z);
}

void requireUnitRange(const Vec3& value, const char* message) {
    if (!isFinite(value) ||
        value.x < 0.0 || value.x > 1.0 ||
        value.y < 0.0 || value.y > 1.0 ||
        value.z < 0.0 || value.z > 1.0) {
        throw std::invalid_argument(message);
    }
}

void requireNonNegative(const Vec3& value, const char* message) {
    if (!isFinite(value) ||
        value.x < 0.0 || value.y < 0.0 || value.z < 0.0) {
        throw std::invalid_argument(message);
    }
}

void requireUnitRange(double value, const char* message) {
    if (!std::isfinite(value) || value < 0.0 || value > 1.0) {
        throw std::invalid_argument(message);
    }
}

Vec3 requireDirection(const Vec3& value, const char* message) {
    const double lengthSquared = value.lengthSquared();
    if (!isFinite(value) || !std::isfinite(lengthSquared) ||
        lengthSquared <= kDirectionEpsilon) {
        throw std::invalid_argument(message);
    }
    return value / std::sqrt(lengthSquared);
}

void requireFiniteResult(const Vec3& value, const char* message) {
    if (!isFinite(value)) {
        throw std::overflow_error(message);
    }
}

Vec3 multiply(const Vec3& first, const Vec3& second) {
    return Vec3(
        first.x * second.x,
        first.y * second.y,
        first.z * second.z
    );
}

Vec3 oneMinus(const Vec3& value) {
    return Vec3(1.0 - value.x, 1.0 - value.y, 1.0 - value.z);
}

double smithGgxVisibility(double normalDotDirection, double roughness) {
    const double shiftedRoughness = roughness + 1.0;
    const double k = shiftedRoughness * shiftedRoughness / 8.0;
    return normalDotDirection /
        (normalDotDirection * (1.0 - k) + k);
}

double decodeSrgbChannel(double value) {
    return value <= 0.04045
        ? value / 12.92
        : std::pow((value + 0.055) / 1.055, 2.4);
}

double encodeSrgbChannel(double value) {
    return value <= 0.0031308
        ? value * 12.92
        : 1.055 * std::pow(value, 1.0 / 2.4) - 0.055;
}

} // namespace

Vec3 lambertDiffuse(
    const Vec3& linearAlbedo,
    const Vec3& normal,
    const DirectionalLight& light
) {
    requireUnitRange(
        linearAlbedo,
        "Lambert albedo must be finite and within [0, 1]"
    );
    requireNonNegative(
        light.radiance,
        "light radiance must be finite and non-negative"
    );
    const Vec3 unitNormal = requireDirection(
        normal,
        "Lambert normal must be finite and non-zero"
    );
    const Vec3 unitDirectionToLight = requireDirection(
        light.directionToLight,
        "light direction must be finite and non-zero"
    );
    const double cosine = std::max(
        unitNormal.dot(unitDirectionToLight),
        0.0
    );
    const Vec3 result = multiply(linearAlbedo, light.radiance) *
        (cosine / kPi);
    requireFiniteResult(result, "Lambert result overflowed");
    return result;
}

double ggxNormalDistribution(double normalDotHalf, double roughness) {
    if (!std::isfinite(normalDotHalf)) {
        throw std::invalid_argument("N dot H must be finite");
    }
    requireUnitRange(
        roughness,
        "roughness must be finite and within [0, 1]"
    );
    const double cosine = std::clamp(normalDotHalf, 0.0, 1.0);
    const double alpha = std::max(
        roughness * roughness,
        kMinimumGgxAlpha
    );
    const double alphaSquared = alpha * alpha;
    const double denominatorTerm =
        cosine * cosine * (alphaSquared - 1.0) + 1.0;
    return alphaSquared /
        (kPi * denominatorTerm * denominatorTerm);
}

double smithGgxGeometry(
    double normalDotView,
    double normalDotLight,
    double roughness
) {
    if (!std::isfinite(normalDotView) || !std::isfinite(normalDotLight)) {
        throw std::invalid_argument("GGX geometry cosines must be finite");
    }
    requireUnitRange(
        roughness,
        "roughness must be finite and within [0, 1]"
    );
    const double viewCosine = std::clamp(normalDotView, 0.0, 1.0);
    const double lightCosine = std::clamp(normalDotLight, 0.0, 1.0);
    return smithGgxVisibility(viewCosine, roughness) *
        smithGgxVisibility(lightCosine, roughness);
}

Vec3 metallicRoughnessF0(const Vec3& baseColor, double metallic) {
    requireUnitRange(
        baseColor,
        "base color must be finite and within [0, 1]"
    );
    requireUnitRange(
        metallic,
        "metallic must be finite and within [0, 1]"
    );
    constexpr double dielectricF0 = 0.04;
    return Vec3(
        dielectricF0 + (baseColor.x - dielectricF0) * metallic,
        dielectricF0 + (baseColor.y - dielectricF0) * metallic,
        dielectricF0 + (baseColor.z - dielectricF0) * metallic
    );
}

Vec3 ggxDirectLighting(
    const MetallicRoughnessMaterial& material,
    const Vec3& normal,
    const Vec3& directionToView,
    const DirectionalLight& light
) {
    const Vec3 f0 = metallicRoughnessF0(
        material.baseColor,
        material.metallic
    );
    requireUnitRange(
        material.roughness,
        "roughness must be finite and within [0, 1]"
    );
    requireNonNegative(
        light.radiance,
        "light radiance must be finite and non-negative"
    );
    const Vec3 unitNormal = requireDirection(
        normal,
        "GGX normal must be finite and non-zero"
    );
    const Vec3 unitDirectionToView = requireDirection(
        directionToView,
        "view direction must be finite and non-zero"
    );
    const Vec3 unitDirectionToLight = requireDirection(
        light.directionToLight,
        "light direction must be finite and non-zero"
    );
    const double normalDotView = unitNormal.dot(unitDirectionToView);
    const double normalDotLight = unitNormal.dot(unitDirectionToLight);
    if (normalDotView <= 0.0 || normalDotLight <= 0.0) {
        return Vec3();
    }

    const Vec3 halfVector = unitDirectionToView + unitDirectionToLight;
    const double halfLengthSquared = halfVector.lengthSquared();
    if (!std::isfinite(halfLengthSquared) || halfLengthSquared <= 0.0) {
        return Vec3();
    }
    const Vec3 halfDirection = halfVector / std::sqrt(halfLengthSquared);
    const double normalDotHalf = std::max(unitNormal.dot(halfDirection), 0.0);
    const double halfDotView = std::max(
        halfDirection.dot(unitDirectionToView),
        0.0
    );

    const double distribution = ggxNormalDistribution(
        normalDotHalf,
        material.roughness
    );
    const double geometry = smithGgxGeometry(
        normalDotView,
        normalDotLight,
        material.roughness
    );
    const Vec3 fresnel = Fresnel::schlick(halfDotView, f0);
    const Vec3 specular = fresnel * (
        distribution * geometry /
        (4.0 * normalDotView * normalDotLight)
    );
    const Vec3 diffuseWeight = oneMinus(fresnel) *
        (1.0 - material.metallic);
    const Vec3 diffuse = multiply(diffuseWeight, material.baseColor) /
        kPi;
    const Vec3 result = multiply(
        diffuse + specular,
        light.radiance
    ) * normalDotLight;
    requireFiniteResult(result, "GGX direct-light result overflowed");
    return result;
}

Vec3 applyExposure(const Vec3& hdrColor, double exposureStops) {
    requireNonNegative(
        hdrColor,
        "HDR color must be finite and non-negative"
    );
    if (!std::isfinite(exposureStops)) {
        throw std::invalid_argument("exposure stops must be finite");
    }
    const double scale = std::exp2(exposureStops);
    if (!std::isfinite(scale)) {
        throw std::overflow_error("exposure scale overflowed");
    }
    const Vec3 result = hdrColor * scale;
    requireFiniteResult(result, "exposed color overflowed");
    return result;
}

Vec3 reinhardToneMap(const Vec3& exposedColor) {
    requireNonNegative(
        exposedColor,
        "tone-map input must be finite and non-negative"
    );
    return Vec3(
        exposedColor.x / (1.0 + exposedColor.x),
        exposedColor.y / (1.0 + exposedColor.y),
        exposedColor.z / (1.0 + exposedColor.z)
    );
}

Vec3 srgbToLinear(const Vec3& srgbColor) {
    requireUnitRange(
        srgbColor,
        "sRGB color must be finite and within [0, 1]"
    );
    return Vec3(
        decodeSrgbChannel(srgbColor.x),
        decodeSrgbChannel(srgbColor.y),
        decodeSrgbChannel(srgbColor.z)
    );
}

Vec3 linearToSrgb(const Vec3& linearColor) {
    requireUnitRange(
        linearColor,
        "linear display color must be finite and within [0, 1]"
    );
    return Vec3(
        encodeSrgbChannel(linearColor.x),
        encodeSrgbChannel(linearColor.y),
        encodeSrgbChannel(linearColor.z)
    );
}

Color toDisplayColor(
    const Vec3& hdrColor,
    double exposureStops,
    double alpha
) {
    if (!std::isfinite(alpha) || alpha < 0.0 || alpha > 1.0) {
        throw std::invalid_argument("display alpha must be within [0, 1]");
    }
    const Vec3 srgb = linearToSrgb(
        reinhardToneMap(applyExposure(hdrColor, exposureStops))
    );
    return Color{srgb.x, srgb.y, srgb.z, alpha};
}

} // namespace Shading
} // namespace SoftRenderer
