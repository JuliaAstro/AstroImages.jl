# These reproduce the behaviour of DS9 according to http://ds9.si.edu/doc/ref/how.html
logstretch(x,a=1000) = log(a*x+1)/log(a)
powstretch(x,a=1000) = (a^x - 1)/a
sqrtstretch = sqrt
squarestretch(x) = x^2
asinhstretch(x) = asinh(10x)/3
sinhstretch(x) = sinh(3x)/10
# These additional stretches reproduce behaviour from astropy
powerdiststretch(x, a=1000) = (a^x - 1) / (a - 1)

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
    clims(data::AbstractVector) = quantile(data, (trim, 1-trim))
    clims(data::AbstractArray) = clims(vec(data))
    return clims
end

const _default_cmap  = Base.RefValue{Union{Symbol,Nothing}}(:magma)#nothing)
const _default_clims = Base.RefValue{Any}(percent(99.5))
const _default_stretch  = Base.RefValue{Any}(identity)

"""
    set_cmap!(cmap::Symbol)
    set_cmap!(cmap::Nothing)

Alter the default color map used to display images when using
`imview` or displaying an AstroImageMat.
"""
function set_cmap!(cmap)
    _default_cmap[] = _lookup_cmap(cmap)
end
"""
    set_clims!(clims::Tuple)
    set_clims!(clims::Function)

Alter the default limits used to display images when using
`imview` or displaying an AstroImageMat.
"""
function set_clims!(clims)
    _default_clims[] = clims
end
"""
    set_stretch!(stretch::Function)

Alter the default value stretch functio used to display images when using
`imview` or displaying an AstroImageMat.
"""
function set_stretch!(stretch)
    _default_stretch[] = stretch
end



"""
Helper to iterate over data skipping missing and non-finite values.
""" 
skipmissingnan(itr) = Iterators.filter(el->!ismissing(el) && isfinite(el), itr)


function _lookup_cmap(cmap)
    if cmap ∉ keys(ColorSchemes.colorschemes)
        error("$cmap not found in ColorSchemes.colorschemes. See: https://juliagraphics.github.io/ColorSchemes.jl/stable/catalogue/")
    end
    return cmap
end
_lookup_cmap(cmap::Nothing) = nothing

function _resolve_clims(img, clims)
    # Tuple or abstract array
    if typeof(clims) <: AbstractArray || typeof(clims) <: Tuple
        if length(clims) != 2
            error("clims must have exactly two values if provided.")
        end
        imgmin = first(clims)
        imgmax = last(clims)
    # Or as a callable that computes them given an iterator
    else
        imgmin, imgmax = clims(skipmissingnan(img))
    end
    return imgmin, imgmax
end


"""
    imview(img; clims=extrema, stretch=identity, cmap=nothing)

Create a read only view of an array or AstroImageMat mapping its data values
to Colors according to `clims`, `stretch`, and `cmap`.

The data is first clamped to `clims`, which can either be a tuple of (min, max)
values or a function accepting an iterator of pixel values that returns (min, max).
By default, `clims=extrema` i.e. the minimum and maximum of `img`.
Convenient functions to use for `clims` are:
`extrema`, `zscale`, and `percent(p)`

Next, the data is rescaled to [0,1] and remapped according to the function `stretch`.
Stretch can be any monotonic fuction mapping values in the range [0,1] to some range [a,b].
Note that `log(0)` is not defined so is not directly supported.
For a list of convenient stretch functions, see:
`logstretch`, `powstretch`, `squarestretch`, `asinhstretch`, `sinhstretch`, `powerdiststretch`

Finally the data is mapped to RGB values according to `cmap`. If cmap is `nothing`,
grayscale is used. ColorSchemes.jl defines hundreds of colormaps. A few nice ones for
images include: `:viridis`, `:magma`, `:plasma`, `:thermal`, and `:turbo`.

Crucially, this function returns a view over the underlying data. If `img` is updated
then those changes will be reflected by this view with the exception of `clims` which
is not recalculated.

Note: if clims or stretch is a function, the pixel values passed in are first filtered
to remove non-finite or missing values.

### Defaults
The default values of `clims`, `stretch`, and `cmap` are `extrema`, `identity`, and `nothing`
respectively.
You may alter these defaults using `AstroImages.set_clims!`,  `AstroImages.set_stretch!`, and
`AstroImages.set_cmap!`.

### Automatic Display
Arrays wrapped by `AstroImageMat()` get displayed as images automatically by calling 
`imview` on them with the default settings when using displays that support showing PNG images.

### Missing data
Pixels that are `NaN` or `missing` will be displayed as transparent when `cmap` is set
or black if.
+/- Inf will be displayed as black or white respectively.

### Exporting Images
The view returned by `imview` can be saved using general `FileIO.save` methods.
Example:
```julia
v = imview(data, cmap=:magma, stretch=asinhstretch, clims=percent(95))
save("output.png", v)
```
"""
function imview(
    img::AbstractMatrix{T};
    clims=_default_clims[],
    stretch=_default_stretch[],
    cmap=_default_cmap[],
) where {T}

    isempt = isempty(img)
    if isempt
        @warn "imview called with empty argument"
        return fill(RGBA{N0f8}(0,0,0,0), 1,1)
    end
    # Users will occaisionally pass in data that is 0D, filled with NaN, or filled with missing.
    # We still need to do something reasonable in those caes.
    nonempty = any(x-> !ismissing(x) && isfinite(x), img)
    if !nonempty
        @warn "imview called with all missing or non-finite values"
        return map(px->RGBA{N0f8}(0,0,0,0), img)
    end

    # TODO: Images.jl has logic to downsize huge images before displaying them.
    # We should use that here before applying all this processing instead of
    # letting Images.jl handle it after.

    # Users can pass clims as an array or tuple containing the minimum and maximum values
    if typeof(clims) <: AbstractArray || typeof(clims) <: Tuple
        if length(clims) != 2
            error("clims must have exactly two values if provided.")
        end
        imgmin = first(clims)
        imgmax = last(clims)
    # Or as a callable that computes them given an iterator
    else
        imgmin, imgmax = clims(skipmissingnan(img))
    end
    normed = clampednormedview(img, (imgmin, imgmax))
    return _imview(img, normed, stretch, _lookup_cmap(cmap))
end
# Special handling for complex images
"""
    imview(img::AbstractArray{<:Complex}; ...)

When applied to an image with complex values, display the magnitude
of the pixels using `imview` and display the phase angle as a panel below
using a cyclical color map.
For more customatization, you can create a view like this yourself:
```julia
vcat(
    imview(abs.(img)),
    imview(angle.(img)),
)
```
"""
function imview(img::AbstractMatrix{T}; kwargs...) where {T<:Complex}
    
    mag_view = imview(abs.(img); kwargs...)
    angle_view = imview(angle.(img), clims=(-pi, pi), cmap=:cyclic_mygbm_30_95_c78_n256_s25)
    vcat(mag_view,angle_view)
end

function _imview(img, normed::AbstractArray{T}, stretch, cmap) where T
    
    if T <: Union{Missing,<:Number}
        TT = typeof(first(skipmissing(normed)))
    else
        TT = T
    end
    if TT == Bool
        TT = N0f8
    end

    stretchmin = stretch(zero(TT))
    stretchmax = stretch(one(TT))

    # Peviously no colormap would fall back to Gray, but
    # it's simpler to keep a single codepath and use the :grays 
    # color scheme.
    if isnothing(cmap)
        cmap = :grays
    end
    cscheme = ColorSchemes.colorschemes[cmap]
    mapper = mappedarray(img, normed) do pixr, pixn
        if ismissing(pixr) || !isfinite(pixr) || ismissing(pixn) || !isfinite(pixn)
            # We check pixr in addition to pixn because we want to preserve if the pixels
            # are +-Inf
            stretched = pixr
        else
            stretched = stretch(pixn)
        end
        # We treat NaN/missing values as transparent
        return if ismissing(stretched) || isnan(stretched)
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

    # Flip image to match conventions of other programs
    # flipped_view = view(mapper', reverse(axes(mapper,2)),:)
    # return maybe_copyheader(img, flipped_view)
    # return maybe_copyheader(img, mapper)

    # flipped_view = OffsetArray(
    #     view(
    #         mapper',
    #         reverse(axes(mapper,1)),
    #         :,
    #     ),
    #     axes(img)...
    # )
    flipped_view = view(
        mapper',
        reverse(axes(mapper,2)),
        :,
    )

    return maybe_copyheader(img, flipped_view)
end


"""
    imview_colorbar(img; orientation=:vertical)
Create a colorbar for a given image matching how it is displayed by 
`imview`. Returns an image.

`orientation` can be `:vertical` or `:horizontal`.
"""
function imview_colorbar(
    img::AbstractMatrix;
    orientation=:vertical,
    clims=_default_clims[],
    stretch=_default_stretch[],
    cmap=_default_cmap[],
)
    imgmin, imgmax = _resolve_clims(img, clims)
    cbpixlen = 100
    data = repeat(range(imgmin, imgmax, length=cbpixlen), 1,10)
    if orientation == :vertical
        data = data'
    elseif orientation == :horizontal
        data = data
    else
        error("Unsupported orientation for colorbar \"$orientation\"")
    end

    # # Stretch the colors:
    # # Construct the image to use as a colorbar
    # cbimg =  imview(data; clims=(imgmin,imgmax), stretch, cmap)
    # # And the colorbar tick locations & labels
    # ticks, cbmin, cbmax = optimize_ticks(imgmin, imgmax)
    # # Now map these to pixel locations through streching and colorlimits:
    # stretchmin = stretch(zero(eltype(data)))
    # stretchmax = stretch(one(eltype(data)))
    # normedticks = clampednormedview(ticks, (imgmin, imgmax))
    # ticksloc = map(ticks,normedticks) do tick, tickn
    #     return cbpixlen * tickn
    # end

    # Strech the ticks
    # Construct the image to use as a colorbar
    cbimg = imview(data; clims=(imgmin,imgmax), stretch=identity, cmap)
    # And the colorbar tick locations & labels
    ticks, cbmin, cbmax = optimize_ticks(imgmin, imgmax)
    # Now map these to pixel locations through streching and colorlimits:
    stretchmin = stretch(zero(eltype(data)))
    stretchmax = stretch(one(eltype(data)))
    normedticks = clampednormedview(ticks, (imgmin, imgmax))
    ticksloc = map(ticks,normedticks) do tick, tickn
        stretched = stretch(tickn)
        stretchednormed = (stretched - stretchmin) * (stretchmax - stretchmin)
        return cbpixlen * stretchednormed
    end

    return cbimg, (ticksloc, string.(ticks))
end
