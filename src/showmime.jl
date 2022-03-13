# _brightness_contrast(color, matrix::AbstractMatrix{T}, brightness, contrast) where {T} =
#     @. color(matrix / 255 * T(contrast) + T(brightness) / 255)

# """
#     brightness_contrast(image::AstroImageMat; brightness_range = 0:255, contrast_range = 1:1000, header_number = 1)

# Visualize the fits image by changing the brightness and contrast of image.

# Users can also provide their own range as keyword arguments.
# """
# function brightness_contrast(img::AstroImageMat{T,N}; brightness_range = 0:255,
#                              contrast_range = 1:1000, header_number = 1) where {T,N}
#     @manipulate for brightness  in brightness_range, contrast in contrast_range
#         _brightness_contrast(C, img.data[header_number], brightness, contrast)
#     end
# end

# This is used in Jupyter notebooks
# Base.show(io::IO, mime::MIME"text/html", img::AstroImageMat; kwargs...) =
#     show(io, mime, brightness_contrast(img), kwargs...)

# This is used in VSCode and others

# If the user displays a AstroImageMat of colors (e.g. one created with imview)
# fal through and display the data as an image
Base.show(io::IO, mime::MIME"image/png", img::AstroImageMat{T}; kwargs...) where {T<:Colorant} =
    show(io, mime, arraydata(img), kwargs...)

# Otherwise, call imview with the default settings.
Base.show(io::IO, mime::MIME"image/png", img::AstroImageMat{T}; kwargs...) where {T} =
    show(io, mime, imview(img), kwargs...)



# Lazily reinterpret the AstroImageMat as a Matrix{Color}, upon request.
# By itself, Images.colorview works fine on AstroImages. But 
# AstroImages are not normalized to be between [0,1]. So we override 
# colorview to first normalize the data using scaleminmax
function render(img::AstroImageMat{T,N}) where {T,N}
    # imgmin, imgmax = img.minmax
    imgmin, imgmax = extrema(img)
    # Add one to maximum to work around this issue:
    # https://github.com/JuliaMath/FixedPointNumbers.jl/issues/102
    f = scaleminmax(_float(imgmin), _float(max(imgmax, imgmax + one(T))))
    return colorview(Gray, f.(_float.(img.data)))
end
Images.colorview(img::AstroImageMat) = render(img)
