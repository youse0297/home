#pragma once

#include "Framebuffer.hpp"
#include "Vec2.hpp"

#include <cstddef>
#include <iosfwd>
#include <stdexcept>
#include <string>
#include <vector>

namespace SoftRenderer {

enum class TextureAddressMode {
    Clamp,
    Repeat
};

enum class TextureUvOrigin {
    BottomLeft,
    TopLeft
};

struct SamplerState {
    TextureAddressMode addressU = TextureAddressMode::Clamp;
    TextureAddressMode addressV = TextureAddressMode::Clamp;
    TextureUvOrigin uvOrigin = TextureUvOrigin::BottomLeft;
};

class TextureLoadError : public std::runtime_error {
public:
    TextureLoadError(std::string sourceName, std::string reason);

    const std::string& sourceName() const noexcept;
    const std::string& reason() const noexcept;

private:
    std::string sourceName_;
    std::string reason_;
};

class Texture2D {
public:
    Texture2D(
        std::size_t width,
        std::size_t height,
        std::vector<Color> texels
    );

    static Texture2D loadPpm(const std::string& path);
    static Texture2D parsePpm(
        std::istream& input,
        const std::string& sourceName = "<stream>"
    );

    std::size_t width() const noexcept;
    std::size_t height() const noexcept;
    std::size_t texelCount() const noexcept;
    const std::vector<Color>& texels() const noexcept;
    const Color& texelAt(std::size_t x, std::size_t y) const;

    Color sampleNearest(
        const Vec2& uv,
        const SamplerState& sampler = SamplerState{}
    ) const;

private:
    std::size_t indexOf(std::size_t x, std::size_t y) const;

    std::size_t width_ = 0;
    std::size_t height_ = 0;
    std::vector<Color> texels_;
};

} // namespace SoftRenderer
