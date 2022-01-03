using RecipesBase

using AstroAngles

"""
    plot(img::AstroImage; clims=extrema, stretch=identity, cmap=nothing)

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
@recipe function f(
        img::AstroImage{T};
        clims=_default_clims[],
        stretch=_default_stretch[],
        cmap=_default_cmap[],
        wcs=true
    ) where T
    seriestype   := :heatmap
    aspect_ratio := :equal

    if isnothing(cmap)
        cmap = :grays
    end
    color        := cmap


    # TODO: apply same `restrict` logic as in Images.jl to downsize
    # very large images.

    # We use the same pipeline as imview: normalize the image data according to clims
    # then stretch, then plot in the new stretched range

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

    img_flipped = img[end:-1:begin,:]

    normed = clampednormedview(img_flipped, (imgmin, imgmax))

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
    mapper = mappedarray(img_flipped, normed) do pixr, pixn
        if ismissing(pixr) || !isfinite(pixr) || ismissing(pixn) || !isfinite(pixn)
            # We check pixr in addition to pixn because we want to preserve if the pixels
            # are +-Inf
            stretched = pixr
        else
            stretched = stretch(pixn)
        end
    end

    # The output range may not be [0,1] depending on the stretch function
    clims := (stretchmin,stretchmax)

    # Calculate tick labels for the colorbar.
    # These may not have linear spacing depending on stretch function.
    # We can't know the inverse of the user's stretch function in general, so we have to
    # map in the forwards direction.
    # cbticklabels = range(
    #     imgmin,
    #     imgmax,
    #     length=9
    # )
    # cbtickpos = stretch.(cbticklabels)

    # By default, disable the colorbar.
    # Plots.jl does no give us sufficient control to make sure the range and ticks
    # are correct after applying a non-linear stretch
    colorbar := false

    # we have a wcs flag (true by default) so that users can skip over 
    # plotting in physical coordinates. This is especially important
    # if the WCS headers are mallformed in some way.
    if wcs

        # We want to avoid having the same coordinate repeated many times 
        # in narrow fields of view (e.g. 150.1, 150.1, 150.1).
        # We attempt to decect this and switch to a coordinate + Δ format
        w = AstroImages.wcs(img)

        # TODO: Is this really the x min and max? What if the image is rotated?
        x1, y1 = pix_to_world(w, [float(minimum(axes(img,1))), float(minimum(axes(img,2)))])
        x2, y2 = pix_to_world(w, [float(maximum(axes(img,1))), float(maximum(axes(img,2)))])
        # Image indices will often be reversed vs. the physical coordinates
        xmin, xmax = minmax(x1,x2)
        ymin, ymax = minmax(y1,y2)

        # X
        if xmax - xmin < 1
            start_x = xmin
            start_x_d, start_x_m, start_x_s = deg2dms(xmin)
            diff_x_d, diff_x_m, diff_x_s = deg2dms(xmax) .- deg2dms(xmin)
            xunit = w.cunit[1]
            tickdiv, tickunit = 1.0, xunit
            # Determine which coordinates to use along the axis.
            @show start_x
            start_x = floor(start_x_d)
            @show start_x
            if diff_x_d <= 1 
                start_x = dms2deg(start_x_d, start_x_m, 0)
            @show start_x
            tickdiv, tickunit = nextunit(tickdiv, tickunit)
            end
            if diff_x_m <= 1
                start_x = dms2deg(start_x_d, start_x_m, ceil(diff_x_m))
            @show start_x
            tickdiv, tickunit = nextunit(tickdiv, tickunit)
            end

            # TODO: adaptive unit switching
            xlabel       := labler_x(w, (start_x_d, start_x_m, start_x_s))

            # tickdiv, tickunit = nextunit(w.cunit[1])
            xformatter   := x -> pix2world_xformatter(x, w, start_x)
        else
            xformatter   := x -> pix2world_xformatter(x, w)
            xlabel       := labler_x(w)
        end

        # # Y
        # if ymax - ymin < 1
        #     # Switch to Δ labeling

        #     # TODO: adaptive unit switching
        #     starty = round(ymin, RoundToZero, digits=0)
        #     ylabel       := labler_y(w, starty)

        #     tickdiv, tickunit = nextunit(w.cunit[2])
        #     yformatter   := y -> pix2world_yformatter(y, w, starty, tickdiv, tickunit)
        # else
            yformatter   := y -> pix2world_yformatter(y, w)
            ylabel       := labler_y(w)
        # end
        
        # TODO: also disable equal aspect ratio if the scales are totally different
    end

    return mapper
end

function pix2world_xformatter(x, wcs::WCSTransform)
    res = round(pix_to_world(wcs, [float(x), float(x)])[1][1], digits=2)
    return string(res, unit2sym(wcs.cunit[1]))
end
function pix2world_xformatter(x, wcs::WCSTransform, start)
    x = pix_to_world(wcs, [float(x), float(x)])[1][1]

    pm = sign(start - x) >= 0 ? '+' : '-'


    @show start x
    diff_x_d, diff_x_m, diff_x_s = deg2dms(x) .- deg2dms(start)
    @show diff_x_d diff_x_m diff_x_s

    if abs(diff_x_d) > 1
        return string(pm, abs(round(Int, diff_x_d)), unit2sym("deg"))
    elseif abs(diff_x_m) > 1
        @show diff_x_m
        return string(pm, abs(round(Int, diff_x_m)), unit2sym("am"))
    elseif abs(diff_x_s) > 1
        return string(pm, abs(round(Int, diff_x_s)), unit2sym("as"))
    elseif abs(diff_x_s) > 1e-3
        return string(pm, abs(round(Int, diff_x_s*1e3)), unit2sym("mas"))
    elseif abs(diff_x_s) > 1e-6
        return string(pm, abs(round(Int, diff_x_s*1e3)), unit2sym("μas"))
    else
        return string(pm, abs(diff_x_s), unit2sym("as"))
    end
        


    # return string(pm, diff_x_d, diff_x_m, diff_x_s, unit2sym(tickunit))
    return string(pm, abs(round(Int, diff_x_s)), unit2sym(tickunit))
end

function pix2world_yformatter(y, wcs::WCSTransform)
    res = round(pix_to_world(wcs, [float(y), float(y)])[2][1], digits=2)
    return string(res, unit2sym(wcs.cunit[1]))
end
function pix2world_yformatter(y, wcs::WCSTransform, start, tickdiv, tickunit)
    y = pix_to_world(wcs, [float(y), float(y)])[2][1]
    pm = sign(res) >= 0 ? '+' : '-'
    return string(pm, abs(round(res,digits=2)), unit2sym(tickunit))
end


labler_x(wcs) = ctype_x(wcs)
labler_y(wcs) = ctype_y(wcs)

labler_x(wcs, start) = string(ctype_x(wcs), "  ", start, unit2sym(wcs.cunit[1]))
labler_y(wcs, start) = string(ctype_y(wcs), "  ", start, unit2sym(wcs.cunit[2]))

function unit2sym(unit)
    if unit == "deg"       # TODO: add symbols for more units
        "°"
    elseif unit == "am"       # TODO: add symbols for more units
        "'"
    elseif unit == "as"       # TODO: add symbols for more units
        "\""
    else
        string(unit)
    end
end

function nextunit(div, unit)
    if unit == "deg"       # TODO: add symbols for more units
        return div*60, "am"
    elseif unit == "am"       # TODO: add symbols for more units
        return div*60, "as"
    elseif unit == "as"       # TODO: add symbols for more units
        return div*60, "mas"
    else
        div, string(unit)
    end
end


function ctype_x(wcs::WCSTransform)
    if length(wcs.ctype[1]) == 0
        return wcs.radesys
    elseif wcs.ctype[1][1:2] == "RA"
        return "Right Ascension (ICRS)"
    elseif wcs.ctype[1][1:4] == "GLON"
        return "Galactic Coordinate"
    elseif wcs.ctype[1][1:4] == "TLON"
        return "ITRS"
    else
        return wcs.ctype[1]
    end
end

function ctype_y(wcs::WCSTransform)
    if length(wcs.ctype[2]) == 0
        return wcs.radesys
    elseif wcs.ctype[2][1:3] == "DEC"
        return "Declination (ICRS)"
    elseif wcs.ctype[2][1:4] == "GLAT"
        return "Galactic Coordinate"
    elseif wcs.ctype[2][1:4] == "TLAT"
        return "ITRS"
    else
        return wcs.ctype[2]
    end
end
