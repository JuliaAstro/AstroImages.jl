# _brightness_contrast(color, matrix::AbstractMatrix{T}, brightness, contrast) where {T} =
#     @. color(matrix / 255 * T(contrast) + T(brightness) / 255)

# """
#     brightness_contrast(image::AstroImage; brightness_range = 0:255, contrast_range = 1:1000, header_number = 1)

# Visualize the fits image by changing the brightness and contrast of image.

# Users can also provide their own range as keyword arguments.
# """
# function brightness_contrast(img::AstroImage{T,N}; brightness_range = 0:255,
#                              contrast_range = 1:1000, header_number = 1) where {T,N}
#     @manipulate for brightness  in brightness_range, contrast in contrast_range
#         _brightness_contrast(C, img.data[header_number], brightness, contrast)
#     end
# end

# This is used in Jupyter notebooks
# Base.show(io::IO, mime::MIME"text/html", img::AstroImage; kwargs...) =
#     show(io, mime, brightness_contrast(img), kwargs...)

# This is used in VSCode and others
Base.show(io::IO, mime::MIME"image/png", img::AstroImage; kwargs...) =
    show(io, mime, imview(img), kwargs...)

using Statistics
using MappedArrays
using ColorSchemes
using PlotUtils: zscale
export zscale

const _default_clims = Ref{Any}(extrema)
const _default_cmap  = Ref{Union{Symbol,Nothing}}(nothing)
const _default_stretch  = Ref{Any}(identity)

function set_cmap!(cmap)
    _default_cmap[] = cmap
end

function set_clims!(clims)
    _default_clims[] = clims
end

function set_stretch!(stretch)
    _default_stretch[] = stretch
end

skipmissingnan(itr) = Iterators.filter(el->!ismissing(el) && isfinite(el), itr)

# These reproduce the behaviour of DS9 according to http://ds9.si.edu/doc/ref/how.html
logstretch(x,a=1000) = log(a*x+1)/log(a)
powstretch(x,a=1000) = (a^x - 1)/a
sqrtstretch = sqrt
squarestretch(x) = x^2
asinhstretch(x) = asinh(10x)/3
sinhstretch(x) = sinh(3x)/10
# The additional stretches reproduce behaviour from astropy
powerdiststretch(x, a=1000) = (a^x - 1) / (a - 1)
export logstretch, powstretch, sqrtstretch, squarestretch, asinhstretch, sinhstretch, powerdiststretch

function imview(
    img::AbstractMatrix{T};
    clims=_default_clims[],
    stretch=_default_stretch[],
    cmap=_default_cmap[],
) where {T}
    isempt = isempty(img)
    if isempt
        return
    end
    # Users will occaisionally pass in data that is 0D, filled with NaN, or filled with missing.
    # We still need to do something reasonable in those caes.
    nonempty = any(x-> !ismissing(x) && isfinite(x), img)
    if !nonempty
        return
    end
    # Users can pass clims as an array or tuple containing the minimum and maximum values
    if typeof(clims) <: AbstractArray || typeof(clims) <: Tuple
        if length(clims) != 2
            error("clims must have exactly two values if provided.")
        end
        imgmin = convert(T, first(clims))
        imgmax = convert(T, last(clims))
    # Or as a callable that computes them given an iterator
    else
        if nonempty
            imgmin_0, imgmax_0 = clims(skipmissingnan(img))
        else
            # Fallback for empty images
            imgmin_0, imgmax_0 = 0,1
        end
        imgmin = convert(T, imgmin_0)
        imgmax = convert(T, imgmax_0)
    end
    normed = normedclampedview(img, (imgmin, imgmax))
    return _imview(normed,stretch,cmap)
end
function _imview(normed::AbstractArray{T}, stretch, cmap) where T
    if T <: Union{Missing,<:Number}
        TT = typeof(first(skipmissing(normed)))
    else
        TT = T
    end
    # minstep(::Type{T}) where {T<:AbstractFloat} = eps(T)
    # minstep(::Type{Bool}) = false
    # minstep(T) = one(T)
    # stretchmin = convert(TT, stretch(zero(TT)+minstep(TT)))
    # stretchmax = convert(TT, stretch(one(T)))
    stretchmin = 0
    stretchmax = 1
    # if T == Bool
    #     Tout = N0f8
    # else
        Tout = T
    # end

    # No color map
    if isnothing(cmap)
        f = scaleminmax(stretchmin, stretchmax)
        return mappedarray(normed) do pix
            if ismissing(pix)
                return Gray{TT}(0)
            else
                stretched = isfinite(pix) ? stretch(pix) : pix
                return Gray{TT}(f(stretched))
            end
        end
    # Monochromatic image using a colormap
    else
        cscheme = ColorSchemes.colorschemes[cmap]
        return mappedarray(normed) do pix
            stretched = !ismissing(pix) && isfinite(pix) ? stretch(pix) : pix
            # We treat NaN/missing values as transparent
            return if ismissing(stretched) || !isfinite(stretched)
                RGBA{TT}(0,0,0,0)
            # We treat Inf values as white / -Inf as black
        elseif isinf(stretched)
                if stretched > 0
                    RGBA{TT}(1,1,1,1)
                else
                    RGBA{TT}(0,0,0,1)
                end
            else
                RGBA{TT}(get(cscheme::ColorScheme, stretched, (stretchmin, stretchmax)))
            end
        end
    end

end
export imview

"""
    percent(99.5)

Returns a function that calculates display limits that include the given 
percent of the image data.

Example:
```julia
julia> imview(img, clims=percent(90))
```
This will set the limits to be the 5th percentile to the 95th percentile.
"""
function percent(perc::Number)
    trim = (1  - perc/100)/2
    clims(data) = quantile(data, (trim, 1-trim))
    clims(data::AbstractMatrix) = quantile(vec(data), (trim, 1-trim))
    return clims
end
export percent

# TODO: is this the correct function to extend?
# Instead of using a datatype like N0f32 to interpret integers as fixed point values in [0,1],
# we use a mappedarray to map the native data range (regardless of type) to [0,1]
Images.normedview(img::AstroImage{<:FixedPoint}) = img
function Images.normedview(img::AstroImage{T}) where T
    imgmin, imgmax = extrema(skipmissingnan(img))
    Δ = abs(imgmax - imgmin)
    Tout = _Float(T)
    normeddata = mappedarray(
        pix -> (pix - imgmin)/Δ,
        pix_norm -> convert(T, pix_norm*Δ + imgmin),
        img
    )
    return shareheaders(img, normeddata)
end
export normedview


function normedclampedview(img::AbstractArray{T}, lims) where T
    imgmin, imgmax = lims
    Δ = abs(imgmax - imgmin)
    normeddata = mappedarray(
        pix -> clamp((pix - imgmin)/Δ, 0, 1),
        pix_norm -> convert(T, pix_norm*Δ + imgmin),
        img
    )
    return maybe_shareheaders(img, normeddata)
end
function normedclampedview(img::AbstractArray{Bool}, lims)
    return img
end
export normedclampedview

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
