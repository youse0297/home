#pragma once
#include "Mat4.hpp"
#include "Vec3.hpp"

namespace Camera {

    /**
     * 构建 LookAt 视图矩阵（右手系，列主序）
     * @param eye    相机位置
     * @param target 观察目标点
     * @param up     世界坐标系中的上方向（通常 (0,1,0)）
     * @return 视图矩阵，将世界坐标变换到相机局部坐标（相机看向 -Z）
     */
    Mat4 lookAt(const Vec3& eye, const Vec3& target, const Vec3& up);

} // namespace Camera