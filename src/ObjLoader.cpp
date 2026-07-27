#include "ObjLoader.hpp"

#include <cmath>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <utility>

namespace SoftRenderer {

ObjParseError::ObjParseError(
    std::string sourceName,
    std::size_t lineNumber,
    std::string reason
)
    : std::runtime_error(
        sourceName + ":" + std::to_string(lineNumber) + ": " + reason
      ),
      sourceName_(std::move(sourceName)),
      lineNumber_(lineNumber),
      reason_(std::move(reason)) {}

const std::string& ObjParseError::sourceName() const noexcept {
    return sourceName_;
}

std::size_t ObjParseError::lineNumber() const noexcept {
    return lineNumber_;
}

const std::string& ObjParseError::reason() const noexcept {
    return reason_;
}

namespace {

[[noreturn]] void fail(
    const std::string& sourceName,
    std::size_t lineNumber,
    const std::string& message
) {
    throw ObjParseError(sourceName, lineNumber, message);
}

double parseNumber(
    const std::string& token,
    const std::string& sourceName,
    std::size_t lineNumber,
    const std::string& fieldName
) {
    std::size_t consumed = 0;
    double value = 0.0;
    try {
        value = std::stod(token, &consumed);
    } catch (const std::exception&) {
        fail(sourceName, lineNumber, "invalid " + fieldName + " value '" + token + "'");
    }
    if (consumed != token.size() || !std::isfinite(value)) {
        fail(sourceName, lineNumber, "invalid " + fieldName + " value '" + token + "'");
    }
    return value;
}

long long parseIndexValue(
    const std::string& token,
    const std::string& sourceName,
    std::size_t lineNumber
) {
    if (token.empty()) {
        fail(sourceName, lineNumber, "face position index is missing");
    }

    std::size_t consumed = 0;
    long long value = 0;
    try {
        value = std::stoll(token, &consumed, 10);
    } catch (const std::exception&) {
        fail(sourceName, lineNumber, "invalid face index '" + token + "'");
    }
    if (consumed != token.size() || value == 0) {
        fail(sourceName, lineNumber, "face index must be a non-zero integer");
    }
    return value;
}

std::size_t resolveIndex(
    long long rawIndex,
    std::size_t valueCount,
    const std::string& indexType,
    const std::string& sourceName,
    std::size_t lineNumber
) {
    if (rawIndex > 0) {
        const unsigned long long oneBased = static_cast<unsigned long long>(rawIndex);
        if (oneBased > valueCount) {
            fail(sourceName, lineNumber, indexType + " index is out of range");
        }
        return static_cast<std::size_t>(oneBased - 1);
    }

    const unsigned long long distance =
        static_cast<unsigned long long>(-(rawIndex + 1)) + 1;
    if (distance > valueCount) {
        fail(sourceName, lineNumber, indexType + " index is out of range");
    }
    return valueCount - static_cast<std::size_t>(distance);
}

std::vector<std::string> readArguments(std::istringstream& lineStream) {
    std::vector<std::string> arguments;
    std::string argument;
    while (lineStream >> argument) {
        arguments.push_back(argument);
    }
    return arguments;
}

void requireArgumentCount(
    const std::vector<std::string>& arguments,
    std::size_t minimum,
    std::size_t maximum,
    const std::string& command,
    const std::string& sourceName,
    std::size_t lineNumber
) {
    if (arguments.size() < minimum || arguments.size() > maximum) {
        fail(
            sourceName,
            lineNumber,
            command + " expects " + std::to_string(minimum) +
                (minimum == maximum ? "" : " to " + std::to_string(maximum)) +
                " values"
        );
    }
}

ObjVertexIndex parseFaceVertex(
    const std::string& token,
    const ObjMesh& mesh,
    const std::string& sourceName,
    std::size_t lineNumber
) {
    const std::size_t firstSlash = token.find('/');
    const std::size_t secondSlash = firstSlash == std::string::npos
        ? std::string::npos
        : token.find('/', firstSlash + 1);
    if (secondSlash != std::string::npos &&
        token.find('/', secondSlash + 1) != std::string::npos) {
        fail(sourceName, lineNumber, "invalid face vertex '" + token + "'");
    }

    const std::string positionToken = token.substr(0, firstSlash);
    const std::string texCoordToken = firstSlash == std::string::npos
        ? std::string()
        : token.substr(
            firstSlash + 1,
            secondSlash == std::string::npos
                ? std::string::npos
                : secondSlash - firstSlash - 1
        );
    const std::string normalToken = secondSlash == std::string::npos
        ? std::string()
        : token.substr(secondSlash + 1);

    if (firstSlash != std::string::npos) {
        if (secondSlash == std::string::npos && texCoordToken.empty()) {
            fail(sourceName, lineNumber, "invalid face vertex '" + token + "'");
        }
        if (secondSlash != std::string::npos && normalToken.empty()) {
            fail(sourceName, lineNumber, "invalid face vertex '" + token + "'");
        }
    }

    ObjVertexIndex index;
    index.positionIndex = resolveIndex(
        parseIndexValue(positionToken, sourceName, lineNumber),
        mesh.positions.size(),
        "position",
        sourceName,
        lineNumber
    );
    if (!texCoordToken.empty()) {
        index.texCoordIndex = resolveIndex(
            parseIndexValue(texCoordToken, sourceName, lineNumber),
            mesh.texCoords.size(),
            "texture coordinate",
            sourceName,
            lineNumber
        );
    }
    if (!normalToken.empty()) {
        index.normalIndex = resolveIndex(
            parseIndexValue(normalToken, sourceName, lineNumber),
            mesh.normals.size(),
            "normal",
            sourceName,
            lineNumber
        );
    }
    return index;
}

} // namespace

bool ObjVertexIndex::hasTexCoord() const noexcept {
    return texCoordIndex != kMissingObjIndex;
}

bool ObjVertexIndex::hasNormal() const noexcept {
    return normalIndex != kMissingObjIndex;
}

ObjMesh ObjLoader::loadFile(const std::string& path) {
    std::ifstream file(path);
    if (!file) {
        throw std::runtime_error("failed to open OBJ file '" + path + "'");
    }
    return parse(file, path);
}

ObjMesh ObjLoader::parse(std::istream& input, const std::string& sourceName) {
    ObjMesh mesh;
    std::string line;
    std::size_t lineNumber = 0;

    while (std::getline(input, line)) {
        ++lineNumber;
        const std::size_t commentStart = line.find('#');
        if (commentStart != std::string::npos) {
            line.erase(commentStart);
        }

        std::istringstream lineStream(line);
        std::string command;
        if (!(lineStream >> command)) {
            continue;
        }
        const std::vector<std::string> arguments = readArguments(lineStream);

        if (command == "v") {
            requireArgumentCount(arguments, 3, 4, command, sourceName, lineNumber);
            double x = parseNumber(arguments[0], sourceName, lineNumber, "position");
            double y = parseNumber(arguments[1], sourceName, lineNumber, "position");
            double z = parseNumber(arguments[2], sourceName, lineNumber, "position");
            if (arguments.size() == 4) {
                const double w = parseNumber(arguments[3], sourceName, lineNumber, "position weight");
                if (w == 0.0) {
                    fail(sourceName, lineNumber, "position weight must be non-zero");
                }
                x /= w;
                y /= w;
                z /= w;
            }
            mesh.positions.emplace_back(x, y, z);
        } else if (command == "vt") {
            requireArgumentCount(arguments, 1, 3, command, sourceName, lineNumber);
            const double u = parseNumber(arguments[0], sourceName, lineNumber, "texture coordinate");
            const double v = arguments.size() >= 2
                ? parseNumber(arguments[1], sourceName, lineNumber, "texture coordinate")
                : 0.0;
            if (arguments.size() == 3) {
                parseNumber(arguments[2], sourceName, lineNumber, "texture coordinate");
            }
            mesh.texCoords.emplace_back(u, v);
        } else if (command == "vn") {
            requireArgumentCount(arguments, 3, 3, command, sourceName, lineNumber);
            mesh.normals.emplace_back(
                parseNumber(arguments[0], sourceName, lineNumber, "normal"),
                parseNumber(arguments[1], sourceName, lineNumber, "normal"),
                parseNumber(arguments[2], sourceName, lineNumber, "normal")
            );
        } else if (command == "f") {
            if (arguments.size() < 3) {
                fail(sourceName, lineNumber, "face expects at least 3 vertices");
            }

            std::vector<ObjVertexIndex> polygon;
            polygon.reserve(arguments.size());
            for (const std::string& argument : arguments) {
                polygon.push_back(parseFaceVertex(argument, mesh, sourceName, lineNumber));
            }
            for (std::size_t index = 1; index + 1 < polygon.size(); ++index) {
                mesh.triangles.push_back(ObjTriangle{{
                    polygon[0],
                    polygon[index],
                    polygon[index + 1]
                }});
            }
        }
    }

    if (input.bad()) {
        fail(sourceName, lineNumber == 0 ? 1 : lineNumber, "I/O failure while reading OBJ data");
    }
    if (mesh.positions.empty()) {
        fail(sourceName, lineNumber == 0 ? 1 : lineNumber, "OBJ contains no positions");
    }
    return mesh;
}

} // namespace SoftRenderer
