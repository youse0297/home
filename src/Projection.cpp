#include "Projection.hpp"
#include <cmath>
#include <stdexcept>

namespace Camera {

    Mat4 perspective(double fovY, double aspect, double zNear, double zFar) {
        constexpr double pi = 3.14159265358979323846;
        if (!std::isfinite(fovY) || fovY <= 0.0 || fovY >= pi) {
            throw std::invalid_argument("fovY must be finite and in the range (0, pi)");
        }
        if (!std::isfinite(zNear) || !std::isfinite(zFar) ||
            zNear <= 0.0 || zFar <= zNear) {
            throw std::invalid_argument("zNear must be >0 and zFar > zNear");
        }
        if (!std::isfinite(aspect) || aspect <= 0.0) {
            throw std::invalid_argument("aspect ratio must be positive");
        }

        const double tanHalfFov = std::tan(fovY * 0.5);
        const double top    = zNear * tanHalfFov;
        const double bottom = -top;
        const double right  = top * aspect;
        const double left   = -right;

        Mat4 proj;
        proj.m[0] = 2.0 * zNear / (right - left);
        proj.m[1] = 0.0;
        proj.m[2] = 0.0;
        proj.m[3] = 0.0;

        proj.m[4] = 0.0;
        proj.m[5] = 2.0 * zNear / (top - bottom);
        proj.m[6] = 0.0;
        proj.m[7] = 0.0;

        proj.m[8]  = (right + left) / (right - left);   // = 0
        proj.m[9]  = (top + bottom) / (top - bottom);   // = 0
        proj.m[10] = -(zFar + zNear) / (zFar - zNear);
        proj.m[11] = -1.0;

        proj.m[12] = 0.0;
        proj.m[13] = 0.0;
        proj.m[14] = -2.0 * zFar * zNear / (zFar - zNear);
        proj.m[15] = 0.0;

        return proj;
    }

} // namespace Camera
