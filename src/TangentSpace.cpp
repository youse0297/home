#include "TangentSpace.hpp"

#include <cmath>
#include <stdexcept>

namespace TangentSpace {

namespace {

constexpr double kEpsilon = 1e-12;

bool isFinite(const Vec3& vector) {
    return std::isfinite(vector.x) &&
           std::isfinite(vector.y) &&
           std::isfinite(vector.z);
}

Vec3 requireNormalized(const Vec3& vector, const char* message) {
    if (!isFinite(vector) || vector.lengthSquared() <= kEpsilon) {
        throw std::invalid_argument(message);
    }
    return vector.normalized();
}

} // namespace

Mat3 makeNormalMatrix(const Mat4& modelMatrix) {
    const double linearPart[9] = {
        modelMatrix.m[0], modelMatrix.m[1], modelMatrix.m[2],
        modelMatrix.m[4], modelMatrix.m[5], modelMatrix.m[6],
        modelMatrix.m[8], modelMatrix.m[9], modelMatrix.m[10]
    };
    return Mat3(linearPart).inverse().transpose();
}

Vec3 transformDirection(const Mat4& matrix, const Vec3& direction) {
    if (!isFinite(direction)) {
        throw std::invalid_argument("direction must be finite");
    }
    const Vec4 transformed = matrix * Vec4(direction, 0.0);
    return Vec3(transformed.x, transformed.y, transformed.z);
}

Vec3 transformNormal(const Mat3& normalMatrix, const Vec3& normal) {
    const Vec3 transformed = normalMatrix * normal;
    return requireNormalized(transformed, "transformed normal must be finite and non-zero");
}

Mat3 buildTBN(const Vec3& normal, const Vec3& tangent, double tangentSign) {
    if (!std::isfinite(tangentSign) || std::abs(tangentSign) <= kEpsilon) {
        throw std::invalid_argument("tangent sign must be finite and non-zero");
    }

    const Vec3 normalizedNormal = requireNormalized(
        normal,
        "normal must be finite and non-zero"
    );
    const Vec3 orthogonalTangent = tangent -
        normalizedNormal * tangent.dot(normalizedNormal);
    const Vec3 normalizedTangent = requireNormalized(
        orthogonalTangent,
        "tangent must not be parallel to the normal"
    );
    const double sign = tangentSign < 0.0 ? -1.0 : 1.0;
    const Vec3 bitangent = normalizedNormal.cross(normalizedTangent) * sign;

    const double data[9] = {
        normalizedTangent.x, normalizedTangent.y, normalizedTangent.z,
        bitangent.x, bitangent.y, bitangent.z,
        normalizedNormal.x, normalizedNormal.y, normalizedNormal.z
    };
    return Mat3(data);
}

Vec3 tangentToWorld(const Mat3& tbn, const Vec3& tangentDirection) {
    return tbn * tangentDirection;
}

Vec3 worldToTangent(const Mat3& tbn, const Vec3& worldDirection) {
    return tbn.transpose() * worldDirection;
}

} // namespace TangentSpace
