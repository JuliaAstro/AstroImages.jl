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
    clims(data) = quantile(data, (trim, 1-trim))
    clims(data::AbstractMatrix) = quantile(vec(data), (trim, 1-trim))
    return clims
end

const _default_cmap  = Ref{Union{Symbol,Nothing}}(nothing)
const _default_clims = Ref{Any}(percent(99.5))
const _default_stretch  = Ref{Any}(identity)

"""
    set_cmap!(cmap::Symbol)
    set_cmap!(cmap::Nothing)

Alter the default color map used to display images when using
`imview` or displaying an AstroImage.
"""
function set_cmap!(cmap)
    if cmap ∉ keys(ColorSchemes.colorschemes)
        throw(KeyError("$cmap not found in ColorSchemes.colorschemes"))
    end
    _default_cmap[] = cmap
end
"""
    set_clims!(clims::Tuple)
    set_clims!(clims::Function)

Alter the default limits used to display images when using
`imview` or displaying an AstroImage.
"""
function set_clims!(clims)
    _default_clims[] = clims
end
"""
    set_stretch!(stretch::Function)

Alter the default value stretch functio used to display images when using
`imview` or displaying an AstroImage.
"""
function set_stretch!(stretch)
    _default_stretch[] = stretch
end



"""
Helper to iterate over data skipping missing and non-finite values.
""" 
skipmissingnan(itr) = Iterators.filter(el->!ismissing(el) && isfinite(el), itr)

"""
    imview(img; clims=extrema, stretch=identity, cmap=nothing)

Create a read only view of an array or AstroImage mapping its data values
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
Arrays wrapped by `AstroImage()` get displayed as images automatically by calling 
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

    # TODO: catch this in `show` instead of here.
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
    return _imview(img, normed, stretch, cmap)
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
    img_no = OffsetArrays.no_offset_view(img)
    normed_no = OffsetArrays.no_offset_view(normed)
    mapper = mappedarray(img_no, normed_no) do pixr, pixn
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
    # return maybe_copyheaders(img, flipped_view)
    # return maybe_copyheaders(img, mapper)

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

    return maybe_copyheaders(img, OffsetArray(flipped_view, axes(img,2), axes(img,1)))
end



# TODO: is this the correct function to extend?
# Instead of using a datatype like N0f32 to interpret integers as fixed point values in [0,1],
# we use a mappedarray to map the native data range (regardless of type) to [0,1]
Images.normedview(img::AstroImage{<:FixedPoint}) = img
function Images.normedview(img::AstroImage{T}) where T
    imgmin, imgmax = extrema(skipmissingnan(img))
    Δ = abs(imgmax - imgmin)
    normeddata = mappedarray(
        pix -> (pix - imgmin)/Δ,
        pix_norm -> convert(T, pix_norm*Δ + imgmin),
        img
    )
    return shareheaders(img, normeddata)
end

"""
    clampednormedview(arr, (min, max))

Given an AbstractArray and limits `min,max` return a view of the array
where data between [min, max] are scaled to [0, 1] and datat outside that
range are clamped to [0, 1].

See also: normedview
"""
function clampednormedview(img::AbstractArray{T}, lims) where T
    imgmin, imgmax = lims
    Δ = abs(imgmax - imgmin)
    normeddata = mappedarray(
        pix -> clamp((pix - imgmin)/Δ, zero(T), one(T)),
        pix_norm -> convert(T, pix_norm*Δ + imgmin),
        img
    )
    return maybe_shareheaders(img, normeddata)
end
function clampednormedview(img::AbstractArray{T}, lims) where T <: Normed
    # If the data is in a Normed type and the limits are [0,1] then
    # it already lies in that range.
    if lims[1] == 0 && lims[2] == 1
        return img
    end
    imgmin, imgmax = lims
    Δ = abs(imgmax - imgmin)
    normeddata = mappedarray(
        pix -> clamp((pix - imgmin)/Δ, zero(T), one(T)),
        pix_norm -> pix_norm*Δ + imgmin,
        img
    )
    return maybe_shareheaders(img, normeddata)
end
function clampednormedview(img::AbstractArray{Bool}, lims)
    return img
end