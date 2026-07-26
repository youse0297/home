#include "Fresnel.hpp"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace Fresnel {

namespace {

void requireReflectance(double reflectance) {
    if (!std::isfinite(reflectance) || reflectance < 0.0 || reflectance > 1.0) {
        throw std::invalid_argument("F0 must be finite and within [0, 1]");
    }
}

double schlickFactor(double cosTheta) {
    if (!std::isfinite(cosTheta)) {
        throw std::invalid_argument("cosTheta must be finite");
    }
    const double oneMinusCosine = 1.0 - std::clamp(cosTheta, 0.0, 1.0);
    const double squared = oneMinusCosine * oneMinusCosine;
    return squared * squared * oneMinusCosine;
}

} // namespace

double dielectricF0(double incidentIor, double transmittedIor) {
    if (!std::isfinite(incidentIor) || !std::isfinite(transmittedIor) ||
        incidentIor <= 0.0 || transmittedIor <= 0.0) {
        throw std::invalid_argument("indices of refraction must be finite and positive");
    }

    const double scale = std::max(incidentIor, transmittedIor);
    const double normalizedIncident = incidentIor / scale;
    const double normalizedTransmitted = transmittedIor / scale;
    const double contrast =
        (normalizedIncident - normalizedTransmitted) /
        (normalizedIncident + normalizedTransmitted);
    return contrast * contrast;
}

double schlick(double cosTheta, double f0) {
    requireReflectance(f0);
    return f0 + (1.0 - f0) * schlickFactor(cosTheta);
}

Vec3 schlick(double cosTheta, const Vec3& f0) {
    requireReflectance(f0.x);
    requireReflectance(f0.y);
    requireReflectance(f0.z);
    const double factor = schlickFactor(cosTheta);
    return Vec3(
        f0.x + (1.0 - f0.x) * factor,
        f0.y + (1.0 - f0.y) * factor,
        f0.z + (1.0 - f0.z) * factor
    );
}

} // namespace Fresnel
