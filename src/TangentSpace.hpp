#pragma once

#include "Mat3.hpp"
#include "Mat4.hpp"

namespace TangentSpace {

Mat3 makeNormalMatrix(const Mat4& modelMatrix);
Vec3 transformDirection(const Mat4& matrix, const Vec3& direction);
Vec3 transformNormal(const Mat3& normalMatrix, const Vec3& normal);
Mat3 buildTBN(const Vec3& normal, const Vec3& tangent, double tangentSign = 1.0);
Vec3 tangentToWorld(const Mat3& tbn, const Vec3& tangentDirection);
Vec3 worldToTangent(const Mat3& tbn, const Vec3& worldDirection);

} // namespace TangentSpace
