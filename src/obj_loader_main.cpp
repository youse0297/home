#include "ObjLoader.hpp"

#include <cmath>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

#ifdef _WIN32
#include <windows.h>
#endif

#ifndef OBJ_FIXTURE_PATH
#define OBJ_FIXTURE_PATH "tests/data/vertex_data.obj"
#endif

namespace {

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

SoftRenderer::ObjMesh parseText(
    const std::string& text,
    const std::string& sourceName
) {
    std::istringstream input(text);
    return SoftRenderer::ObjLoader::parse(input, sourceName);
}

void expectParseFailure(
    const std::string& text,
    std::size_t expectedLine,
    const std::string& expectedMessage
) {
    bool rejected = false;
    try {
        parseText(text, "invalid.obj");
    } catch (const SoftRenderer::ObjParseError& error) {
        const std::string expectedPrefix =
            "invalid.obj:" + std::to_string(expectedLine) + ": ";
        rejected = error.sourceName() == "invalid.obj" &&
            error.lineNumber() == expectedLine &&
            error.reason().find(expectedMessage) != std::string::npos &&
            std::string(error.what()).find(expectedPrefix) == 0;
    }
    expect(
        rejected,
        "OBJ parser did not report line " + std::to_string(expectedLine) +
            ": " + expectedMessage
    );
}

} // namespace

int main() {
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif

    try {
        const SoftRenderer::ObjMesh fixture =
            SoftRenderer::ObjLoader::loadFile(OBJ_FIXTURE_PATH);
        expect(fixture.positions.size() == 4, "fixture position count is incorrect");
        expect(fixture.texCoords.size() == 3, "fixture texture coordinate count is incorrect");
        expect(fixture.normals.size() == 1, "fixture normal count is incorrect");
        expect(fixture.triangles.size() == 2, "fixture triangle count is incorrect");
        expectNear("homogeneous position.x", fixture.positions[1].x, 1.0);
        expectNear("position.y", fixture.positions[2].y, 1.0);
        expectNear("texture coordinate.x", fixture.texCoords[1].x, 1.0);
        expectNear("normal.z", fixture.normals[0].z, 1.0);
        expect(fixture.triangles[0].vertices[2].positionIndex == 2,
               "positive position index was not converted to zero-based storage");
        expect(fixture.triangles[1].vertices[1].positionIndex == 2,
               "negative position index was not resolved relative to the data pool");
        expect(!fixture.triangles[1].vertices[0].hasTexCoord(),
               "missing texture coordinate was not preserved");
        expect(fixture.triangles[1].vertices[0].hasNormal(),
               "normal index was not parsed from v//vn syntax");

        const SoftRenderer::ObjMesh polygon = parseText(
            "v 0 0 0\n"
            "v 1 0 0\n"
            "v 1 1 0\n"
            "v 0 1 0\n"
            "vt 0.25\n"
            "vn 0 0 1\n"
            "f 1/1/1 2//1 3/1/1 4/1/1 # quad\n",
            "polygon.obj"
        );
        expect(polygon.triangles.size() == 2,
               "polygon was not triangulated into a fan");
        expect(polygon.triangles[1].vertices[0].positionIndex == 0 &&
               polygon.triangles[1].vertices[1].positionIndex == 2 &&
               polygon.triangles[1].vertices[2].positionIndex == 3,
               "polygon fan indices are incorrect");
        expectNear("one-component texture coordinate.v", polygon.texCoords[0].y, 0.0);

        const SoftRenderer::ObjMesh indexFormats = parseText(
            "v 0 0 0\n"
            "v 1 0 0\n"
            "v 0 1 0\n"
            "vt 0 0\n"
            "vt 1 0\n"
            "vt 0 1\n"
            "vn 0 0 1\n"
            "f 1 2 3\n"
            "f 1/1 2/2 3/3\n"
            "f 1//1 2//1 3//1\n"
            "f -3/-3/-1 -2/-2/-1 -1/-1/-1\n",
            "index-formats.obj"
        );
        expect(indexFormats.triangles.size() == 4,
               "the four supported face index formats were not parsed");
        expect(!indexFormats.triangles[0].vertices[0].hasTexCoord() &&
               !indexFormats.triangles[0].vertices[0].hasNormal(),
               "position-only face acquired optional indices");
        expect(indexFormats.triangles[1].vertices[2].texCoordIndex == 2 &&
               !indexFormats.triangles[1].vertices[2].hasNormal(),
               "v/vt face indices are incorrect");
        expect(!indexFormats.triangles[2].vertices[1].hasTexCoord() &&
               indexFormats.triangles[2].vertices[1].normalIndex == 0,
               "v//vn face indices are incorrect");
        expect(indexFormats.triangles[3].vertices[0].positionIndex == 0 &&
               indexFormats.triangles[3].vertices[1].texCoordIndex == 1 &&
               indexFormats.triangles[3].vertices[2].normalIndex == 0,
               "negative v/vt/vn indices are incorrect");

        expectParseFailure("v 0 nope 0\n", 1, "invalid position value");
        expectParseFailure("v 0 0 0\nf 0 1 1\n", 2, "non-zero integer");
        expectParseFailure("v 0 0 0\nf 1 2 1\n", 2,
                           "position index is out of range");
        expectParseFailure("v 0 0 0\nf 1/1 1/1 1/1\n", 2,
                           "texture coordinate index is out of range");
        expectParseFailure("v 0 0 0\nf 1//1 1//1 1//1\n", 2,
                           "normal index is out of range");
        expectParseFailure("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1/ 2 3\n", 4,
                           "invalid face vertex");
        expectParseFailure("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1/1/ 2 3\n", 4,
                           "invalid face vertex");
        expectParseFailure("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1///1 2 3\n", 4,
                           "invalid face vertex");
        expectParseFailure("v 0 0 0\nf 1 1\n", 2,
                           "face expects at least 3 vertices");
        expectParseFailure("v 0 0 0 0\n", 1,
                           "position weight must be non-zero");
        expectParseFailure("# no vertex data\n", 1, "OBJ contains no positions");

        bool missingFileRejected = false;
        try {
            SoftRenderer::ObjLoader::loadFile("__missing_obj_loader_acceptance__.obj");
        } catch (const std::runtime_error& error) {
            missingFileRejected = std::string(error.what()).find("failed to open OBJ file") !=
                std::string::npos;
        }
        expect(missingFileRejected, "missing OBJ file was not rejected");

        std::cout << "OBJ positions: " << fixture.positions.size() << '\n';
        std::cout << "OBJ texture coordinates: " << fixture.texCoords.size() << '\n';
        std::cout << "OBJ normals: " << fixture.normals.size() << '\n';
        std::cout << "OBJ triangles: " << fixture.triangles.size() << '\n';
        std::cout << "OBJ vertex data acceptance: PASS\n";
        std::cout << "OBJ index and error handling acceptance: PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "OBJ vertex data acceptance failed: " << error.what() << '\n';
        return 1;
    }
}
