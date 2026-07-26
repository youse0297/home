#pragma once

#include "Vec3.hpp"

namespace Fresnel {

double dielectricF0(double incidentIor, double transmittedIor);
double schlick(double cosTheta, double f0);
Vec3 schlick(double cosTheta, const Vec3& f0);

} // namespace Fresnel
