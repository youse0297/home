#include "Camera.hpp"
#include <cmath>

namespace Camera {
    
    Mat4 lookAt(const Vec3& eye, const Vec3& target, const Vec3& up) {
        // 计算相机坐标系向量 （右手系）
        Vec3 forward = (eye - target).normalized();
        Vec3 right   = up.cross(forward).normalized();
        Vec3 newUp   = forward.cross(right).normalized();

        // 构造视图矩阵 （列主序）
        // 旋转部分：将世界轴映射到相机轴
        // 平移部分：将相机移到原点
        Mat4 view = Mat4::identity();

        // 第0列 （right）
        view.m[0] = right.x;
        view.m[1] = right.y;
        view.m[2] = right.z;
        // 第1列 （newup）
        view.m[4] = newUp.x;
        view.m[5] = newUp.y;
        view.m[6] = newUp.z;
        // 第2列 （-forward）
        view.m[8] = -forward.x;
        view.m[9] = -forward.y;
        view.m[10] = -forward.z;
        // 第3列 （平移）
        view.m[12] = -right.dot(eye);
        view.m[13] = -newUp.dot(eye);
        view.m[14] = forward.dot(eye);

        return view;
    }
    
} // namespace Camera 
