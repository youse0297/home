#include "Framebuffer.hpp"
#include "ObjLoader.hpp"
#include "Rasterizer.hpp"
#include "Shading.hpp"
#include "Texture2D.hpp"
#include "VertexStage.hpp"

#include <array>
#include <cmath>
#include <functional>
#include <iostream>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

namespace {

constexpr double kPi = 3.14159265358979323846;

void expect(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void expectNear(const std::string& label, double actual, double expected) {
    constexpr double tolerance = 1e-9;
    if (!std::isfinite(actual) || std::abs(actual - expected) > tolerance) {
        throw std::runtime_error(
            label + " expected " + std::to_string(expected) +
            ", got " + std::to_string(actual)
        );
    }
}

void expectVectorNear(
    const std::string& label,
    const Vec3& actual,
    const Vec3& expected
) {
    expectNear(label + ".x", actual.x, expected.x);
    expectNear(label + ".y", actual.y, expected.y);
    expectNear(label + ".z", actual.z, expected.z);
}

void expectColor(
    const std::string& label,
    const SoftRenderer::Color& actual,
    const SoftRenderer::Color& expected
) {
    expectNear(label + ".r", actual.r, expected.r);
    expectNear(label + ".g", actual.g, expected.g);
    expectNear(label + ".b", actual.b, expected.b);
    expectNear(label + ".a", actual.a, expected.a);
}

template <typename Exception>
void expectFailure(
    const std::string& label,
    const std::string& expectedMessage,
    const std::function<void()>& operation
) {
    bool rejected = false;
    try {
        operation();
    } catch (const Exception& error) {
        rejected = std::string(error.what()).find(expectedMessage) != std::string::npos;
    }
    expect(rejected, label + " was not rejected with the expected error");
}

SoftRenderer::ScreenTriangle makeShadedTriangle() {
    std::istringstream input(
        "v -0.5 -0.5 0\n"
        "v 0.5 -0.5 0\n"
        "v -0.5 0.5 0\n"
        "vt 0.5 0.5\n"
        "vn 0 0 1\n"
        "f 1/1/1 2/1/1 3/1/1\n"
    );
    const SoftRenderer::ObjMesh mesh = SoftRenderer::ObjLoader::parse(
        input,
        "diffuse-exposure.obj"
    );
    SoftRenderer::VertexStageUniforms uniforms;
    uniforms.viewport = Pipeline::Viewport{
        0.0,
        0.0,
        8.0,
        8.0,
        0.0,
        1.0,
        Pipeline::ViewportOrigin::TopLeft
    };
    return SoftRenderer::VertexStage::shade(mesh, uniforms).front();
}

} // namespace

int main() {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        const Vec3 albedo(0.8, 0.4, 0.2);
        const SoftRenderer::Shading::DirectionalLight frontalLight{
            Vec3(0.0, 0.0, 5.0),
            Vec3(kPi, 2.0 * kPi, 0.5 * kPi)
        };
        expectVectorNear(
            "frontal Lambert",
            SoftRenderer::Shading::lambertDiffuse(
                albedo,
                Vec3(0.0, 0.0, 2.0),
                frontalLight
            ),
            Vec3(0.8, 0.8, 0.1)
        );

        const SoftRenderer::Shading::DirectionalLight sixtyDegreeLight{
            Vec3(std::sqrt(3.0), 0.0, 1.0),
            Vec3(kPi, kPi, kPi)
        };
        expectVectorNear(
            "sixty-degree Lambert",
            SoftRenderer::Shading::lambertDiffuse(
                albedo,
                Vec3(0.0, 0.0, 1.0),
                sixtyDegreeLight
            ),
            albedo * 0.5
        );
        const SoftRenderer::Shading::DirectionalLight backLight{
            Vec3(0.0, 0.0, -1.0),
            Vec3(kPi, kPi, kPi)
        };
        expectVectorNear(
            "back-facing Lambert",
            SoftRenderer::Shading::lambertDiffuse(
                albedo,
                Vec3(0.0, 0.0, 1.0),
                backLight
            ),
            Vec3()
        );

        const Vec3 hdrColor(0.5, 1.0, 3.0);
        const Vec3 exposed = SoftRenderer::Shading::applyExposure(hdrColor, 1.0);
        expectVectorNear("positive exposure", exposed, Vec3(1.0, 2.0, 6.0));
        expectVectorNear(
            "negative exposure",
            SoftRenderer::Shading::applyExposure(hdrColor, -1.0),
            Vec3(0.25, 0.5, 1.5)
        );
        const Vec3 toneMapped = SoftRenderer::Shading::reinhardToneMap(exposed);
        expectVectorNear(
            "Reinhard tone map",
            toneMapped,
            Vec3(0.5, 2.0 / 3.0, 6.0 / 7.0)
        );

        const Vec3 decoded = SoftRenderer::Shading::srgbToLinear(
            Vec3(0.04045, 0.5, 1.0)
        );
        expectNear("sRGB linear segment", decoded.x, 0.0031308049535603713);
        expectNear("sRGB power segment", decoded.y, 0.21404114048223255);
        expectNear("sRGB white", decoded.z, 1.0);
        const Vec3 roundTripSource(0.02, 0.5, 1.0);
        expectVectorNear(
            "sRGB round trip",
            SoftRenderer::Shading::linearToSrgb(
                SoftRenderer::Shading::srgbToLinear(roundTripSource)
            ),
            roundTripSource
        );

        const SoftRenderer::Color displayColor =
            SoftRenderer::Shading::toDisplayColor(hdrColor, 1.0, 0.75);
        const Vec3 expectedSrgb = SoftRenderer::Shading::linearToSrgb(toneMapped);
        expectColor(
            "display transform",
            displayColor,
            SoftRenderer::Color{
                expectedSrgb.x,
                expectedSrgb.y,
                expectedSrgb.z,
                0.75
            }
        );

        const SoftRenderer::Texture2D texture(
            1,
            1,
            std::vector<SoftRenderer::Color>{
                SoftRenderer::Color{0.5, 0.5, 0.5, 1.0}
            }
        );
        const SoftRenderer::ScreenTriangle triangle = makeShadedTriangle();
        const std::vector<SoftRenderer::RasterSample> samples =
            SoftRenderer::Rasterizer::rasterize(triangle, 8, 8);
        expect(!samples.empty(), "diffuse triangle generated no samples");

        std::array<Vec2, 3> uvs;
        std::array<Vec3, 3> normals;
        for (std::size_t index = 0; index < 3; ++index) {
            expect(triangle.vertices[index].hasTexCoord,
                   "diffuse vertex is missing UV data");
            expect(triangle.vertices[index].hasNormal,
                   "diffuse vertex is missing normal data");
            uvs[index] = triangle.vertices[index].texCoord;
            normals[index] = triangle.vertices[index].worldNormal;
        }

        SoftRenderer::Framebuffer framebuffer(8, 8);
        framebuffer.clear(SoftRenderer::Color{0.0, 0.0, 0.0, 1.0}, 1.0);
        const SoftRenderer::Shading::DirectionalLight whiteLight{
            Vec3(0.0, 0.0, 1.0),
            Vec3(kPi, kPi, kPi)
        };
        std::size_t writtenSamples = 0;
        for (const SoftRenderer::RasterSample& sample : samples) {
            const Vec2 uv = sample.interpolatePerspective<Vec2>(uvs);
            const SoftRenderer::Color sampled = texture.sampleNearest(uv);
            const Vec3 linearAlbedo = SoftRenderer::Shading::srgbToLinear(
                Vec3(sampled.r, sampled.g, sampled.b)
            );
            const Vec3 normal = sample
                .interpolatePerspective<Vec3>(normals)
                .normalized();
            const Vec3 radiance = SoftRenderer::Shading::lambertDiffuse(
                linearAlbedo,
                normal,
                whiteLight
            );
            const SoftRenderer::Color output =
                SoftRenderer::Shading::toDisplayColor(radiance, 1.0);
            if (framebuffer.writeFragment(
                    sample.x,
                    sample.y,
                    sample.depth,
                    output
                )) {
                ++writtenSamples;
            }
        }
        expect(writtenSamples == samples.size(),
               "diffuse path did not write every visible sample");
        const SoftRenderer::RasterSample& firstSample = samples.front();
        const Vec3 grayLinear = SoftRenderer::Shading::srgbToLinear(
            Vec3(0.5, 0.5, 0.5)
        );
        const SoftRenderer::Color expectedOutput =
            SoftRenderer::Shading::toDisplayColor(grayLinear, 1.0);
        expectColor(
            "integrated diffuse output",
            framebuffer.colorAt(firstSample.x, firstSample.y),
            expectedOutput
        );
        expectNear(
            "integrated diffuse depth",
            framebuffer.depthAt(firstSample.x, firstSample.y),
            0.5
        );

        expectFailure<std::invalid_argument>(
            "invalid Lambert albedo",
            "albedo must be finite and within [0, 1]",
            [&]() {
                SoftRenderer::Shading::lambertDiffuse(
                    Vec3(1.1, 0.0, 0.0),
                    Vec3(0.0, 0.0, 1.0),
                    frontalLight
                );
            }
        );
        expectFailure<std::invalid_argument>(
            "zero Lambert normal",
            "normal must be finite and non-zero",
            [&]() {
                SoftRenderer::Shading::lambertDiffuse(albedo, Vec3(), frontalLight);
            }
        );
        SoftRenderer::Shading::DirectionalLight invalidDirection = frontalLight;
        invalidDirection.directionToLight = Vec3();
        expectFailure<std::invalid_argument>(
            "zero light direction",
            "light direction must be finite and non-zero",
            [&]() {
                SoftRenderer::Shading::lambertDiffuse(
                    albedo,
                    Vec3(0.0, 0.0, 1.0),
                    invalidDirection
                );
            }
        );
        SoftRenderer::Shading::DirectionalLight negativeRadiance = frontalLight;
        negativeRadiance.radiance.x = -1.0;
        expectFailure<std::invalid_argument>(
            "negative light radiance",
            "radiance must be finite and non-negative",
            [&]() {
                SoftRenderer::Shading::lambertDiffuse(
                    albedo,
                    Vec3(0.0, 0.0, 1.0),
                    negativeRadiance
                );
            }
        );
        expectFailure<std::invalid_argument>(
            "negative HDR color",
            "HDR color must be finite and non-negative",
            [&]() {
                SoftRenderer::Shading::applyExposure(Vec3(-1.0, 0.0, 0.0), 0.0);
            }
        );
        expectFailure<std::invalid_argument>(
            "non-finite exposure",
            "exposure stops must be finite",
            [&]() {
                SoftRenderer::Shading::applyExposure(
                    hdrColor,
                    std::numeric_limits<double>::quiet_NaN()
                );
            }
        );
        expectFailure<std::overflow_error>(
            "overflowing exposure",
            "exposure scale overflowed",
            [&]() { SoftRenderer::Shading::applyExposure(hdrColor, 1024.0); }
        );
        expectFailure<std::invalid_argument>(
            "negative tone-map input",
            "tone-map input must be finite and non-negative",
            [&]() { SoftRenderer::Shading::reinhardToneMap(Vec3(0.0, -1.0, 0.0)); }
        );
        expectFailure<std::invalid_argument>(
            "out-of-range sRGB input",
            "sRGB color must be finite and within [0, 1]",
            [&]() { SoftRenderer::Shading::srgbToLinear(Vec3(0.0, 1.1, 0.0)); }
        );
        expectFailure<std::invalid_argument>(
            "out-of-range linear display input",
            "linear display color must be finite and within [0, 1]",
            [&]() { SoftRenderer::Shading::linearToSrgb(Vec3(0.0, -0.1, 0.0)); }
        );
        expectFailure<std::invalid_argument>(
            "invalid display alpha",
            "display alpha must be within [0, 1]",
            [&]() { SoftRenderer::Shading::toDisplayColor(hdrColor, 0.0, 1.1); }
        );

        std::cout << "Frontal Lambert: (0.8, 0.8, 0.1)\n";
        std::cout << "Exposure +1 EV: (1, 2, 6)\n";
        std::cout << "Reinhard: (0.5, 0.666667, 0.857143)\n";
        std::cout << "Diffuse framebuffer samples: " << writtenSamples << '\n';
        std::cout << "Diffuse and exposure acceptance: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Diffuse and exposure acceptance failed: "
                  << error.what() << '\n';
        return 1;
    }
}
