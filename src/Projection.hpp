#pragma once
#include "Mat4.hpp"

namespace Camera {
    
    /**
     * 构建透视投影矩阵（右手系，列主序，OpenGL 风格 NDC：[-1,1]）
     * @param fovY  垂直视场角（弧度）
     * @param aspect 宽高比 (width / height)
     * @param near   近平面距离（正数，>0）
     * @param far    远平面距离（正数，>near）
     * @return 投影矩阵，将视锥体映射到 NDC 立方体
     */
    Mat4 perspective(double fovY, double aspect, double zNear, double zFar);

} // namespace Camer
