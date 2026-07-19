#include "Vec3.hpp"
#include "Vec4.hpp"
#include "Mat4.hpp"
#include "Transform.hpp"
#include "Camera.hpp"
#include <iomanip>
#include <iostream>
#include <windows.h>
#include <vector>

int main() {
    SetConsoleOutputCP(CP_UTF8);
    
    std::cout << "\n=== Camera LookAt 测试 ===\n";

    // 配置1：相机在（0，0，5）看向原点，上方向为Y
    Vec3 eye1(0, 0, 5);
    Vec3 target1(0, 0, 0);
    Vec3 up1(0, 1, 0);
    Mat4 view1 = Camera::lookAt(eye1, target1, up1);
    std::cout << "View1 （相机在（0，0，5）看向原点）：\n" << view1 << "\n";

    // 测试一个世界点（0，0，0）变换到相机空间
    Vec4 worldPoint(0, 0, 0, 1);
    Vec4 viewPoint = view1 * worldPoint;
    std::cout << "世界原点（0，0，0）在相机空间 = " << viewPoint << "\n";

    // 配置2：相机在（1，2，3）看向（0，0，0）
    Vec3 eye2(1, 2, 3);
    Vec3 target2(0, 0, 0);
    Vec3 up2(0, 1, 0);
    Mat4 view2 = Camera::lookAt(eye2, target2, up2);
    std::cout << "\nView2（相机在（1，2，3）看向原点：\n" << view2 << "\n";
    Vec4 worldPoint2(1, 2, 3, 1);
    Vec4 viewPoint2 = view2 * worldPoint2;
    std::cout << "相机自身位置（1，2，3）在相机空间 = " << viewPoint2 << "\n";

    // 配置3：改变上方向（让相机倾斜）
    Vec3 eye3(0, 0, 5);
    Vec3 target3(0, 0, 0);
    Vec3 up3(1, 0, 0); // 上方向为x轴 （相机倾斜）
    Mat4 view3 = Camera::lookAt(eye3, target3, up3);
    std::cout << "\nView3（相机在（0，0，5）看向原点，上方向为 X）：\n" << view3 << "\n";
    Vec4 worldPoint3(0, 0, 0, 1);
    Vec4 viewPoint3 = view3 * worldPoint3;
    std::cout << "世界原点在相机空间 = " << viewPoint3 << "\n";

    return 0;
}
