#include "Camera.hpp"
#include <cmath>
#include <stdexcept>

namespace Camera {

    Mat4 lookAt(const Vec3& eye, const Vec3& target, const Vec3& up) {
        constexpr double epsilon = 1e-12;
        const Vec3 backwardVector = eye - target;
        if (backwardVector.lengthSquared() <= epsilon) {
            throw std::invalid_argument("eye and target must be different");
        }
        if (up.lengthSquared() <= epsilon) {
            throw std::invalid_argument("up vector must be non-zero");
        }

        const Vec3 backward = backwardVector.normalized();
        const Vec3 rightVector = up.cross(backward);
        if (rightVector.lengthSquared() <= epsilon) {
            throw std::invalid_argument("up vector must not be parallel to the view direction");
        }

        const Vec3 right = rightVector.normalized();
        const Vec3 cameraUp = backward.cross(right);
        Mat4 view = Mat4::identity();

        view.m[0] = right.x;
        view.m[4] = right.y;
        view.m[8] = right.z;

        view.m[1] = cameraUp.x;
        view.m[5] = cameraUp.y;
        view.m[9] = cameraUp.z;

        view.m[2] = backward.x;
        view.m[6] = backward.y;
        view.m[10] = backward.z;

        view.m[12] = -right.dot(eye);
        view.m[13] = -cameraUp.dot(eye);
        view.m[14] = -backward.dot(eye);

        return view;
    }

} // namespace Camera
