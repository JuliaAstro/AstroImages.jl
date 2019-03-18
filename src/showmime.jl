_brightness_contrast(color, matrix::AbstractMatrix{T}, brightness, contrast) where {T} =
    @. color(matrix / 255 * T(contrast) + T(brightness) / 255)

"""
    brightness_contrast(image::AstroImage; brightness_range = 0:255, contrast_range = 1:1000)

Visualize the fits image by changing the brightness and contrast of image.
Users can also provide their own range as keyword arguments.
"""
function brightness_contrast(img::AstroImage{T,C}; brightness_range = 0:255,
                             contrast_range = 1:1000) where {T,C}
    @manipulate for brightness  in brightness_range, contrast in contrast_range
        _brightness_contrast(C, img.data, brightness, contrast)
    end
end

# This is used in Jupyter notebooks
Base.show(io::IO, mime::MIME"image/png", img::AstroImage; kwargs...) =
    show(io, mime, render(img), kwargs...)
