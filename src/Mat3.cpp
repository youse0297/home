#include "Mat3.hpp"

#include <algorithm>
#include <cmath>
#include <iomanip>
#include <ostream>
#include <stdexcept>

Mat3::Mat3() : m{} {}

Mat3::Mat3(const double data[9]) {
    std::copy(data, data + 9, m);
}

Mat3 Mat3::identity() {
    Mat3 matrix;
    matrix.m[0] = matrix.m[4] = matrix.m[8] = 1.0;
    return matrix;
}

double Mat3::determinant() const {
    const double a00 = m[0];
    const double a01 = m[3];
    const double a02 = m[6];
    const double a10 = m[1];
    const double a11 = m[4];
    const double a12 = m[7];
    const double a20 = m[2];
    const double a21 = m[5];
    const double a22 = m[8];

    return a00 * (a11 * a22 - a12 * a21) -
           a01 * (a10 * a22 - a12 * a20) +
           a02 * (a10 * a21 - a11 * a20);
}

Mat3 Mat3::transpose() const {
    Mat3 result;
    for (int column = 0; column < 3; ++column) {
        for (int row = 0; row < 3; ++row) {
            result.m[column * 3 + row] = m[row * 3 + column];
        }
    }
    return result;
}

Mat3 Mat3::inverse() const {
    constexpr double epsilon = 1e-12;
    const double determinantValue = determinant();
    if (!std::isfinite(determinantValue) || std::abs(determinantValue) <= epsilon) {
        throw std::domain_error("Mat3 inverse requires a non-singular finite matrix");
    }

    const double a00 = m[0];
    const double a01 = m[3];
    const double a02 = m[6];
    const double a10 = m[1];
    const double a11 = m[4];
    const double a12 = m[7];
    const double a20 = m[2];
    const double a21 = m[5];
    const double a22 = m[8];
    const double inverseDeterminant = 1.0 / determinantValue;

    const double data[9] = {
        (a11 * a22 - a12 * a21) * inverseDeterminant,
        (a12 * a20 - a10 * a22) * inverseDeterminant,
        (a10 * a21 - a11 * a20) * inverseDeterminant,
        (a02 * a21 - a01 * a22) * inverseDeterminant,
        (a00 * a22 - a02 * a20) * inverseDeterminant,
        (a01 * a20 - a00 * a21) * inverseDeterminant,
        (a01 * a12 - a02 * a11) * inverseDeterminant,
        (a02 * a10 - a00 * a12) * inverseDeterminant,
        (a00 * a11 - a01 * a10) * inverseDeterminant
    };
    return Mat3(data);
}

Vec3 Mat3::operator*(const Vec3& vector) const {
    return Vec3(
        m[0] * vector.x + m[3] * vector.y + m[6] * vector.z,
        m[1] * vector.x + m[4] * vector.y + m[7] * vector.z,
        m[2] * vector.x + m[5] * vector.y + m[8] * vector.z
    );
}

Vec3 Mat3::getColumn(int column) const {
    if (column < 0 || column >= 3) {
        throw std::out_of_range("Mat3 column index must be in the range [0, 2]");
    }
    return Vec3(m[column * 3], m[column * 3 + 1], m[column * 3 + 2]);
}

std::ostream& operator<<(std::ostream& stream, const Mat3& matrix) {
    stream << std::fixed << std::setprecision(4);
    for (int row = 0; row < 3; ++row) {
        stream << "[ ";
        for (int column = 0; column < 3; ++column) {
            stream << matrix.m[column * 3 + row];
            if (column < 2) {
                stream << ", ";
            }
        }
        stream << " ]";
        if (row < 2) {
            stream << '\n';
        }
    }
    return stream;
}
