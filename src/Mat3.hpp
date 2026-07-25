#pragma once

#include "Vec3.hpp"

#include <iosfwd>

class Mat3 {
public:
    double m[9];

    Mat3();
    explicit Mat3(const double data[9]);

    static Mat3 identity();

    double determinant() const;
    Mat3 transpose() const;
    Mat3 inverse() const;
    Vec3 operator*(const Vec3& vector) const;
    Vec3 getColumn(int column) const;

    friend std::ostream& operator<<(std::ostream& stream, const Mat3& matrix);
};
