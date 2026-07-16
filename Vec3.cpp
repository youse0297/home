#include "Vec3.hpp"
#include <cmath>
#include <stdexcept>

Vec3 Vec3::operator+(const Vec3& other) const {
    return Vec3(x + other.x, y + other.y, z + other.z);
}

Vec3& Vec3::operator+=(const Vec3& other) {
    x += other.x;
    y += other.y;
    z += other.z;
    return *this;
}

Vec3 Vec3::operator-(const Vec3& other) const {
    return Vec3(x - other.x, y - other.y, z - other.z);
}

Vec3& Vec3::operator-=(const Vec3& other) {
    x -= other.x;
    y -= other.y;
    z -= other.z;
    return *this;
}

Vec3 Vec3::operator*(double scalar) const {
    return Vec3(x * scalar, y * scalar, z * scalar);
}

Vec3 operator*(double scalar, const Vec3& vec) {
    return vec * scalar;
}

Vec3& Vec3::operator*=(double scalar) {
    x *= scalar;
    y *= scalar;
    z *= scalar;
    return *this;
}

Vec3 Vec3::operator/(double scalar) const {
    if (scalar == 0.0) throw std::runtime_error("Division by zero");
    return Vec3(x / scalar, y / scalar, z / scalar);
}

Vec3& Vec3::operator/=(double scalar) {
    if (scalar == 0.0) throw std::runtime_error("Division by zero");
    x /= scalar;
    y /= scalar;
    z /= scalar;
    return *this;
}

Vec3 Vec3::operator-() const {
    return Vec3(-x, -y, -z);
}

double Vec3::dot(const Vec3& other) const {
    return x * other.x + y * other.y + z * other.z;
}

double Vec3::lengthSquared() const {
    return dot(*this);
}

double Vec3::length() const {
    return std::sqrt(lengthSquared());
}

Vec3 Vec3::normalized() const {
    double len = length();
    if (len == 0.0) return Vec3(0, 0, 0);
    return *this / len;
}

Vec3& Vec3::normalize() {
    double len = length();
    if (len != 0.0) {
        *this /= len;
    }
    return *this;
}

std::ostream& operator<<(std::ostream& os, const Vec3& v) {
    os << "(" << v.x << ", " << v.y << ", " << v.z << ")";
    return os;
}