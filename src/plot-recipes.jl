using RecipesBase
using AstroAngles
using Printf
using PlotUtils: optimize_ticks

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
# This recipe promotes AstroImages of numerical data into full color using
# imview().
@recipe function f(
    img::AstroImage{T};
    clims=_default_clims[],
    stretch=_default_stretch[],
    cmap=_default_cmap[],
    wcs=AstroImages.wcs(img)
) where {T<:Number}
    # We currently use the AstroImages defaults. If unset, we could
    # instead follow the plot theme.
    iv = imview(img; clims, stretch, cmap)
    return iv
end

# TODO: the wcs parameter is not getting forwardded correctly. Use plot recipe system for this.

# This recipe plots as AstroImage of color data as an image series (not heatmap).
# This lets us also plot color composites e.g. in WCS coordinates.
@recipe function f(
    img::AstroImage{T};
    wcs=AstroImages.wcs(img)
) where {T<:Colorant}

    # By default, disable the colorbar.
    # Plots.jl does no give us sufficient control to make sure the range and ticks
    # are correct after applying a non-linear stretch
    # colorbar := false

    # we have a wcs flag (from the image by default) so that users can skip over 
    # plotting in physical coordinates. This is especially important
    # if the WCS headers are mallformed in some way.
    if !isnothing(wcs)

        # TODO: fill out coordinates array considering offset indices and slices
        # out of cubes (tricky!)
        
        xguide, xticks = prepare_label_ticks(img, 1, ones(wcs.naxis))
        xguide := xguide
        xticks := xticks

        yguide, yticks = prepare_label_ticks(img, 2, ones(wcs.naxis))
        yguide := yguide
        yticks := yticks
    end

    # TODO: also disable equal aspect ratio if the scales are totally different
    # aspect_ratio := :equal

    # We have to do a lot of flipping to keep the orientation corect 
    yflip := false
    # return axes(img,2), axes(img,1), view(arraydata(img), reverse(axes(img,1)),:)
    xflip := false
    return axes(img,2), axes(img,1), view(arraydata(img), reverse(axes(img,1)),:)
end


"""
Calculate good tick positions and nice labels for them

INPUT
img:    an AstroImage
axnum:  the index of the axis we want ticks for
axnumᵀ: the index of the axis we are plotting against
coords: the position in all coordinates for this plot. The value a axnum and axnumᵀ is igored.

`coords` is important for showing 2D coords of a 3+D cube as we need to know
our position along the other axes for accurate tick positions.

OUTPUT
tickpos: tick positions in pixels for this axis
ticklabels: tick labels for each position
"""
function prepare_label_ticks(img, axnum, coords)

    naxis = wcs(img).naxis
    coordsx = convert(Vector{Float64}, coords)

    # coordsw = zeros(eltype(coordsx), size(coordsx))
    coordsw = pix_to_world(wcs(img), coordsx)


    label = ctype_label(wcs(img).ctype[axnum], wcs(img).radesys)

    if wcs(img).cunit[axnum] == "deg"
        if startswith(uppercase(wcs(img).ctype[axnum]), "RA")
            converter = deg2hms
            units = hms_units
        else
            converter = deg2dmsmμ
            units = dmsmμ_units
        end
    else
        converter = x->(x,)
        units = ("",)
    end

    # w denotes world coordinates along this axis; x denotes pixel coordinates.
    # wᵀ denotes world coordinates along the opposite axis.

    # TODO: wrapped around axes...
    # Mabye we can detect this by comparing with the minpoint. If they're not monatonic,
    # there is a wrap around somewhere. But then what do we do...

    minx = first(axes(img,axnum))
    maxx = last(axes(img,axnum))

    posx = copy(coordsx)
    posx[axnum] = minx
    w1 = pix_to_world(wcs(img), posx)[axnum]
    posx[axnum] = maxx
    w3 = pix_to_world(wcs(img), posx)[axnum]
    minw, maxw = extrema((w1,w3))

    # TODO: May need to rethink this approach in light of coordinates that can wrap around
    # Perhaps we can instead choose a phyically relevant step size

    # Use PlotUtils.optimize_ticks to find good tick positions in world coordinates
    Q=[(1.0,1.0), (3.0, 0.8), (2.0, 0.7), (5.0, 0.5)]
    tickpos_w = optimize_ticks(minw*6, maxw*6; Q, k_min=3, k_ideal=6)[1]
    if w1 > w3
        tickpos_w = reverse(tickpos_w)
    end

    # Then convert back to pixel coordinates along the axis
    tickpos = map(tickpos_w) do w
        posw = copy(coordsw)
        posw[axnum] = w/6
        # pos[axnumᵀ] = minwᵀ # TODO: should this instead be wᵀ1?
        x = world_to_pix(wcs(img), posw)[axnum]
        return x
    end

    # Format inital ticklabel 
    ticklabels = fill("", length(tickpos))
    # We only include the part of the label that has changed since the last time.
    # Split up coordinates into e.g. sexagesimal
    parts = map(tickpos) do x
        posx = copy(coordsx)
        posx[axnum] = x
        # pos[axnumᵀ] = minxᵀ
        w = pix_to_world(wcs(img), posx)[axnum]
        vals = converter(w)
        return vals
    end

    # Start with something impossible of the same size:
    last_coord = Inf .* converter(minw)
    zero_coords_i = maximum(map(parts) do vals
        changing_coord_i = findfirst(vals .!= last_coord)
        last_coord = vals
        return changing_coord_i
    end)

    # Loop through using only the relevant part of the label
    # Start with something impossible of the same size:
    last_coord = Inf .* converter(minw)
    for (i,vals) in enumerate(parts)
        changing_coord_i = findfirst(vals .!= last_coord)
 
        val_unit_zip = zip(vals[changing_coord_i:zero_coords_i],units[changing_coord_i:zero_coords_i])
        ticklabels[i] = mapreduce(*, enumerate(val_unit_zip)) do (coord_i,(val,unit))
            # Last coordinate always gets decimal places
            # if coord_i == zero_coords_i && zero_coords_i == length(vals)
            if coord_i + changing_coord_i - 1== length(vals)
                str = @sprintf("%.2f", val)
                while endswith(str, r"0|\.")
                    str = chop(str)
                end
            else
                str = @sprintf("%d", val)
            end
            if length(str) > 0
                return str * unit
            else
                return str
            end
        end

        last_coord = vals
    end

    return label, (tickpos, ticklabels)

end


# Extended form of deg2dms that further returns mas, microas.
function deg2dmsmμ(deg)
    d,m,s = deg2dms(deg)
    s_f = floor(s)
    mas = (s - s_f)*1e3
    mas_f = floor(mas)
    μas = (mas - mas_f)*1e3
    return (d,m,s_f,mas_f,μas)
end
const dmsmμ_units = [
    "°",
    "'",
    "\"",
    "mas",
    "μas",
]
const hms_units = [
    "ʰ",
    "ᵐ",
    "ˢ",
]

function ctype_label(ctype,radesys)
    if length(ctype) == 0
        return radesys
    elseif startswith(ctype, "RA")
        return "Right Ascension ($(radesys))"
    elseif startswith(ctype, "GLON")
        return "Galactic Longitude"
    elseif startswith(ctype, "TLON")
        return "ITRS"
    elseif startswith(ctype, "DEC")
        return "Declination ($(radesys))"
    elseif startswith(ctype, "GLAT")
        return "Galactic Latitude"
    elseif startswith(ctype, "TLAT")
    else
        return ctype
    end
end
