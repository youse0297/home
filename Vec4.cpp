#include "Vec4.hpp"
#include "Vec3.hpp"
#include <cmath>
#include <stdexcept>

Vec4::Vec4(double x, double y, double z, double w) : x(x), y(y), z(z), w(w) {}

Vec4::Vec4(const Vec3& v3, double w) : x(v3.x), y(v3.y), z(v3.z), w(w) {}

Vec4 Vec4::operator+(const Vec4& other) const {
    return Vec4(x + other.x, y + other.y, z + other.z, w + other.w);
}

Vec4 Vec4::operator-(const Vec4& other) const {
    return Vec4(x - other.x, y - other.y, z - other.z, w - other.w);
}

Vec4 Vec4::operator*(double scalar) const {
    return Vec4(x * scalar, y * scalar, z * scalar, w * scalar);
}

Vec4 Vec4::operator/(double scalar) const {
    if (scalar == 0) {
        throw std::invalid_argument("Division by zero");
    }
    return Vec4(x / scalar, y / scalar, z / scalar, w / scalar);
}

Vec4& Vec4::operator+=(const Vec4& other) {
    x += other.x;
    y += other.y;
    z += other.z;
    w += other.w;
    return *this;
}

Vec4& Vec4::operator-=(const Vec4& other) {
    x -= other.x;
    y -= other.y;
    z -= other.z;
    w -= other.w;
    return *this;
}

Vec4& Vec4::operator*=(double scalar) {
    x *= scalar;
    y *= scalar;
    z *= scalar;
    w *= scalar;
    return *this;
}

Vec4& Vec4::operator/=(double scalar) {
    if (scalar == 0) {
        throw std::invalid_argument("Division by zero");
    }
    x /= scalar;
    y /= scalar;
    z /= scalar;
    w /= scalar;
    return *this;
}

double Vec4::dot(const Vec4& other) const {
    return x * other.x + y * other.y + z * other.z + w * other.w;
}

double Vec4::length() const {
    return std::sqrt(dot(*this));
}

Vec4 Vec4::normalize() const {
    double len = length();
    if (len == 0)
        return Vec4(0, 0, 0, 0); // 或者抛出异常，取决于你的设计选择}
    return *this / len;
}

std::ostream& operator<<(std::ostream& os, const Vec4& v) {
    os << "Vec4(" << v.x << ", " << v.y << ", " << v.z << ", " << v.w << ")";
    return os;
}