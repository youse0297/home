#include "Texture2D.hpp"

#include <algorithm>
#include <charconv>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <limits>
#include <utility>

namespace SoftRenderer {

namespace {

class PpmReader {
public:
    PpmReader(
        const std::vector<unsigned char>& bytes,
        const std::string& sourceName
    ) : bytes_(bytes), sourceName_(sourceName) {}

    std::string nextToken(const std::string& label) {
        skipWhitespaceAndComments();
        if (position_ >= bytes_.size()) {
            fail("missing " + label);
        }

        const std::size_t start = position_;
        while (position_ < bytes_.size() &&
               !isWhitespace(bytes_[position_]) &&
               bytes_[position_] != '#') {
            ++position_;
        }
        return std::string(
            reinterpret_cast<const char*>(bytes_.data() + start),
            position_ - start
        );
    }

    bool hasToken() {
        skipWhitespaceAndComments();
        return position_ < bytes_.size();
    }

    void consumeBinarySeparator() {
        if (position_ >= bytes_.size() || !isWhitespace(bytes_[position_])) {
            fail("binary PPM header must end with whitespace");
        }
        const unsigned char separator = bytes_[position_++];
        if (separator == '\r' && position_ < bytes_.size() &&
            bytes_[position_] == '\n') {
            ++position_;
        }
    }

    std::size_t remaining() const noexcept {
        return bytes_.size() - position_;
    }

    unsigned char readByte() {
        if (position_ >= bytes_.size()) {
            fail("binary PPM pixel data is truncated");
        }
        return bytes_[position_++];
    }

    bool remainingIsWhitespace() const noexcept {
        for (std::size_t index = position_; index < bytes_.size(); ++index) {
            if (!isWhitespace(bytes_[index])) {
                return false;
            }
        }
        return true;
    }

    [[noreturn]] void fail(const std::string& reason) const {
        throw TextureLoadError(sourceName_, reason);
    }

private:
    static bool isWhitespace(unsigned char value) noexcept {
        return value == ' ' || value == '\t' || value == '\r' ||
               value == '\n' || value == '\f' || value == '\v';
    }

    void skipWhitespaceAndComments() {
        while (position_ < bytes_.size()) {
            while (position_ < bytes_.size() && isWhitespace(bytes_[position_])) {
                ++position_;
            }
            if (position_ >= bytes_.size() || bytes_[position_] != '#') {
                return;
            }
            while (position_ < bytes_.size() && bytes_[position_] != '\n') {
                ++position_;
            }
        }
    }

    const std::vector<unsigned char>& bytes_;
    const std::string& sourceName_;
    std::size_t position_ = 0;
};

std::uint64_t parseUnsigned(
    PpmReader& reader,
    const std::string& token,
    const std::string& label
) {
    std::uint64_t value = 0;
    const char* begin = token.data();
    const char* end = begin + token.size();
    const std::from_chars_result result = std::from_chars(begin, end, value);
    if (token.empty() || result.ec != std::errc{} || result.ptr != end) {
        reader.fail(label + " must be an unsigned integer");
    }
    return value;
}

std::size_t requireDimension(
    PpmReader& reader,
    const std::string& token,
    const std::string& label
) {
    const std::uint64_t value = parseUnsigned(reader, token, label);
    if (value == 0 || value > std::numeric_limits<std::size_t>::max()) {
        reader.fail(label + " must fit a non-zero size");
    }
    return static_cast<std::size_t>(value);
}

std::size_t requirePixelCount(
    PpmReader& reader,
    std::size_t width,
    std::size_t height
) {
    if (width > std::numeric_limits<std::size_t>::max() / height) {
        reader.fail("PPM dimensions overflow pixel count");
    }
    const std::size_t count = width * height;
    if (count > std::numeric_limits<std::size_t>::max() / 3) {
        reader.fail("PPM dimensions overflow channel count");
    }
    return count;
}

std::uint32_t requireMaxValue(PpmReader& reader, const std::string& token) {
    const std::uint64_t value = parseUnsigned(reader, token, "PPM max value");
    if (value == 0 || value > 65535) {
        reader.fail("PPM max value must be within [1, 65535]");
    }
    return static_cast<std::uint32_t>(value);
}

Color makeColor(
    std::uint32_t red,
    std::uint32_t green,
    std::uint32_t blue,
    std::uint32_t maxValue
) {
    const double scale = 1.0 / static_cast<double>(maxValue);
    return Color{
        static_cast<double>(red) * scale,
        static_cast<double>(green) * scale,
        static_cast<double>(blue) * scale,
        1.0
    };
}

std::vector<Color> readAsciiPixels(
    PpmReader& reader,
    std::size_t pixelCount,
    std::uint32_t maxValue
) {
    std::vector<Color> texels;
    texels.reserve(pixelCount);
    for (std::size_t pixel = 0; pixel < pixelCount; ++pixel) {
        std::uint32_t channels[3]{};
        for (std::size_t channel = 0; channel < 3; ++channel) {
            const std::uint64_t value = parseUnsigned(
                reader,
                reader.nextToken("PPM pixel channel"),
                "PPM pixel channel"
            );
            if (value > maxValue) {
                reader.fail("PPM pixel channel exceeds max value");
            }
            channels[channel] = static_cast<std::uint32_t>(value);
        }
        texels.push_back(makeColor(
            channels[0],
            channels[1],
            channels[2],
            maxValue
        ));
    }
    if (reader.hasToken()) {
        reader.fail("ASCII PPM contains extra pixel data");
    }
    return texels;
}

std::uint32_t readBinaryChannel(PpmReader& reader, bool wideChannel) {
    const std::uint32_t high = reader.readByte();
    if (!wideChannel) {
        return high;
    }
    return (high << 8U) | reader.readByte();
}

std::vector<Color> readBinaryPixels(
    PpmReader& reader,
    std::size_t pixelCount,
    std::uint32_t maxValue
) {
    const bool wideChannel = maxValue > 255;
    const std::size_t channelCount = pixelCount * 3;
    const std::size_t bytesPerChannel = wideChannel ? 2 : 1;
    if (channelCount >
        std::numeric_limits<std::size_t>::max() / bytesPerChannel) {
        reader.fail("binary PPM byte count overflows");
    }
    const std::size_t requiredBytes = channelCount * bytesPerChannel;
    if (reader.remaining() < requiredBytes) {
        reader.fail("binary PPM pixel data is truncated");
    }

    std::vector<Color> texels;
    texels.reserve(pixelCount);
    for (std::size_t pixel = 0; pixel < pixelCount; ++pixel) {
        const std::uint32_t red = readBinaryChannel(reader, wideChannel);
        const std::uint32_t green = readBinaryChannel(reader, wideChannel);
        const std::uint32_t blue = readBinaryChannel(reader, wideChannel);
        if (red > maxValue || green > maxValue || blue > maxValue) {
            reader.fail("binary PPM pixel channel exceeds max value");
        }
        texels.push_back(makeColor(red, green, blue, maxValue));
    }
    if (!reader.remainingIsWhitespace()) {
        reader.fail("binary PPM contains extra pixel data");
    }
    return texels;
}

std::size_t requireTexturePixelCount(std::size_t width, std::size_t height) {
    if (width == 0 || height == 0) {
        throw std::invalid_argument("texture dimensions must be non-zero");
    }
    if (width > std::numeric_limits<std::size_t>::max() / height) {
        throw std::length_error("texture dimensions overflow texel count");
    }
    return width * height;
}

void requireNormalizedColor(const Color& color) {
    const double channels[4] = {color.r, color.g, color.b, color.a};
    for (double channel : channels) {
        if (!std::isfinite(channel) || channel < 0.0 || channel > 1.0) {
            throw std::invalid_argument("texture color channels must be within [0, 1]");
        }
    }
}

double addressCoordinate(double value, TextureAddressMode mode) {
    switch (mode) {
    case TextureAddressMode::Clamp:
        return std::clamp(value, 0.0, 1.0);
    case TextureAddressMode::Repeat:
        return value - std::floor(value);
    default:
        throw std::invalid_argument("texture address mode is invalid");
    }
}

std::size_t nearestIndex(double coordinate, std::size_t extent) noexcept {
    if (coordinate <= 0.0) {
        return 0;
    }
    if (coordinate >= 1.0) {
        return extent - 1;
    }
    return std::min(
        static_cast<std::size_t>(std::floor(coordinate * extent)),
        extent - 1
    );
}

} // namespace

TextureLoadError::TextureLoadError(
    std::string sourceName,
    std::string reason
) : std::runtime_error(sourceName + ": " + reason),
    sourceName_(std::move(sourceName)),
    reason_(std::move(reason)) {}

const std::string& TextureLoadError::sourceName() const noexcept {
    return sourceName_;
}

const std::string& TextureLoadError::reason() const noexcept {
    return reason_;
}

Texture2D::Texture2D(
    std::size_t width,
    std::size_t height,
    std::vector<Color> texels
) : width_(width), height_(height), texels_(std::move(texels)) {
    const std::size_t expectedCount = requireTexturePixelCount(width_, height_);
    if (texels_.size() != expectedCount) {
        throw std::invalid_argument("texture texel count does not match dimensions");
    }
    for (const Color& texel : texels_) {
        requireNormalizedColor(texel);
    }
}

Texture2D Texture2D::loadPpm(const std::string& path) {
    std::ifstream input(path, std::ios::binary);
    if (!input.is_open()) {
        throw TextureLoadError(path, "could not open texture file");
    }
    return parsePpm(input, path);
}

Texture2D Texture2D::parsePpm(
    std::istream& input,
    const std::string& sourceName
) {
    const std::vector<unsigned char> bytes{
        std::istreambuf_iterator<char>(input),
        std::istreambuf_iterator<char>()
    };
    if (input.bad()) {
        throw TextureLoadError(sourceName, "failed while reading texture data");
    }

    PpmReader reader(bytes, sourceName);
    const std::string magic = reader.nextToken("PPM magic");
    if (magic != "P3" && magic != "P6") {
        reader.fail("PPM magic must be P3 or P6");
    }
    const std::size_t width = requireDimension(
        reader,
        reader.nextToken("PPM width"),
        "PPM width"
    );
    const std::size_t height = requireDimension(
        reader,
        reader.nextToken("PPM height"),
        "PPM height"
    );
    const std::uint32_t maxValue = requireMaxValue(
        reader,
        reader.nextToken("PPM max value")
    );
    const std::size_t pixelCount = requirePixelCount(reader, width, height);

    if (magic == "P3") {
        return Texture2D(
            width,
            height,
            readAsciiPixels(reader, pixelCount, maxValue)
        );
    }

    reader.consumeBinarySeparator();
    return Texture2D(
        width,
        height,
        readBinaryPixels(reader, pixelCount, maxValue)
    );
}

std::size_t Texture2D::width() const noexcept {
    return width_;
}

std::size_t Texture2D::height() const noexcept {
    return height_;
}

std::size_t Texture2D::texelCount() const noexcept {
    return texels_.size();
}

const std::vector<Color>& Texture2D::texels() const noexcept {
    return texels_;
}

const Color& Texture2D::texelAt(std::size_t x, std::size_t y) const {
    return texels_[indexOf(x, y)];
}

Color Texture2D::sampleNearest(
    const Vec2& uv,
    const SamplerState& sampler
) const {
    if (!std::isfinite(uv.x) || !std::isfinite(uv.y)) {
        throw std::invalid_argument("texture coordinates must be finite");
    }
    const double addressedU = addressCoordinate(uv.x, sampler.addressU);
    const double addressedV = addressCoordinate(uv.y, sampler.addressV);

    double rowCoordinate = 0.0;
    switch (sampler.uvOrigin) {
    case TextureUvOrigin::BottomLeft:
        rowCoordinate = 1.0 - addressedV;
        break;
    case TextureUvOrigin::TopLeft:
        rowCoordinate = addressedV;
        break;
    default:
        throw std::invalid_argument("texture UV origin is invalid");
    }

    return texelAt(
        nearestIndex(addressedU, width_),
        nearestIndex(rowCoordinate, height_)
    );
}

std::size_t Texture2D::indexOf(std::size_t x, std::size_t y) const {
    if (x >= width_ || y >= height_) {
        throw std::out_of_range("texture coordinates are out of range");
    }
    return y * width_ + x;
}

} // namespace SoftRenderer
