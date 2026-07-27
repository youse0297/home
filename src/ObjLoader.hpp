#pragma once

#include "Vec2.hpp"
#include "Vec3.hpp"

#include <array>
#include <cstddef>
#include <iosfwd>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

namespace SoftRenderer {

inline constexpr std::size_t kMissingObjIndex =
    std::numeric_limits<std::size_t>::max();

class ObjParseError : public std::runtime_error {
public:
    ObjParseError(
        std::string sourceName,
        std::size_t lineNumber,
        std::string reason
    );

    const std::string& sourceName() const noexcept;
    std::size_t lineNumber() const noexcept;
    const std::string& reason() const noexcept;

private:
    std::string sourceName_;
    std::size_t lineNumber_;
    std::string reason_;
};

struct ObjVertexIndex {
    std::size_t positionIndex = kMissingObjIndex;
    std::size_t texCoordIndex = kMissingObjIndex;
    std::size_t normalIndex = kMissingObjIndex;

    bool hasTexCoord() const noexcept;
    bool hasNormal() const noexcept;
};

struct ObjTriangle {
    std::array<ObjVertexIndex, 3> vertices;
};

struct ObjMesh {
    std::vector<Vec3> positions;
    std::vector<Vec2> texCoords;
    std::vector<Vec3> normals;
    std::vector<ObjTriangle> triangles;
};

class ObjLoader {
public:
    static ObjMesh loadFile(const std::string& path);
    static ObjMesh parse(
        std::istream& input,
        const std::string& sourceName = "<stream>"
    );
};

} // namespace SoftRenderer
