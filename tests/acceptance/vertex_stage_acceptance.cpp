#include "Camera.hpp"
#include "ObjLoader.hpp"
#include "Projection.hpp"
#include "Transform.hpp"
#include "VertexStage.hpp"

#include <cmath>
#include <functional>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

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
    constexpr double tolerance = 1e-6;
    if (!std::isfinite(actual) || std::abs(actual - expected) > tolerance) {
        throw std::runtime_error(
            label + " expected " + std::to_string(expected) +
            ", got " + std::to_string(actual)
        );
    }
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

SoftRenderer::ObjMesh makeAcceptanceMesh() {
    std::istringstream input(
        "v -1 -1 0\n"
        "v 1 -1 0\n"
        "v 0 1 0\n"
        "v 10 0 0\n"
        "v 11 1 0\n"
        "v 11 -1 0\n"
        "vt 0 0\n"
        "vt 1 0\n"
        "vt 0.5 1\n"
        "vn 0 0 1\n"
        "f 1/1/1 2/2/1 3/3/1\n"
        "f 1 4 3\n"
        "f 4 5 6\n"
    );
    return SoftRenderer::ObjLoader::parse(input, "vertex-stage.obj");
}

} // namespace

int main() {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        const SoftRenderer::ObjMesh mesh = makeAcceptanceMesh();
        const SoftRenderer::VertexStageUniforms uniforms{
            Transform::translation(Vec3(1.0, 0.0, 0.0)),
            Camera::lookAt(
                Vec3(0.0, 0.0, 5.0),
                Vec3(0.0, 0.0, 0.0),
                Vec3(0.0, 1.0, 0.0)
            ),
            Camera::perspective(kPi * 0.5, 4.0 / 3.0, 1.0, 10.0),
            Pipeline::Viewport{
                0.0,
                0.0,
                800.0,
                600.0,
                0.0,
                1.0,
                Pipeline::ViewportOrigin::TopLeft
            }
        };
        const std::vector<SoftRenderer::ScreenTriangle> triangles =
            SoftRenderer::VertexStage::shade(mesh, uniforms);

        expect(triangles.size() == 3, "vertex stage triangle count is incorrect");
        expect(triangles[0].sourceTriangleIndex == 0,
               "source triangle index was not preserved");
        expect(triangles[0].clipStatus == SoftRenderer::TriangleClipStatus::FullyInside,
               "inside triangle clip status is incorrect");
        expect(triangles[1].clipStatus == SoftRenderer::TriangleClipStatus::RequiresClipping,
               "partially visible triangle clip status is incorrect");
        expect(triangles[2].clipStatus == SoftRenderer::TriangleClipStatus::FullyOutside,
               "outside triangle clip status is incorrect");

        const SoftRenderer::ShadedVertex& first = triangles[0].vertices[0];
        expect(first.source.positionIndex == 0 &&
               first.source.texCoordIndex == 0 &&
               first.source.normalIndex == 0,
               "OBJ corner indices were not preserved");
        expectNear("world.x", first.transformed.world.x, 0.0);
        expectNear("world.y", first.transformed.world.y, -1.0);
        expectNear("view.z", first.transformed.view.z, -5.0);
        expectNear("clip.w", first.transformed.clip.w, 5.0);
        expectNear("reciprocal w", first.reciprocalW, 0.2);
        expectNear("ndc.x", first.transformed.ndc.x, 0.0);
        expectNear("ndc.y", first.transformed.ndc.y, -0.2);
        expectNear("ndc.z", first.transformed.ndc.z, 7.0 / 9.0);
        expectNear("screen.x", first.transformed.screen.x, 400.0);
        expectNear("screen.y", first.transformed.screen.y, 360.0);
        expectNear("screen.z", first.transformed.screen.z, 8.0 / 9.0);
        expectNear("second screen.x", triangles[0].vertices[1].transformed.screen.x, 520.0);
        expectNear("third screen.y", triangles[0].vertices[2].transformed.screen.y, 240.0);

        SoftRenderer::ObjMesh invalidPosition = mesh;
        invalidPosition.triangles[0].vertices[0].positionIndex = mesh.positions.size();
        expectFailure<std::out_of_range>(
            "invalid position index",
            "triangle 0 corner 0 position index is out of range",
            [&]() { SoftRenderer::VertexStage::shade(invalidPosition, uniforms); }
        );

        SoftRenderer::ObjMesh invalidTexCoord = mesh;
        invalidTexCoord.triangles[0].vertices[0].texCoordIndex = mesh.texCoords.size();
        expectFailure<std::out_of_range>(
            "invalid texture coordinate index",
            "texture coordinate index is out of range",
            [&]() { SoftRenderer::VertexStage::shade(invalidTexCoord, uniforms); }
        );

        SoftRenderer::ObjMesh invalidNormal = mesh;
        invalidNormal.triangles[0].vertices[0].normalIndex = mesh.normals.size();
        expectFailure<std::out_of_range>(
            "invalid normal index",
            "normal index is out of range",
            [&]() { SoftRenderer::VertexStage::shade(invalidNormal, uniforms); }
        );

        SoftRenderer::VertexStageUniforms invalidViewport = uniforms;
        invalidViewport.viewport.width = 0.0;
        expectFailure<std::invalid_argument>(
            "invalid viewport",
            "viewport width and height must be positive",
            [&]() { SoftRenderer::VertexStage::shade(mesh, invalidViewport); }
        );

        SoftRenderer::VertexStageUniforms zeroW = uniforms;
        zeroW.projection = Mat4();
        expectFailure<std::domain_error>(
            "zero clip w",
            "perspective divide requires a finite non-zero w",
            [&]() { SoftRenderer::VertexStage::shade(mesh, zeroW); }
        );

        std::cout << "Screen triangles: " << triangles.size() << '\n';
        std::cout << "Clip status: inside / requires-clipping / outside\n";
        std::cout << "First screen vertex: ("
                  << first.transformed.screen.x << ", "
                  << first.transformed.screen.y << ", "
                  << first.transformed.screen.z << ")\n";
        std::cout << "Vertex shading stage acceptance: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Vertex shading stage acceptance failed: " << error.what() << '\n';
        return 1;
    }
}
