# _brightness_contrast(color, matrix::AbstractMatrix{T}, brightness, contrast) where {T} =
#     @. color(matrix / 255 * T(contrast) + T(brightness) / 255)

# """
#     brightness_contrast(image::AstroImageMat; brightness_range = 0:255, contrast_range = 1:1000, header_number = 1)

# Visualize the fits image by changing the brightness and contrast of image.


# This is used in VSCode and others

# If the user displays a AstroImageMat of colors (e.g. one created with imview)
# fal through and display the data as an image
Base.show(io::IO, mime::MIME"image/png", img::AstroImageMat{T}; kwargs...) where {T<:Colorant} =
    show(io, mime, arraydata(img), kwargs...)

# Otherwise, call imview with the default settings.
Base.show(io::IO, mime::MIME"image/png", img::AstroImageMat{T}; kwargs...) where {T<:Union{Number,Missing}} =
    show(io, mime, imview(img), kwargs...)

# # Special handling for complex images
# function Base.show(io::IO, mime::MIME"image/png", img::AstroImageMat{T}; kwargs...) where {T<:Complex}
#     # Not sure we really want to support this functionality, but we will allow it for
#     # now with a warning.
#     @warn "Displaying complex image as magnitude and phase (maxlog=1)" maxlog=1
#     mag_view = imview(abs.(img))
#     angle_view = imview(angle.(img), clims=(-pi, pi), cmap=:cyclic_mygbm_30_95_c78_n256_s25)
#     show(io, mime, vcat(mag_view,angle_view), kwargs...)
# end

# const _autoshow = Base.RefValue{Bool}(true)
# """
#     set_autoshow!(autoshow::Bool)

# By default, `display`ing a 2D AstroImage e.g. at the REPL or in a notebook
# shows it as a PNG image using the `imview` function and user's default
# colormap, stretch, etc.
# If set to false, displaying an image will just show a textual representation.
# You can still visualize images using `imview`.
# """
# function set_autoshow!(autoshow::Bool)
#     _autoshow[] = autoshow
# end
# TODO: for this to work, we need to actually add and remove a show method. TBD how.

# TODO: ensure this still works and is backwards compatible
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
ImageCore.colorview(img::AstroImageMat) = render(img)
