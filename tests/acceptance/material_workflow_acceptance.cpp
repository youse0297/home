#include "Framebuffer.hpp"
#include "Material.hpp"
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

SoftRenderer::ScreenTriangle makeMaterialTriangle() {
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
        "material-workflow.obj"
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
        SoftRenderer::Material::MetallicRoughnessDefinition factorOnly;
        factorOnly.baseColorFactor =
            SoftRenderer::Color{0.8, 0.4, 0.2, 0.75};
        factorOnly.metallicFactor = 0.25;
        factorOnly.roughnessFactor = 0.5;
        const SoftRenderer::Material::MetallicRoughnessSample factorSample =
            SoftRenderer::Material::sampleMetallicRoughness(
                factorOnly,
                Vec2(0.0, 0.0)
            );
        expectVectorNear(
            "factor-only base color",
            factorSample.shading.baseColor,
            Vec3(0.8, 0.4, 0.2)
        );
        expectNear("factor-only metallic", factorSample.shading.metallic, 0.25);
        expectNear("factor-only roughness", factorSample.shading.roughness, 0.5);
        expectNear("factor-only alpha", factorSample.alpha, 0.75);

        const SoftRenderer::Texture2D baseColorTexture(
            1,
            1,
            std::vector<SoftRenderer::Color>{
                SoftRenderer::Color{0.5, 0.25, 0.75, 0.8}
            }
        );
        const SoftRenderer::Texture2D metallicRoughnessTexture(
            1,
            1,
            std::vector<SoftRenderer::Color>{
                SoftRenderer::Color{0.9, 0.6, 0.25, 0.15}
            }
        );
        SoftRenderer::Material::MetallicRoughnessDefinition textured;
        textured.baseColorFactor =
            SoftRenderer::Color{0.8, 0.5, 0.25, 0.5};
        textured.metallicFactor = 0.8;
        textured.roughnessFactor = 0.5;
        textured.baseColorTexture = &baseColorTexture;
        textured.metallicRoughnessTexture = &metallicRoughnessTexture;

        const SoftRenderer::Material::MetallicRoughnessSample texturedSample =
            SoftRenderer::Material::sampleMetallicRoughness(
                textured,
                Vec2(0.5, 0.5)
            );
        const Vec3 decodedBaseColor = SoftRenderer::Shading::srgbToLinear(
            Vec3(0.5, 0.25, 0.75)
        );
        expectVectorNear(
            "textured base color",
            texturedSample.shading.baseColor,
            Vec3(
                decodedBaseColor.x * 0.8,
                decodedBaseColor.y * 0.5,
                decodedBaseColor.z * 0.25
            )
        );
        expectNear("packed metallic B", texturedSample.shading.metallic, 0.2);
        expectNear("packed roughness G", texturedSample.shading.roughness, 0.3);
        expectNear("textured alpha", texturedSample.alpha, 0.4);

        const SoftRenderer::Texture2D addressBaseTexture(
            2,
            1,
            std::vector<SoftRenderer::Color>{
                SoftRenderer::Color{0.25, 0.0, 0.0, 1.0},
                SoftRenderer::Color{0.75, 0.0, 0.0, 1.0}
            }
        );
        const SoftRenderer::Texture2D addressPackedTexture(
            2,
            1,
            std::vector<SoftRenderer::Color>{
                SoftRenderer::Color{0.0, 0.2, 0.3, 1.0},
                SoftRenderer::Color{0.0, 0.8, 0.9, 1.0}
            }
        );
        SoftRenderer::Material::MetallicRoughnessDefinition addressed;
        addressed.baseColorTexture = &addressBaseTexture;
        addressed.metallicRoughnessTexture = &addressPackedTexture;
        addressed.baseColorSampler.addressU =
            SoftRenderer::TextureAddressMode::Clamp;
        addressed.metallicRoughnessSampler.addressU =
            SoftRenderer::TextureAddressMode::Repeat;
        const SoftRenderer::Material::MetallicRoughnessSample addressedSample =
            SoftRenderer::Material::sampleMetallicRoughness(
                addressed,
                Vec2(1.2, 0.5)
            );
        expectNear(
            "independent base sampler",
            addressedSample.shading.baseColor.x,
            SoftRenderer::Shading::srgbToLinear(Vec3(0.75, 0.0, 0.0)).x
        );
        expectNear(
            "independent packed metallic sampler",
            addressedSample.shading.metallic,
            0.3
        );
        expectNear(
            "independent packed roughness sampler",
            addressedSample.shading.roughness,
            0.2
        );

        const SoftRenderer::ScreenTriangle triangle = makeMaterialTriangle();
        const std::vector<SoftRenderer::RasterSample> samples =
            SoftRenderer::Rasterizer::rasterize(triangle, 8, 8);
        expect(!samples.empty(), "material triangle generated no samples");

        std::array<Vec2, 3> uvs;
        std::array<Vec3, 3> normals;
        for (std::size_t index = 0; index < 3; ++index) {
            expect(triangle.vertices[index].hasTexCoord,
                   "material vertex is missing UV data");
            expect(triangle.vertices[index].hasNormal,
                   "material vertex is missing normal data");
            uvs[index] = triangle.vertices[index].texCoord;
            normals[index] = triangle.vertices[index].worldNormal;
        }

        const SoftRenderer::Shading::DirectionalLight light{
            Vec3(0.0, 0.0, 1.0),
            Vec3(kPi, kPi, kPi)
        };
        SoftRenderer::Framebuffer framebuffer(8, 8);
        framebuffer.clear(SoftRenderer::Color{0.0, 0.0, 0.0, 1.0}, 1.0);
        std::size_t writtenSamples = 0;
        for (const SoftRenderer::RasterSample& sample : samples) {
            const Vec2 uv = sample.interpolatePerspective<Vec2>(uvs);
            const SoftRenderer::Material::MetallicRoughnessSample material =
                SoftRenderer::Material::sampleMetallicRoughness(textured, uv);
            const Vec3 normal = sample
                .interpolatePerspective<Vec3>(normals)
                .normalized();
            const Vec3 hdr = SoftRenderer::Shading::ggxDirectLighting(
                material.shading,
                normal,
                Vec3(0.0, 0.0, 1.0),
                light
            );
            const SoftRenderer::Color display =
                SoftRenderer::Shading::toDisplayColor(
                    hdr,
                    0.0,
                    material.alpha
                );
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
               "material path did not write every visible sample");

        const Vec3 expectedHdr = SoftRenderer::Shading::ggxDirectLighting(
            texturedSample.shading,
            Vec3(0.0, 0.0, 1.0),
            Vec3(0.0, 0.0, 1.0),
            light
        );
        const SoftRenderer::Color expectedDisplay =
            SoftRenderer::Shading::toDisplayColor(
                expectedHdr,
                0.0,
                texturedSample.alpha
            );
        const SoftRenderer::RasterSample& firstSample = samples.front();
        expectColor(
            "integrated material output",
            framebuffer.colorAt(firstSample.x, firstSample.y),
            expectedDisplay
        );
        expectNear(
            "integrated material depth",
            framebuffer.depthAt(firstSample.x, firstSample.y),
            0.5
        );

        SoftRenderer::Material::MetallicRoughnessDefinition invalid = textured;
        invalid.baseColorFactor.r = 1.1;
        expectFailure<std::invalid_argument>(
            "invalid base color factor",
            "base color factor must be finite and within [0, 1]",
            [&]() {
                SoftRenderer::Material::sampleMetallicRoughness(
                    invalid,
                    Vec2()
                );
            }
        );
        invalid = textured;
        invalid.metallicFactor = -0.1;
        expectFailure<std::invalid_argument>(
            "invalid metallic factor",
            "metallic factor must be finite and within [0, 1]",
            [&]() {
                SoftRenderer::Material::sampleMetallicRoughness(
                    invalid,
                    Vec2()
                );
            }
        );
        invalid = textured;
        invalid.roughnessFactor =
            std::numeric_limits<double>::quiet_NaN();
        expectFailure<std::invalid_argument>(
            "invalid roughness factor",
            "roughness factor must be finite and within [0, 1]",
            [&]() {
                SoftRenderer::Material::sampleMetallicRoughness(
                    invalid,
                    Vec2()
                );
            }
        );
        expectFailure<std::invalid_argument>(
            "invalid material UV",
            "material texture coordinates must be finite",
            [&]() {
                SoftRenderer::Material::sampleMetallicRoughness(
                    textured,
                    Vec2(std::numeric_limits<double>::infinity(), 0.0)
                );
            }
        );

        std::cout << "Base color factor: (0.8, 0.4, 0.2, 0.75)\n";
        std::cout << "Packed material channels: roughness=0.3, metallic=0.2\n";
        std::cout << "Material framebuffer samples: " << writtenSamples << '\n';
        std::cout << "Metallic-roughness workflow acceptance: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Metallic-roughness workflow acceptance failed: "
                  << error.what() << '\n';
        return 1;
    }
}
