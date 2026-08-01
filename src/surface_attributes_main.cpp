#include "ObjLoader.hpp"
#include "Rasterizer.hpp"
#include "TangentSpace.hpp"
#include "Transform.hpp"
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

SoftRenderer::ObjMesh makeSurfaceMesh() {
    std::istringstream input(
        "v -0.25 -0.25 0\n"
        "v 0.25 -0.25 0.5\n"
        "v -0.25 0.25 0\n"
        "vt 0 0\n"
        "vt 1 0\n"
        "vt 0 1\n"
        "vt 0 0\n"
        "vt -1 0\n"
        "vt 0 1\n"
        "vt 0.5 0.5\n"
        "vn -1 0 1\n"
        "vn -1 0.25 1\n"
        "vn -1 -0.25 1\n"
        "f 1/1/1 2/2/2 3/3/3\n"
        "f 1/4/1 2/5/1 3/6/1\n"
        "f 1/1 2/2 3/3\n"
        "f 1//1 2//1 3//1\n"
        "f 1/7/1 2/7/1 3/7/1\n"
    );
    return SoftRenderer::ObjLoader::parse(input, "surface-attributes.obj");
}

SoftRenderer::VertexStageUniforms makeUniforms(const Mat4& model) {
    SoftRenderer::VertexStageUniforms uniforms;
    uniforms.model = model;
    uniforms.viewport = Pipeline::Viewport{
        0.0,
        0.0,
        8.0,
        8.0,
        0.0,
        1.0,
        Pipeline::ViewportOrigin::TopLeft
    };
    return uniforms;
}

} // namespace

int main() {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        const SoftRenderer::ObjMesh mesh = makeSurfaceMesh();
        const Mat4 model = Transform::scaling(Vec3(2.0, 1.0, 0.5));
        const SoftRenderer::VertexStageUniforms uniforms = makeUniforms(model);
        const std::vector<SoftRenderer::ScreenTriangle> triangles =
            SoftRenderer::VertexStage::shade(mesh, uniforms);
        expect(triangles.size() == 5, "surface triangle count is incorrect");

        const SoftRenderer::ScreenTriangle& standard = triangles[0];
        for (const SoftRenderer::ShadedVertex& vertex : standard.vertices) {
            expect(vertex.hasTexCoord, "textured vertex lost its UV");
            expect(vertex.hasNormal, "source normal was not transformed");
            expect(vertex.hasTangent, "valid UV derivatives did not generate a tangent");
            expect(!vertex.normalWasGenerated,
                   "source normal was incorrectly marked as generated");
            expectNear("world normal length", vertex.worldNormal.length(), 1.0);
            expectNear("world tangent length", vertex.worldTangent.length(), 1.0);
            expectNear(
                "world tangent-normal orthogonality",
                vertex.worldNormal.dot(vertex.worldTangent),
                0.0
            );
            expectNear("standard tangent sign", vertex.tangentSign, 1.0);
        }
        expectNear("first UV.u", standard.vertices[0].texCoord.x, 0.0);
        expectNear("first UV.v", standard.vertices[0].texCoord.y, 0.0);

        constexpr double inverseSqrt17 = 0.24253562503633297;
        const Vec3 expectedWorldNormal(
            -inverseSqrt17,
            0.0,
            4.0 * inverseSqrt17
        );
        const Vec3 expectedWorldTangent(
            4.0 * inverseSqrt17,
            0.0,
            inverseSqrt17
        );
        expectVectorNear(
            "non-uniform world normal",
            standard.vertices[0].worldNormal,
            expectedWorldNormal
        );
        expectVectorNear(
            "non-uniform world tangent",
            standard.vertices[0].worldTangent,
            expectedWorldTangent
        );

        const Vec3 objectNormal = Vec3(-1.0, 0.0, 1.0).normalized();
        const Vec3 naiveWorldNormal = TangentSpace::transformDirection(
            model,
            objectNormal
        ).normalized();
        expectNear(
            "naive normal error baseline",
            naiveWorldNormal.dot(standard.vertices[0].worldTangent),
            -15.0 / 17.0
        );

        const SoftRenderer::ScreenTriangle& mirroredUv = triangles[1];
        for (const SoftRenderer::ShadedVertex& vertex : mirroredUv.vertices) {
            expect(vertex.hasTangent, "mirrored UV tangent was not generated");
            expectNear("mirrored UV tangent sign", vertex.tangentSign, -1.0);
        }

        const SoftRenderer::ScreenTriangle& generatedNormals = triangles[2];
        for (const SoftRenderer::ShadedVertex& vertex : generatedNormals.vertices) {
            expect(vertex.hasNormal, "missing normal was not generated");
            expect(vertex.normalWasGenerated, "generated normal flag is missing");
            expect(vertex.hasTangent, "generated normal did not receive tangent data");
            expectVectorNear(
                "generated world normal",
                vertex.worldNormal,
                expectedWorldNormal
            );
        }

        const SoftRenderer::ScreenTriangle& missingUv = triangles[3];
        for (const SoftRenderer::ShadedVertex& vertex : missingUv.vertices) {
            expect(!vertex.hasTexCoord, "missing UV was incorrectly synthesized");
            expect(vertex.hasNormal, "normal disappeared when UV was missing");
            expect(!vertex.hasTangent, "tangent was generated without UV data");
        }

        const SoftRenderer::ScreenTriangle& degenerateUv = triangles[4];
        for (const SoftRenderer::ShadedVertex& vertex : degenerateUv.vertices) {
            expect(vertex.hasTexCoord, "degenerate UV data was not preserved");
            expect(vertex.hasNormal, "normal disappeared for degenerate UV data");
            expect(!vertex.hasTangent, "degenerate UV derivatives generated a tangent");
        }

        const std::vector<SoftRenderer::RasterSample> samples =
            SoftRenderer::Rasterizer::rasterize(standard, 8, 8);
        expect(!samples.empty(), "surface triangle generated no raster samples");
        const SoftRenderer::RasterSample& sample = samples.front();
        std::array<Vec3, 3> normals;
        std::array<Vec3, 3> tangents;
        std::array<double, 3> tangentSigns;
        for (std::size_t index = 0; index < 3; ++index) {
            normals[index] = standard.vertices[index].worldNormal;
            tangents[index] = standard.vertices[index].worldTangent;
            tangentSigns[index] = standard.vertices[index].tangentSign;
        }
        const Vec3 interpolatedNormal =
            sample.interpolatePerspective<Vec3>(normals).normalized();
        const Vec3 interpolatedTangent =
            sample.interpolatePerspective<Vec3>(tangents).normalized();
        const double interpolatedSign =
            sample.interpolatePerspective<double>(tangentSigns);
        const Mat3 tbn = TangentSpace::buildTBN(
            interpolatedNormal,
            interpolatedTangent,
            interpolatedSign
        );
        expectNear("interpolated TBN determinant", tbn.determinant(), 1.0);
        expectNear("interpolated T dot N", tbn.getColumn(0).dot(tbn.getColumn(2)), 0.0);
        expectNear("interpolated B dot N", tbn.getColumn(1).dot(tbn.getColumn(2)), 0.0);
        expectVectorNear(
            "interpolated tangent-space +Z",
            TangentSpace::tangentToWorld(tbn, Vec3(0.0, 0.0, 1.0)),
            interpolatedNormal
        );

        SoftRenderer::VertexStageUniforms noGeneratedNormals = uniforms;
        noGeneratedNormals.generateMissingNormals = false;
        const std::vector<SoftRenderer::ScreenTriangle> withoutFallback =
            SoftRenderer::VertexStage::shade(mesh, noGeneratedNormals);
        for (const SoftRenderer::ShadedVertex& vertex : withoutFallback[2].vertices) {
            expect(!vertex.hasNormal, "normal fallback could not be disabled");
            expect(!vertex.hasTangent, "tangent survived without a normal");
        }

        const SoftRenderer::VertexStageUniforms reflectedUniforms = makeUniforms(
            Transform::scaling(Vec3(-2.0, 1.0, 0.5))
        );
        const std::vector<SoftRenderer::ScreenTriangle> reflected =
            SoftRenderer::VertexStage::shade(mesh, reflectedUniforms);
        for (const SoftRenderer::ShadedVertex& vertex : reflected[0].vertices) {
            expectNear("negative-scale tangent sign", vertex.tangentSign, -1.0);
        }

        SoftRenderer::ObjMesh invalidNormal = mesh;
        invalidNormal.normals[0] = Vec3();
        expectFailure<std::invalid_argument>(
            "zero source normal",
            "normal must be finite and non-zero",
            [&]() { SoftRenderer::VertexStage::shade(invalidNormal, uniforms); }
        );

        SoftRenderer::ObjMesh invalidUv = mesh;
        invalidUv.texCoords[0].x = std::numeric_limits<double>::infinity();
        expectFailure<std::invalid_argument>(
            "non-finite source UV",
            "texture coordinate must be finite",
            [&]() { SoftRenderer::VertexStage::shade(invalidUv, uniforms); }
        );

        SoftRenderer::VertexStageUniforms singularModel = uniforms;
        singularModel.model = Transform::scaling(Vec3(1.0, 1.0, 0.0));
        expectFailure<std::domain_error>(
            "singular normal matrix",
            "non-singular finite matrix",
            [&]() { SoftRenderer::VertexStage::shade(mesh, singularModel); }
        );

        std::cout << "Surface triangles: " << triangles.size() << '\n';
        std::cout << "Generated normals: 3\n";
        std::cout << "Mirrored UV sign: "
                  << mirroredUv.vertices[0].tangentSign << '\n';
        std::cout << "Interpolated TBN determinant: "
                  << tbn.determinant() << '\n';
        std::cout << "Normal and tangent data acceptance: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Normal and tangent data acceptance failed: "
                  << error.what() << '\n';
        return 1;
    }
}
