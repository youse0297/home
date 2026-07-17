#include "Mat4.hpp"
#include <cstring>
#include <iomanip>
#include <stdexcept>

Mat4::Mat4() {
    std::memset(m, 0, sizeof(m));
}

Mat4::Mat4(const double data[16]) {
    std::memcpy(m, data, sizeof(m));
}

Mat4 Mat4::identity() {
    Mat4 mat;
    // 设置对角线元素为 1，其余为 0
    mat.m[0] = mat.m[5] = mat.m[10] = mat.m[15] = 1.0;
    return mat;
}

Mat4 Mat4::operator*(const Mat4& other) const {
    Mat4 result;
    // 列主序，C = A * B
    // 结果第 i 行第 j 列的元素 C[i][j] = sum_k (A[i][k] * B[k][j])
    // 即 result.m[col*4 + row] = sum_k (this->m[k*4 + row] * other.m[col*4 + k])
    for (int col = 0; col < 4; ++col) {
        for (int row = 0; row < 4; ++row) {
            double sum = 0.0;
            for (int k = 0; k < 4; ++k) {
                sum += this->m[k * 4 + row] * other.m[col * 4 + k];
            }
            result.m[col * 4 + row] = sum;
        }
    }
    return result;
}

Vec4 Mat4::operator*(const Vec4& vec) const {
    // 列主序：结果 = M * vec
    // result.row = sum_col (M[col][row] * vec[col])
    double x = vec.x, y = vec.y, z = vec.z, w = vec.w;
    double rx = m[0] * x + m[4] * y + m[8] * z + m[12] * w;
    double ry = m[1] * x + m[5] * y + m[9] * z + m[13] * w;
    double rz = m[2] * x + m[6] * y + m[10] * z + m[14] * w;
    double rw = m[3] * x + m[7] * y + m[11] * z + m[15] * w;

    return Vec4(rx, ry, rz, rw);
}

Vec4 operator*(const Vec4& vec, const Mat4& mat) {
    // 左乘：result = vec * M
    // result_j = sum_i (vec[i] * M[i][j])
    // 列主序存储：M[i][j] = mat.m[j*4 + i]
    double rx = vec.x * mat.m[0] + vec.y * mat.m[1] + vec.z * mat.m[2] + vec.w * mat.m[3];
    double ry = vec.x * mat.m[4] + vec.y * mat.m[5] + vec.z * mat.m[6] + vec.w * mat.m[7];
    double rz = vec.x * mat.m[8] + vec.y * mat.m[9] + vec.z * mat.m[10] + vec.w * mat.m[11];
    double rw = vec.x * mat.m[12] + vec.y * mat.m[13] + vec.z * mat.m[14] + vec.w * mat.m[15];

    return Vec4(rx, ry, rz, rw);
}

Vec4 Mat4::getColumn(int col) const {
    if (col < 0 || col >= 4) {
        throw std::out_of_range("Column index out of range. Valid range is 0 to 3.");
    }
    return Vec4(m[col * 4 + 0], m[col * 4 + 1], m[col * 4 + 2], m[col * 4 + 3]);
}

std::ostream& operator<<(std::ostream& os, const Mat4& mat) {
    os << std::fixed << std::setprecision(4);
    for (int row = 0; row < 4; ++row) {
        os << "[ ";
        for (int col = 0; col < 4; ++col) {
            os << mat.m[col * 4 + row];
            if (col < 3) os << ", ";
        }
        os << "]\n" << std::endl;
    }
    return os;
}

