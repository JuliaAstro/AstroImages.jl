_brightness_contrast(color, matrix::AbstractMatrix{T}, brightness, contrast) where {T} =
    @. color(matrix / 255 * T(contrast) + T(brightness) / 255)

"""
    brightness_contrast(image::AstroImage; brightness_range = 0:255, contrast_range = 1:1000, header_number = 1)

Visualize the fits image by changing the brightness and contrast of image.

Users can also provide their own range as keyword arguments.
"""
function brightness_contrast(img::AstroImage{T,N}; brightness_range = 0:255,
                             contrast_range = 1:1000, header_number = 1) where {T,N}
    @manipulate for brightness  in brightness_range, contrast in contrast_range
        _brightness_contrast(C, img.data[header_number], brightness, contrast)
    end
end

# This is used in Jupyter notebooks
Base.show(io::IO, mime::MIME"text/html", img::AstroImage; kwargs...) =
    show(io, mime, brightness_contrast(img), kwargs...)

# This is used in Jupyter notebooks
Base.show(io::IO, mime::MIME"image/png", img::AstroImage; kwargs...) =
    show(io, mime, imshow(img), kwargs...)

using MappedArrays
using ColorSchemes
using PlotUtils: zscale
export zscale

const _default_clims = Ref{Any}(extrema)
const _default_cmap  = Ref{Union{Symbol,Nothing}}(nothing)

function set_cmap!(cmap)
    _default_cmap[] = cmap
end

function set_clims!(clims)
    _default_clims[] = clims
end

function imshow(
    img::AbstractMatrix{T};
    clims=_default_clims[],
    cmap=_default_cmap[]
) where {T}
    # Users can pass clims as an array or tuple containing the minimum and maximum values
    if typeof(clims) <: AbstractArray || typeof(clims) <: Tuple
        if length(clims) != 2
            error("clims must have exactly two values if provided.")
        end
        imgmin = convert(T, first(clims))
        imgmax = convert(T, last(clims))
    # Or as a callable that computes them given an iterator
    else
        imgmin_0, imgmax_0 = clims(Iterators.filter(pix->isfinite(pix) && !ismissing(pix), img))
        imgmin = convert(T, imgmin_0)
        imgmax = convert(T, imgmax_0)
    end
    return imshow(img,(imgmin,imgmax),cmap)
end
function imshow(img::AbstractMatrix{T}, clims::Union{<:AbstractArray{<:T},Tuple{T,T}}, cmap) where {T}

    if length(clims) != 2
        error("clims must have exactly two values if provided.")
    end
    imgmin, imgmax = clims

    # Pure grayscale display
    if isnothing(cmap)
        f = scaleminmax(_float(imgmin), _float(max(imgmax, imgmax + one(T))))
        return mappedarray(Gray ∘ f, img)
    # Monochromatic image using a colormap
    else
        cscheme = ColorSchemes.colorschemes[cmap]
        # We create a MappedArray that converts from image data
        # to RGBA values on the fly according to a colorscheme.
        return mappedarray(img) do pix
            # We treat Inf values as white / -Inf as black
            return if isinf(pix)
                if pix > 0
                    RGBA{T}(1,1,1,1)
                else
                    RGBA{T}(0,0,0,1)
                end
            # We treat NaN/missing values as transparent
            elseif !isfinite(pix) || ismissing(pix)
                RGBA{T}(0,0,0,0)
            else
                RGBA{T}(get(cscheme::ColorScheme, pix, (imgmin, imgmax)))
            end
        end
    end

end
export imshow


# Lazily reinterpret the AstroImage as a Matrix{Color}, upon request.
# By itself, Images.colorview works fine on AstroImages. But 
# AstroImages are not normalized to be between [0,1]. So we override 
# colorview to first normalize the data using scaleminmax
function render(img::AstroImage{T,N}) where {T,N}
    # imgmin, imgmax = img.minmax
    imgmin, imgmax = extrema(img)
    # Add one to maximum to work around this issue:
    # https://github.com/JuliaMath/FixedPointNumbers.jl/issues/102
    f = scaleminmax(_float(imgmin), _float(max(imgmax, imgmax + one(T))))
    return colorview(Gray, f.(_float.(img.data)))
end
Images.colorview(img::AstroImage) = render(img)