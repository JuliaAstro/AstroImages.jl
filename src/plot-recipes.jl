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
    wcs=true
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

        yguide, yticks = prepare_label_ticks(img, 2)
        yguide := yguide
        yticks := yticks

        xguide, xticks = prepare_label_ticks(img, 1)
        xguide := xguide
        xticks := xticks

    end

    # TODO: also disable equal aspect ratio if the scales are totally different
    aspect_ratio := :equal

    # We have to do a lot of flipping to keep the orientation corect 
    yflip := false
    return axes(img,2), axes(img,1), view(arraydata(img), reverse(axes(img,1)),:)
end


function prepare_label_ticks(img, axnum)

    if axnum == 1
        label = ctype_x(wcs(img))
    elseif axnum == 2
        label = ctype_y(wcs(img))
    else
        label = wcs(img).ctype[axnum]
    end
    if wcs(img).cunit[axnum] == "deg"
        if startswith(uppercase(wcs(img).ctype[axnum]), "RA")
            @info "using deg2hms"
            converter = deg2hms
            units = hms_units
        else
            @info "using deg2dms"
            converter = deg2dmsmμ
            units = dmsmμ_units
        end
    else
        converter = x->(x,)
        units = ("",)
    end

    # w denotes world coordinates along this axis; x denotes pixel coordinates.
    # wᵀ denotes world coordinates along the opposite axis.
    axnumᵀ = axnum == 1 ? 2 : 1

    # TODO: Is this really the x min and max? What if the image is rotated?
    # TODO: what about viewing a slice?
    # TODO: wrapped around axes...
    # Mabye we can detect this by comparing with the minpoint. If they're not monatonic,
    # there is a wrap around somewhere. But then what do we do...

    @info "axes" axnum axnumᵀ
    minx = first(axes(img,axnum))
    maxx = last(axes(img,axnum))
    minxᵀ = first(axes(img,axnumᵀ))
    maxxᵀ = last(axes(img,axnumᵀ))
    @info "pixel extrema" minx maxx minxᵀ maxxᵀ
    @show [axnum, axnumᵀ]

    w1, wᵀ1 = pix_to_world(wcs(img), Float64[minx, minxᵀ][[axnum, axnumᵀ]])[[axnum, axnumᵀ]]
    w2, wᵀ2 = pix_to_world(wcs(img), Float64[minx, maxxᵀ][[axnum, axnumᵀ]])[[axnum, axnumᵀ]]
    w3, wᵀ3 = pix_to_world(wcs(img), Float64[maxx, minxᵀ][[axnum, axnumᵀ]])[[axnum, axnumᵀ]]
    w4, wᵀ4 = pix_to_world(wcs(img), Float64[maxx, maxxᵀ][[axnum, axnumᵀ]])[[axnum, axnumᵀ]]
    # minw, maxw = extrema((w1,w2,w3,w4))
    # minwᵀ, maxwᵀ = extrema((wᵀ1,wᵀ2,wᵀ3,wᵀ4))
    # @show w1 w2 w3 w4
    minw, maxw = extrema((w1,w3))
    minwᵀ, maxwᵀ = extrema((wᵀ1,wᵀ3))
    @info "world extrema" w1 w2 w3 w4 wᵀ1 wᵀ2 wᵀ3 wᵀ4 minw maxw
    # @show w1 w3 wᵀ3 wᵀ3

    # TODO: May need to rethink this approach in light of coordinates that can wrap around
    # Perhaps we can instead choose a phyically relevant step size

    # Use PlotUtils.optimize_ticks to find good tick positions in world coordinates
    Q=[(1.0,1.0), (2.0, 0.7), (5.0, 0.5), (3.0, 0.2)]
    tickpos_w = optimize_ticks(minw*6, maxw*6; Q, k_min=3, k_ideal=6)[1]
    if w1 > w3
        tickpos_w = reverse(tickpos_w)
    end
    # Then convert back to pixel coordinates along the axis
    tickpos = map(tickpos_w) do w
        # TODO: naxis, slices
        x = world_to_pix(wcs(img), Float64[w/6, minwᵀ, 0][[axnum,axnumᵀ,3]])[axnum]
        return x
    end


    # tickpos_w = optimize_ticks(minw*60*60, maxw*60*60; k_min=6, k_ideal=6)[1]
    # @show tickpos_w
    # phys_tick_spacing = mean(diff(tickpos_w))/60/60
    # @show phys_tick_spacing
    # pix_spacing = abs(
    #     world_to_pix(wcs(img), Float64[minw+phys_tick_spacing, minwᵀ, 0][[axnum,axnumᵀ,3]])[axnum] - 
    #     world_to_pix(wcs(img), Float64[minw, minwᵀ, 0][[axnum,axnumᵀ,3]])[axnum]

    # )
    # @show pix_spacing

    # Q = [
    #     (1.0, 1.0),
    #     (pix_spacing,   0.9),
    #     (pix_spacing/2, 0.8),
    #     (pix_spacing/3, 0.7),
    #     (pix_spacing/5, 0.6),
    # ]
    # tickpos = optimize_ticks(minx, maxx; Q, k_min=6, k_ideal=6)[1]

    # Format inital ticklabel 
    ticklabels = fill("", length(tickpos))
    # We only include the part of the label that has changed since the last time.
    # Split up coordinates into e.g. sexagesimal
    parts = map(tickpos) do x
        # TODO: naxis
        w = pix_to_world(wcs(img), Float64[x, minxᵀ, 0][[axnum,axnumᵀ,3]])[axnum]
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

    # deubg override:
    # zero_coords_i = length(last_coord)

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
            return str * unit
        end

        last_coord = vals
    end
    @show ticklabels

    return label, (tickpos, ticklabels)

end


# # We need  a function that takes a WCSTransform, axis number, and physical coordinate start annd stop
# # And returns (if units are degrees):
# # * Starting position in sexagesimal (truncated to show static parts)
# # * formatter in sexagesimal (truncated to show changing parts)
# function prepare_formatter(w::WCSTransform, axnum, xmin, xmax, len)

#     if axnum == 1
#         label = ctype_x(w)
#         converter = deg2hms
#         units = hms_units
#     elseif axnum == 2
#         label = ctype_y(w)
#         converter = deg2dmsmμ
#         units = dmsmμ_units
#     else
#         label = w.ctype[axnum]
#         converter = deg2dmsmμ
#         units = dmsmμ_units
#     end

#     if w.cunit[axnum] != "deg"
#         formatter = string
#     else
#         diff = converter(xmax) .- converter(xmin)
#         changing_coord_i = findfirst(d->abs(d)>0, diff)

#         start = vcat(
#             converter(xmin)[1:changing_coord_i-1]...,
#             zeros(length(units)-changing_coord_i+1)...
#         )

#         # Add the starting coordinate to the label.
#         # These are the components that are the same for every tick
#         label *= "  " * mapreduce(*, zip(start,units[1:changing_coord_i-1])) do (val,unit)
#             @sprintf("%d%s", val, unit)
#         end * "+"

#         # TODO: also need a tick positioner??? Ottherwise the ticks aren'tt properly posjtions

#         formatter = function (x)
#             # TODO: pixels are already in physical coordinates...
#             # This seems like not a good assumption
#             # res = x
#             # Todo, both x? Doesn't seem right
#             # res = pix_to_world(w, [float(x), float(x)])[axnum]
#             if axnum ==1
#                 res = pix_to_world(w, [float(x), float(zero(x))])[axnum]
#             else
#                 res = pix_to_world(w, [float(zero(x)), float(x)])[axnum]
#             end

#             vals = converter(res) .- start
#             if changing_coord_i < length(units)
#                 ticklabel = "  " * mapreduce(*, zip(vals[changing_coord_i:min(changing_coord_i+1,end)],units[changing_coord_i:min(changing_coord_i+1,end)])) do (val,unit)
#                     @sprintf("%d%s", val, unit)
#                 end
#             else
#                 ticklabel = @sprintf(
#                     "%.2f%s",
#                     vals[changing_coord_i],
#                     units[changing_coord_i]
#                 )
#             end
#             return ticklabel
#         end
#     end
#     return label, formatter
# end

# # Extended form of deg2dms that further returns mas, microas.
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

# function deg2hmsmμ(deg)
#     h,m,s = deg2hms(deg)
#     s_f = floor(s)
#     mas = (s - s_f)*1e3
#     mas_f = floor(mas)
#     μas = (mas - mas_f)*1e3
#     return (h,m,s_f,mas_f,μas)
# end
# const hmsmμ_units = [
#     "ʰ",
#     "ᵐ",
#     "ˢ",
#     # "mas",
#     # "μas",
# ]
const hms_units = [
    "ʰ",
    "ᵐ",
    "ˢ",
]







# function pix2world_xformatter(x, wcs::WCSTransform)
#     res = round(pix_to_world(wcs, [float(x), float(x)])[1][1], digits=2)
#     return string(res, unit2sym(wcs.cunit[1]))
# end
# function pix2world_xformatter(x, wcs::WCSTransform, start)
#     x = pix_to_world(wcs, [float(x), float(x)])[1][1]

#     pm = sign(start - x) >= 0 ? '+' : '-'

#     diff_x_d, diff_x_m, diff_x_s = deg2dms(x) .- deg2dms(start)

#     if abs(diff_x_d) > 1
#         return string(pm, abs(round(Int, diff_x_d)), unit2sym("deg"))
#     elseif abs(diff_x_m) > 1
#         @show diff_x_m
#         return string(pm, abs(round(Int, diff_x_m)), unit2sym("am"))
#     elseif abs(diff_x_s) > 1
#         return string(pm, abs(round(Int, diff_x_s)), unit2sym("as"))
#     elseif abs(diff_x_s) > 1e-3
#         return string(pm, abs(round(Int, diff_x_s*1e3)), unit2sym("mas"))
#     elseif abs(diff_x_s) > 1e-6
#         return string(pm, abs(round(Int, diff_x_s*1e3)), unit2sym("μas"))
#     else
#         return string(pm, abs(diff_x_s), unit2sym("as"))
#     end
        


#     # return string(pm, diff_x_d, diff_x_m, diff_x_s, unit2sym(tickunit))
#     return string(pm, abs(round(Int, diff_x_s)), unit2sym(tickunit))
# end

# function pix2world_yformatter(y, wcs::WCSTransform)
#     res = round(pix_to_world(wcs, [float(y), float(y)])[2][1], digits=2)
#     return string(res, unit2sym(wcs.cunit[1]))
# end
# function pix2world_yformatter(y, wcs::WCSTransform, start, tickdiv, tickunit)
#     y = pix_to_world(wcs, [float(y), float(y)])[2][1]
#     pm = sign(res) >= 0 ? '+' : '-'
#     return string(pm, abs(round(res,digits=2)), unit2sym(tickunit))
# end


# labler_x(wcs) = ctype_x(wcs)
# labler_y(wcs) = ctype_y(wcs)

# labler_x(wcs, start) = string(ctype_x(wcs), "  ", start, unit2sym(wcs.cunit[1]))
# labler_y(wcs, start) = string(ctype_y(wcs), "  ", start, unit2sym(wcs.cunit[2]))

# function unit2sym(unit)
#     if unit == "deg"       # TODO: add symbols for more units
#         "°"
#     elseif unit == "am"       # TODO: add symbols for more units
#         "'"
#     elseif unit == "as"       # TODO: add symbols for more units
#         "\""
#     else
#         string(unit)
#     end
# end

# function nextunit(div, unit)
#     if unit == "deg"       # TODO: add symbols for more units
#         return div*60, "am"
#     elseif unit == "am"       # TODO: add symbols for more units
#         return div*60, "as"
#     elseif unit == "as"       # TODO: add symbols for more units
#         return div*60, "mas"
#     else
#         div, string(unit)
#     end
# end


function ctype_x(wcs::WCSTransform)
    if length(wcs.ctype[1]) == 0
        return wcs.radesys
    elseif wcs.ctype[1][1:2] == "RA"
        return "Right Ascension (ICRS)"
    elseif wcs.ctype[1][1:4] == "GLON"
        return "Galactic Longitude"
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
        return "Galactic Latitude"
    elseif wcs.ctype[2][1:4] == "TLAT"
        return "ITRS"
    else
        return wcs.ctype[2]
    end
end
