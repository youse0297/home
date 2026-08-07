#include "ImageIO.hpp"
#include "Material.hpp"
#include "ObjLoader.hpp"
#include "Rasterizer.hpp"
#include "Shading.hpp"
#include "SoftwareRenderer.hpp"
#include "Texture2D.hpp"
#include "VertexStage.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#endif

namespace {

constexpr std::size_t kWidth = 96;
constexpr std::size_t kHeight = 32;
constexpr std::size_t kExpectedMaterialPixels = 1872;
constexpr double kPi = 3.14159265358979323846;

void expect(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

SoftRenderer::ObjMesh makeReleaseMesh() {
    std::istringstream input(
        "v -0.9 -0.75 0\n"
        "v -0.35 -0.75 0\n"
        "v -0.35 0.75 0\n"
        "v -0.9 0.75 0\n"
        "v -0.275 -0.75 0\n"
        "v 0.275 -0.75 0\n"
        "v 0.275 0.75 0\n"
        "v -0.275 0.75 0\n"
        "v 0.35 -0.75 0\n"
        "v 0.9 -0.75 0\n"
        "v 0.9 0.75 0\n"
        "v 0.35 0.75 0\n"
        "vt 0.1666666666666667 0.5\n"
        "vt 0.5 0.5\n"
        "vt 0.8333333333333333 0.5\n"
        "vn -0.4 -0.25 1\n"
        "vn 0.4 -0.25 1\n"
        "vn 0.4 0.25 1\n"
        "vn -0.4 0.25 1\n"
        "f 1/1/1 2/1/2 3/1/3\n"
        "f 1/1/1 3/1/3 4/1/4\n"
        "f 5/2/1 6/2/2 7/2/3\n"
        "f 5/2/1 7/2/3 8/2/4\n"
        "f 9/3/1 10/3/2 11/3/3\n"
        "f 9/3/1 11/3/3 12/3/4\n"
    );
    return SoftRenderer::ObjLoader::parse(input, "release-materials.obj");
}

SoftRenderer::Texture2D makeBaseColorAtlas() {
    std::istringstream input(
        "P3\n"
        "3 1\n"
        "255\n"
        "204 64 32  230 170 50  230 170 50\n"
    );
    return SoftRenderer::Texture2D::parsePpm(
        input,
        "release-base-color.ppm"
    );
}

SoftRenderer::Texture2D makeMetallicRoughnessAtlas() {
    std::istringstream input(
        "P3\n"
        "3 1\n"
        "255\n"
        "255 255 0  255 166 255  255 51 255\n"
    );
    return SoftRenderer::Texture2D::parsePpm(
        input,
        "release-metallic-roughness.ppm"
    );
}

std::uint64_t fnv1a64(const std::vector<unsigned char>& bytes) {
    std::uint64_t hash = UINT64_C(14695981039346656037);
    for (unsigned char byte : bytes) {
        hash ^= static_cast<std::uint64_t>(byte);
        hash *= UINT64_C(1099511628211);
    }
    return hash;
}

std::array<unsigned char, 3> rgbAt(
    const std::vector<unsigned char>& ppm,
    std::size_t width,
    std::size_t height,
    std::size_t x,
    std::size_t y
) {
    if (x >= width || y >= height) {
        throw std::out_of_range("PPM pixel coordinates are out of range");
    }
    const std::string header =
        "P6\n" + std::to_string(width) + " " +
        std::to_string(height) + "\n255\n";
    const std::size_t offset = header.size() + (y * width + x) * 3U;
    if (ppm.size() < offset + 3U) {
        throw std::runtime_error("PPM output is shorter than expected");
    }
    return std::array<unsigned char, 3>{
        ppm[offset],
        ppm[offset + 1U],
        ppm[offset + 2U]
    };
}

void printRgb(
    const char* label,
    const std::array<unsigned char, 3>& rgb
) {
    std::cout << label << ": ("
              << static_cast<unsigned int>(rgb[0]) << ", "
              << static_cast<unsigned int>(rgb[1]) << ", "
              << static_cast<unsigned int>(rgb[2]) << ")\n";
}

void expectRgb(
    const std::string& label,
    const std::array<unsigned char, 3>& actual,
    const std::array<unsigned char, 3>& expected
) {
    expect(actual == expected, label + " RGB8 regression changed");
}

std::vector<unsigned char> readBytes(const std::string& path) {
    std::ifstream input(path, std::ios::binary);
    if (!input.is_open()) {
        throw std::runtime_error("could not reopen release image: " + path);
    }
    return std::vector<unsigned char>{
        std::istreambuf_iterator<char>(input),
        std::istreambuf_iterator<char>()
    };
}

} // namespace

int main(int argc, char** argv) {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        if (argc > 2) {
            throw std::invalid_argument(
                "usage: release_acceptance [output.ppm]"
            );
        }
        const std::string outputPath =
            argc == 2 ? argv[1] : "soft_renderer_release.ppm";

        const SoftRenderer::ObjMesh mesh = makeReleaseMesh();
        const SoftRenderer::Texture2D baseColorAtlas = makeBaseColorAtlas();
        const SoftRenderer::Texture2D metallicRoughnessAtlas =
            makeMetallicRoughnessAtlas();
        SoftRenderer::Material::MetallicRoughnessDefinition material;
        material.baseColorTexture = &baseColorAtlas;
        material.metallicRoughnessTexture = &metallicRoughnessAtlas;

        SoftRenderer::VertexStageUniforms uniforms;
        uniforms.viewport = Pipeline::Viewport{
            0.0,
            0.0,
            static_cast<double>(kWidth),
            static_cast<double>(kHeight),
            0.0,
            1.0,
            Pipeline::ViewportOrigin::TopLeft
        };
        const std::vector<SoftRenderer::ScreenTriangle> triangles =
            SoftRenderer::VertexStage::shade(mesh, uniforms);
        expect(triangles.size() == 6U,
               "release mesh did not produce six triangles");

        const SoftRenderer::Shading::DirectionalLight light{
            Vec3(0.35, 0.25, 1.0),
            Vec3(6.0, 5.5, 5.0)
        };
        const SoftRenderer::RendererConfig config{
            kWidth,
            kHeight,
            SoftRenderer::Color{0.02, 0.025, 0.03, 1.0},
            1.0
        };
        SoftRenderer::SoftwareRenderer renderer(config);
        std::size_t writtenSamples = 0;
        renderer.renderFrame([&](SoftRenderer::FrameContext& context) {
            expect(context.frameIndex == 0U,
                   "release frame index did not start at zero");
            for (const SoftRenderer::ScreenTriangle& triangle : triangles) {
                expect(
                    triangle.clipStatus ==
                        SoftRenderer::TriangleClipStatus::FullyInside,
                    "release triangle unexpectedly requires clipping"
                );
                std::array<Vec2, 3> uvs;
                std::array<Vec3, 3> normals;
                for (std::size_t index = 0; index < 3U; ++index) {
                    expect(triangle.vertices[index].hasTexCoord,
                           "release vertex is missing UV data");
                    expect(triangle.vertices[index].hasNormal,
                           "release vertex is missing normal data");
                    uvs[index] = triangle.vertices[index].texCoord;
                    normals[index] = triangle.vertices[index].worldNormal;
                }

                const std::vector<SoftRenderer::RasterSample> samples =
                    SoftRenderer::Rasterizer::rasterize(
                        triangle,
                        kWidth,
                        kHeight
                    );
                for (const SoftRenderer::RasterSample& sample : samples) {
                    const Vec2 uv =
                        sample.interpolatePerspective<Vec2>(uvs);
                    const SoftRenderer::Material::MetallicRoughnessSample
                        surface =
                            SoftRenderer::Material::sampleMetallicRoughness(
                                material,
                                uv
                            );
                    const Vec3 normal = sample
                        .interpolatePerspective<Vec3>(normals)
                        .normalized();
                    const Vec3 hdr =
                        SoftRenderer::Shading::ggxDirectLighting(
                            surface.shading,
                            normal,
                            Vec3(0.0, 0.0, 1.0),
                            light
                        );
                    const SoftRenderer::Color display =
                        SoftRenderer::Shading::toDisplayColor(
                            hdr,
                            -1.0,
                            surface.alpha
                        );
                    if (context.framebuffer.writeFragment(
                            sample.x,
                            sample.y,
                            sample.depth,
                            display
                        )) {
                        ++writtenSamples;
                    }
                }
            }
        });

        expect(renderer.completedFrames() == 1U,
               "release renderer did not complete exactly one frame");
        expect(writtenSamples == kExpectedMaterialPixels,
               "release material coverage changed");

        std::size_t materialPixels = 0;
        for (double depth : renderer.framebuffer().depthBuffer()) {
            if (depth < 1.0) {
                ++materialPixels;
                expect(
                    std::abs(depth - 0.5) <= 1e-12,
                    "release material depth changed"
                );
            }
        }
        expect(materialPixels == kExpectedMaterialPixels,
               "release depth coverage changed");

        const std::vector<unsigned char> ppm =
            SoftRenderer::ImageIO::encodePpmRgb8(renderer.framebuffer());
        const std::string expectedHeader = "P6\n96 32\n255\n";
        expect(ppm.size() == expectedHeader.size() + kWidth * kHeight * 3U,
               "release PPM byte count changed");
        expect(std::equal(
                   expectedHeader.begin(),
                   expectedHeader.end(),
                   ppm.begin()
               ),
               "release PPM header changed");

        const std::array<unsigned char, 3> matteDielectric =
            rgbAt(ppm, kWidth, kHeight, 16U, 16U);
        const std::array<unsigned char, 3> roughMetal =
            rgbAt(ppm, kWidth, kHeight, 48U, 16U);
        const std::array<unsigned char, 3> smoothMetal =
            rgbAt(ppm, kWidth, kHeight, 80U, 16U);
        const std::array<unsigned char, 3> background =
            rgbAt(ppm, kWidth, kHeight, 0U, 0U);
        const std::uint64_t checksum = fnv1a64(ppm);

        printRgb("Matte dielectric", matteDielectric);
        printRgb("Rough metal", roughMetal);
        printRgb("Smooth metal", smoothMetal);
        printRgb("Background", background);
        std::cout << "PPM FNV-1a64: 0x" << std::hex << checksum
                  << std::dec << '\n';

        expectRgb(
            "matte dielectric",
            matteDielectric,
            std::array<unsigned char, 3>{157U, 60U, 35U}
        );
        expectRgb(
            "rough metal",
            roughMetal,
            std::array<unsigned char, 3>{174U, 138U, 43U}
        );
        expectRgb(
            "smooth metal",
            smoothMetal,
            std::array<unsigned char, 3>{151U, 115U, 32U}
        );
        expectRgb(
            "background",
            background,
            std::array<unsigned char, 3>{5U, 6U, 8U}
        );
        expect(checksum == UINT64_C(0x6e50ef105c6d04c),
               "release PPM checksum changed");

        SoftRenderer::Framebuffer clampFramebuffer(1U, 1U);
        clampFramebuffer.setColor(
            0U,
            0U,
            SoftRenderer::Color{-1.0, 0.5, 2.0, 0.25}
        );
        const std::vector<unsigned char> clampPpm =
            SoftRenderer::ImageIO::encodePpmRgb8(clampFramebuffer);
        expectRgb(
            "PPM clamping",
            rgbAt(clampPpm, 1U, 1U, 0U, 0U),
            std::array<unsigned char, 3>{0U, 128U, 255U}
        );

        bool emptyPathRejected = false;
        try {
            SoftRenderer::ImageIO::writePpmRgb8(
                renderer.framebuffer(),
                ""
            );
        } catch (const std::invalid_argument&) {
            emptyPathRejected = true;
        }
        expect(emptyPathRejected, "empty PPM output path was not rejected");

        SoftRenderer::ImageIO::writePpmRgb8(
            renderer.framebuffer(),
            outputPath
        );
        expect(readBytes(outputPath) == ppm,
               "written release image differs from encoded bytes");

        std::cout << "Material pixels: " << materialPixels << '\n';
        std::cout << "Release image: " << outputPath << '\n';
        std::cout << "Software renderer release acceptance: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Software renderer release acceptance failed: "
                  << error.what() << '\n';
        return 1;
    }
}
