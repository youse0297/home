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
        rejected = std::string(error.what()).find(expectedMessage) !=
            std::string::npos;
    }
    expect(rejected, label + " was not rejected with the expected error");
}

SoftRenderer::ScreenTriangle makeGgxTriangle() {
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
        "ggx-brdf.obj"
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
        expectNear(
            "aligned GGX distribution",
            SoftRenderer::Shading::ggxNormalDistribution(1.0, 0.5),
            16.0 / kPi
        );
        expectNear(
            "grazing GGX distribution",
            SoftRenderer::Shading::ggxNormalDistribution(0.0, 0.5),
            0.0625 / kPi
        );
        const double smoothDistribution =
            SoftRenderer::Shading::ggxNormalDistribution(1.0, 0.0);
        expect(std::isfinite(smoothDistribution) && smoothDistribution > 0.0,
               "zero roughness was not stabilized");

        expectNear(
            "aligned Smith geometry",
            SoftRenderer::Shading::smithGgxGeometry(1.0, 1.0, 0.5),
            1.0
        );
        expectNear(
            "angled Smith geometry",
            SoftRenderer::Shading::smithGgxGeometry(0.5, 0.5, 0.5),
            1024.0 / 1681.0
        );
        expectNear(
            "back-facing Smith geometry",
            SoftRenderer::Shading::smithGgxGeometry(-1.0, 0.5, 0.5),
            0.0
        );

        const Vec3 baseColor(0.8, 0.4, 0.2);
        expectVectorNear(
            "dielectric F0",
            SoftRenderer::Shading::metallicRoughnessF0(baseColor, 0.0),
            Vec3(0.04, 0.04, 0.04)
        );
        expectVectorNear(
            "metal F0",
            SoftRenderer::Shading::metallicRoughnessF0(baseColor, 1.0),
            baseColor
        );
        expectVectorNear(
            "mixed F0",
            SoftRenderer::Shading::metallicRoughnessF0(baseColor, 0.5),
            Vec3(0.42, 0.22, 0.12)
        );

        const SoftRenderer::Shading::DirectionalLight frontalLight{
            Vec3(0.0, 0.0, 4.0),
            Vec3(kPi, kPi, kPi)
        };
        const Vec3 normal(0.0, 0.0, 2.0);
        const Vec3 directionToView(0.0, 0.0, 3.0);
        const SoftRenderer::Shading::MetallicRoughnessMaterial dielectric{
            baseColor,
            0.0,
            0.5
        };
        expectVectorNear(
            "dielectric GGX lighting",
            SoftRenderer::Shading::ggxDirectLighting(
                dielectric,
                normal,
                directionToView,
                frontalLight
            ),
            Vec3(0.928, 0.544, 0.352)
        );

        const SoftRenderer::Shading::MetallicRoughnessMaterial metal{
            baseColor,
            1.0,
            0.5
        };
        expectVectorNear(
            "metal GGX lighting",
            SoftRenderer::Shading::ggxDirectLighting(
                metal,
                normal,
                directionToView,
                frontalLight
            ),
            Vec3(3.2, 1.6, 0.8)
        );

        SoftRenderer::Shading::DirectionalLight backLight = frontalLight;
        backLight.directionToLight = Vec3(0.0, 0.0, -1.0);
        expectVectorNear(
            "back-facing GGX lighting",
            SoftRenderer::Shading::ggxDirectLighting(
                dielectric,
                normal,
                directionToView,
                backLight
            ),
            Vec3()
        );
        expectVectorNear(
            "hidden-view GGX lighting",
            SoftRenderer::Shading::ggxDirectLighting(
                dielectric,
                normal,
                Vec3(0.0, 0.0, -1.0),
                frontalLight
            ),
            Vec3()
        );

        const SoftRenderer::Texture2D texture(
            1,
            1,
            std::vector<SoftRenderer::Color>{
                SoftRenderer::Color{0.5, 0.25, 0.75, 1.0}
            }
        );
        const SoftRenderer::ScreenTriangle triangle = makeGgxTriangle();
        const std::vector<SoftRenderer::RasterSample> samples =
            SoftRenderer::Rasterizer::rasterize(triangle, 8, 8);
        expect(!samples.empty(), "GGX triangle generated no samples");

        std::array<Vec2, 3> uvs;
        std::array<Vec3, 3> normals;
        for (std::size_t index = 0; index < 3; ++index) {
            expect(triangle.vertices[index].hasTexCoord,
                   "GGX vertex is missing UV data");
            expect(triangle.vertices[index].hasNormal,
                   "GGX vertex is missing normal data");
            uvs[index] = triangle.vertices[index].texCoord;
            normals[index] = triangle.vertices[index].worldNormal;
        }

        SoftRenderer::Framebuffer framebuffer(8, 8);
        framebuffer.clear(SoftRenderer::Color{0.0, 0.0, 0.0, 1.0}, 1.0);
        std::size_t writtenSamples = 0;
        for (const SoftRenderer::RasterSample& sample : samples) {
            const Vec2 uv = sample.interpolatePerspective<Vec2>(uvs);
            const SoftRenderer::Color sampled = texture.sampleNearest(uv);
            const Vec3 linearBaseColor = SoftRenderer::Shading::srgbToLinear(
                Vec3(sampled.r, sampled.g, sampled.b)
            );
            const Vec3 interpolatedNormal = sample
                .interpolatePerspective<Vec3>(normals)
                .normalized();
            const SoftRenderer::Shading::MetallicRoughnessMaterial material{
                linearBaseColor,
                0.0,
                1.0
            };
            const Vec3 hdr = SoftRenderer::Shading::ggxDirectLighting(
                material,
                interpolatedNormal,
                Vec3(0.0, 0.0, 1.0),
                frontalLight
            );
            const SoftRenderer::Color display =
                SoftRenderer::Shading::toDisplayColor(hdr, 0.0);
            if (framebuffer.writeFragment(
                    sample.x,
                    sample.y,
                    sample.depth,
                    display
                )) {
                ++writtenSamples;
            }
        }
        expect(writtenSamples == samples.size(),
               "GGX path did not write every visible sample");

        const Vec3 sampledLinear = SoftRenderer::Shading::srgbToLinear(
            Vec3(0.5, 0.25, 0.75)
        );
        const Vec3 expectedHdr = sampledLinear * 0.96 +
            Vec3(0.01, 0.01, 0.01);
        const SoftRenderer::Color expectedDisplay =
            SoftRenderer::Shading::toDisplayColor(expectedHdr, 0.0);
        const SoftRenderer::RasterSample& firstSample = samples.front();
        expectColor(
            "integrated GGX output",
            framebuffer.colorAt(firstSample.x, firstSample.y),
            expectedDisplay
        );
        expectNear(
            "integrated GGX depth",
            framebuffer.depthAt(firstSample.x, firstSample.y),
            0.5
        );

        expectFailure<std::invalid_argument>(
            "invalid GGX cosine",
            "N dot H must be finite",
            [&]() {
                SoftRenderer::Shading::ggxNormalDistribution(
                    std::numeric_limits<double>::quiet_NaN(),
                    0.5
                );
            }
        );
        expectFailure<std::invalid_argument>(
            "invalid GGX roughness",
            "roughness must be finite and within [0, 1]",
            [&]() {
                SoftRenderer::Shading::ggxNormalDistribution(1.0, 1.1);
            }
        );
        expectFailure<std::invalid_argument>(
            "invalid Smith cosine",
            "geometry cosines must be finite",
            [&]() {
                SoftRenderer::Shading::smithGgxGeometry(
                    1.0,
                    std::numeric_limits<double>::infinity(),
                    0.5
                );
            }
        );
        expectFailure<std::invalid_argument>(
            "invalid base color",
            "base color must be finite and within [0, 1]",
            [&]() {
                SoftRenderer::Shading::metallicRoughnessF0(
                    Vec3(1.1, 0.0, 0.0),
                    0.0
                );
            }
        );
        expectFailure<std::invalid_argument>(
            "invalid metallic",
            "metallic must be finite and within [0, 1]",
            [&]() {
                SoftRenderer::Shading::metallicRoughnessF0(baseColor, -0.1);
            }
        );

        SoftRenderer::Shading::MetallicRoughnessMaterial invalidMaterial =
            dielectric;
        invalidMaterial.roughness = -0.1;
        expectFailure<std::invalid_argument>(
            "invalid material roughness",
            "roughness must be finite and within [0, 1]",
            [&]() {
                SoftRenderer::Shading::ggxDirectLighting(
                    invalidMaterial,
                    normal,
                    directionToView,
                    frontalLight
                );
            }
        );
        expectFailure<std::invalid_argument>(
            "zero GGX normal",
            "GGX normal must be finite and non-zero",
            [&]() {
                SoftRenderer::Shading::ggxDirectLighting(
                    dielectric,
                    Vec3(),
                    directionToView,
                    frontalLight
                );
            }
        );
        expectFailure<std::invalid_argument>(
            "zero view direction",
            "view direction must be finite and non-zero",
            [&]() {
                SoftRenderer::Shading::ggxDirectLighting(
                    dielectric,
                    normal,
                    Vec3(),
                    frontalLight
                );
            }
        );
        SoftRenderer::Shading::DirectionalLight negativeRadiance =
            frontalLight;
        negativeRadiance.radiance.y = -1.0;
        expectFailure<std::invalid_argument>(
            "negative GGX radiance",
            "radiance must be finite and non-negative",
            [&]() {
                SoftRenderer::Shading::ggxDirectLighting(
                    dielectric,
                    normal,
                    directionToView,
                    negativeRadiance
                );
            }
        );

        std::cout << "GGX D(1, 0.5): " << 16.0 / kPi << '\n';
        std::cout << "Dielectric GGX: (0.928, 0.544, 0.352)\n";
        std::cout << "Metal GGX: (3.2, 1.6, 0.8)\n";
        std::cout << "GGX framebuffer samples: " << writtenSamples << '\n';
        std::cout << "Simplified GGX BRDF acceptance: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Simplified GGX BRDF acceptance failed: "
                  << error.what() << '\n';
        return 1;
    }
}
