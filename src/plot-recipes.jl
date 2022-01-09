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
Stretch can be any monotonic function mapping values in the range [0,1] to some range [a,b].
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
) where {T<:Colorant}

    # By default, disable the colorbar.
    # Plots.jl does no give us sufficient control to make sure the range and ticks
    # are correct after applying a non-linear stretch
    # colorbar := false

    # we have a wcs flag (from the image by default) so that users can skip over 
    # plotting in physical coordinates. This is especially important
    # if the WCS headers are mallformed in some way.
    if !haskey(plotattributes, :wcs) || plotattributes[:wcs]

        # TODO: fill out coordinates array considering offset indices and slices
        # out of cubes (tricky!)

        # Note: if the axes are on unusual sides (e.g. y-axis at right, x-axis at top)
        # then these coordinates are not correct. They are only correct exactly
        # along the axis.
        # In astropy, the ticks are actually tilted to reflect this, though in general
        # the transformation from pixel to coordinates can be non-linear and curved.

        # (;tickpos1x, tickpos1w, tickpos2x, tickpos2w, ) 
        wcsg = WCSGrid(img, (1,2))

        gridspec = wcsgridspec(wcsg)
        
        # xticks --> (gridspec.tickpos1x, wcsticks(wcs(img), 1, gridspec))
        xticks --> wcsticks(wcsg, 1, gridspec)
        xguide --> ctype_label(wcs(img).ctype[1], wcs(img).radesys)

        # yticks --> (gridspec.tickpos2x, wcsticks(wcs(img), 2, gridspec))
        yticks --> wcsticks(wcsg, 2, gridspec)
        yguide --> ctype_label(wcs(img).ctype[2], wcs(img).radesys)

        # To ensure the physical axis tick labels are correct the axes must be
        # # tight to the image
        xlims := first(axes(img,2)), last(axes(img,2))
        ylims := first(axes(img,1)), last(axes(img,1))

        # The grid lines are likely to be confusing since they do not follow
        # the possibly tilted axes
        grid := false
        tickdirection := :none
    end

    # TODO: also disable equal aspect ratio if the scales are totally different
    # aspect_ratio := :equal

    # We have to do a lot of flipping to keep the orientation corect 
    yflip := false
    xflip := false

    return axes(img,2), axes(img,1), view(arraydata(img), reverse(axes(img,1)),:)
end


struct WCSGrid
    w
    extent
    ax
    coords
end
WCSGrid(w,extent,ax) = WCSGrid(w,extent,ax,ones(length(ax)))


"""
Generate nice labels from a WCSTransform, axis, and known positions.

INPUT
w:      a WCSTransform
axnum:  the index of the axis we want ticks for
axnumᵀ: the index of the axis we are plotting against
coords: the position in all coordinates for this plot. The value a axnum and axnumᵀ is igored.

`coords` is important for showing 2D coords of a 3+D cube as we need to know
our position along the other axes for accurate tick positions.

OUTPUT
tickpos: tick positions in pixels for this axis
ticklabels: tick labels for each position
"""
# Most of the complexity of this function is making sure everything
# generalizes to N different, possiby skewed axes, where a change in
# the opposite coordinate or even an unplotted coordinate affects
# the tick labels.
wcsticks(img::AstroImage, axnum) = wcsticks(WCSGrid(img), axnum)
function wcsticks(wcsg::WCSGrid, axnum, gridspec=wcsgridspec(wcsg))#tickposx, tickposw)
    w = wcsg.w

    # TODO: sort out axnum stuff
    tickposx = axnum == 1 ? gridspec.tickpos1x : gridspec.tickpos2x
    tickposw = axnum == 1 ? gridspec.tickpos1w : gridspec.tickpos2w

    if length(tickposw) != length(tickposx)
        error("Tick position vectors are of different length")
    end
    if length(tickposx) == 0
        return similar(tickposx, 0), String[]
    end

    if w.cunit[axnum] == "deg"
        if startswith(uppercase(w.ctype[axnum]), "RA")
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

    # Format inital ticklabel 
    ticklabels = fill("", length(tickposx))
    # We only include the part of the label that has changed since the last time.
    # Split up coordinates into e.g. sexagesimal
    parts = map(tickposw) do w
        vals = converter(w)
        return vals
    end

    # Start with something impossible of the same size:
    last_coord = Inf .* converter(first(tickposw))
    zero_coords_i = maximum(map(parts) do vals
        changing_coord_i = findfirst(vals .!= last_coord)
        last_coord = vals
        return changing_coord_i
    end)

    # Loop through using only the relevant part of the label
    # Start with something impossible of the same size:
    last_coord = Inf .* converter(first(tickposw))
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

    return tickposx, ticklabels
end
export wcsticks

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



"""
    WCSGrid(img::AstroImage, ax=(1,2), coords=(first(axes(img,ax[1])),first(axes(img,ax[2]))))

Given an AstroImage, return information necessary to plot WCS gridlines in physical
coordinates against the image's pixel coordinates.
This function has to work on both plotted axes at once to handle rotation and general
curvature of the WCS grid projected on the image coordinates.

"""
function WCSGrid(img::AstroImage, ax=(1,2))

    minx = first(axes(img,ax[1]))
    maxx = last(axes(img,ax[1]))
    miny = first(axes(img,ax[2]))
    maxy = last(axes(img,ax[2]))
    extent = (minx, maxx, miny, maxy)

    return WCSGrid(wcs(img), extent, ax, (extent[1], extent[3]))
end



# TODO: the wcs parameter is not getting forwardded correctly. Use plot recipe system for this.

# This recipe plots as AstroImage of color data as an image series (not heatmap).
# This lets us also plot color composites e.g. in WCS coordinates.
@recipe function f(wcsg::WCSGrid)
    color --> :black # Is there a way to get the foreground color automatically?
    label --> ""

    gridspec = wcsgridspec(wcsg)
    xs, ys = wcsgridlines(gridspec)

    color = plotattributes[:color]

    # We can optionally annotate the grid with their coordinates
    if haskey(plotattributes, :annotategrid) && plotattributes[:annotategrid]
        tickpos, ticklabels = wcsticks(wcsg, 2, gridspec)
        @series begin
            rotations = atand.(gridspec.tickslopes2x, 1)
            seriestype := :line
            linewidth := 0
            series_annotations := [
                Main.Plots.text(" $l", :left, :bottom, color, 8; rotation)
                for (l, rotation) in zip(ticklabels, rotations)
            ]
            ones(length(gridspec.tickpos2x)), tickpos
        end

        tickpos, ticklabels = wcsticks(wcsg, 1, gridspec)
        @series begin
            rotations = atand.(gridspec.tickslopes1x, 1)
            seriestype := :line
            linewidth := 0
            series_annotations := [
                Main.Plots.text(" $l", :left, :bottom, color, 8; rotation)
                for (l, rotation) in zip(ticklabels, rotations)
            ]
            tickpos, ones(length(gridspec.tickpos1x))
        end
    end

    xticks --> wcsticks(wcsg, 1, gridspec)
    xguide --> ctype_label(wcsg.w.ctype[wcsg.ax[1]], wcsg.w.radesys)

    yticks --> wcsticks(wcsg, 2, gridspec)
    yguide --> ctype_label(wcsg.w.ctype[wcsg.ax[2]], wcsg.w.radesys)

    xlims := wcsg.extent[1], wcsg.extent[2]
    ylims := wcsg.extent[3], wcsg.extent[4]

    grid := false
    tickdirection := :none

    return xs, ys

end


function wcsgridspec(wsg::WCSGrid)
# function wcsgridspec(w::WCSTransform, extent, ax=(1,2), coords=(extent[1], extent[3]))#coords=(first(axes(img,ax[1])),first(axes(img,ax[2]))))
    
    # x and y denote pixel coordinates (along `ax`), u and v are world coordinates along same?
    ax = collect(wsg.ax)
    coordsx = convert(Vector{Float64}, collect(wsg.coords))
    minx, maxx, miny, maxy = wsg.extent

    # Find the extent of this slice in world coordinates
    posxy = repeat(coordsx, 1, 4)
    posxy[ax,1] .= (minx,miny)
    posxy[ax,2] .= (minx,maxy)
    posxy[ax,3] .= (maxx,miny)
    posxy[ax,4] .= (maxx,maxy)
    posuv = pix_to_world(wsg.w, posxy)
    (minu, maxu), (minv, maxv) = extrema(posuv, dims=2)
    # Δu = abs(maxu-minu)
    # Δv = abs(maxv-minv)

    # Find nice grid spacings
    # These heuristics can probably be improved
    Q=[(1.0,1.0), (3.0, 0.8), (2.0, 0.7), (5.0, 0.5)] # dms2deg(0, 0, 20)
    k_min = 4
    k_ideal = 8
    k_max = 20
    tickposu = optimize_ticks(6minu, 6maxu; Q, k_min, k_ideal, k_max)[1]./6
    tickposv = optimize_ticks(6minv, 6maxv; Q, k_min, k_ideal, k_max)[1]./6

    # In general, grid can be curved when plotted back against the image.
    # So we will need to sample multiple points along the grid.
    # TODO: find a good heuristic for this based on the curvature.
    N_points = 20
    # TODO: this does not handle coordinates that wrap arounds
    urange = range(minu, maxu, length=N_points)
    vrange = range(minv, maxv, length=N_points)

    tickpos2x = Float64[]
    tickpos2w = Float64[]
    tickslopes2x = Float64[]
    gridlinesxy2 = NTuple{2,Vector{Float64}}[]
    for ticku in tickposu
        # Make sure we handle unplotted slices correctly.
        griduv = repeat(posuv[:,1], 1, N_points)
        griduv[ax[1],:] .= ticku
        griduv[ax[2],:] .= vrange
        posxy = world_to_pix(wsg.w, griduv)

        # Now that we have the grid in pixel coordinates, 
        # if we find out where the grid intersects the axes we can put
        # the labels in the correct spot
        
        # We can use these masks to determine where, and in what direction
        # the gridlines leave the plot extent
        in_horz_ax = minx .<=  posxy[ax[1],:] .<= maxx
        in_vert_ax = miny .<=  posxy[ax[2],:] .<= maxy
        in_axes = in_horz_ax .& in_vert_ax
        if count(in_axes) < 2
            continue
        # Vertical grid line
        elseif all(in_horz_ax)
            point_entered = [
                posxy[ax[1],1]
                miny
            ]
            point_exitted = [
                posxy[ax[1],1]
                maxy
            ]
            push!(tickpos2x, posxy[ax[1],1])
            push!(tickpos2w, ticku)
            push!(tickslopes2x, π/2)
        else

            # Use the masks to pick an x,y point inside the axes and an
            # x,y point outside the axes.
            i = findfirst(in_axes)
            x1 = posxy[ax[1],i]
            y1 = posxy[ax[2],i]
            x2 = posxy[ax[1],i+1]
            y2 = posxy[ax[2],i+1]
            if x2-x1 ≈ 0
                @show "undef slope A"
            end

            # Fit a line where we cross the axis
            m1 = (y2-y1)/(x2-x1)
            b1 = y1-m1*x1
            # If the line enters via the vertical axes...
            if findfirst(in_vert_ax) <= findfirst(in_horz_ax)
                # Then we simply evaluate it at that axis
                x = abs(x1-maxx) < abs(x1-minx) ? maxx : minx
                x = clamp(x,minx,maxx)
                y = m1*x+b1
                if abs(x-minx) < abs(x-maxx)
                    push!(tickpos2x, y)
                    push!(tickpos2w, ticku)
                    push!(tickslopes2x, atan(m1, 1))
                end
            else
                # We must find where it enters the plot from
                # bottom or top
                x = abs(y1-maxy) < abs(y1-miny) ? (maxy-b1)/m1 : (miny-b1)/m1
                x = clamp(x,minx,maxx)
                y = m1*x+b1
            end
        
            # From here, do a linear fit to find the intersection with the axis.
            point_entered = [
                x
                y
            ]

            # Use the masks to pick an x,y point inside the axes and an
            # x,y point outside the axes.
            i = findlast(in_axes)
            x1 = posxy[ax[1],i-1]
            y1 = posxy[ax[2],i-1]
            x2 = posxy[ax[1],i]
            y2 = posxy[ax[2],i]
            if x2-x1 ≈ 0
                @show "undef slope B"
            end

            # Fit a line where we cross the axis
            m2 = (y2-y1)/(x2-x1)
            b2 = y2-m2*x2
            if findlast(in_vert_ax) > findlast(in_horz_ax)
                # Then we simply evaluate it at that axis
                x = abs(x1-maxx) < abs(x1-minx) ? maxx : minx
                x = clamp(x,minx,maxx)
                y = m2*x+b2
                if abs(x-minx) < abs(x-maxx)
                    push!(tickpos2x, y)
                    push!(tickpos2w, ticku)
                    push!(tickslopes2x, atan(m2, 1))
                end
            else
                # We must find where it enters the plot from
                # bottom or top
                x = abs(y1-maxy) < abs(y1-miny) ? (maxy-b2)/m2 : (miny-b2)/m2
                x = clamp(x,minx,maxx)
                y = m2*x+b2
            end
        
            # From here, do a linear fit to find the intersection with the axis.
            point_exitted = [
                x 
                y
            ]
        end

        posxy_neat = [point_entered  posxy[[ax[1],ax[2]],in_axes] point_exitted]
        # posxy_neat = posxy
        # TODO: do unplotted other axes also need a fit?

        gridlinexy = (
            posxy_neat[ax[1],:],
            posxy_neat[ax[2],:]
        )
        push!(gridlinesxy2, gridlinexy)
    end

    # Then do the opposite coordinate
    tickpos1x = Float64[]
    tickpos1w = Float64[]
    tickslopes1x = Float64[]
    gridlinesxy1 = NTuple{2,Vector{Float64}}[]
    for tickv in tickposv
        # Make sure we handle unplotted slices correctly.
        griduv = repeat(posuv[:,1], 1, N_points)
        griduv[ax[1],:] .= urange
        griduv[ax[2],:] .= tickv
        posxy = world_to_pix(wsg.w, griduv)

        # Now that we have the grid in pixel coordinates, 
        # if we find out where the grid intersects the axes we can put
        # the labels in the correct spot
        
        # We can use these masks to determine where, and in what direction
        # the gridlines leave the plot extent
        in_horz_ax = minx .<=  posxy[ax[1],:] .<= maxx
        in_vert_ax = miny .<=  posxy[ax[2],:] .<= maxy
        in_axes = in_horz_ax .& in_vert_ax
        if count(in_axes) < 2
            continue
         # Vertical grid line
        elseif all(in_vert_ax)
            point_entered = [
                maxx
                posxy[ax[2],1]
            ]
            point_exitted = [
                maxx
                posxy[ax[2],2]
            ]
            push!(tickpos1x, posxy[ax[2],1])
            push!(tickpos1w, tickv)
            push!(tickslopes1x, π/2)
        else
            
            # Use the masks to pick an x,y point inside the axes and an
            # x,y point outside the axes.
            i = findfirst(in_axes)
            x1 = posxy[ax[1],i]
            y1 = posxy[ax[2],i]
            x2 = posxy[ax[1],i+1]
            y2 = posxy[ax[2],i+1]
            if x2-x1 ≈ 0
                @show "undef slope C"
            end

            # Fit a line where we cross the axis
            m1 = (y2-y1)/(x2-x1)
            b1 = y1-m1*x1
            # If the line enters via the vertical axes...
            if findfirst(in_vert_ax) < findfirst(in_horz_ax)
                # Then we simply evaluate it at that axis
                x = abs(x1-maxx) < abs(x1-minx) ? maxx : minx
                x = clamp(x,minx,maxx)
                y = m1*x+b1
            else
                # We must find where it enters the plot from
                # bottom or top
                x = abs(y1-maxy) < abs(y1-miny) ? (maxy-b1)/m1 : (miny-b1)/m1
                # x = clamp(x,minx,maxx)
                y = m1*x+b1
                if abs(y-miny) < abs(y-maxy)
                    push!(tickpos1x, x)
                    push!(tickpos1w, tickv)
                    push!(tickslopes1x, atan(m1, 1))
                end
            end
        
            # From here, do a linear fit to find the intersection with the axis.
            point_entered = [
                x
                y
            ]

            # Use the masks to pick an x,y point inside the axes and an
            # x,y point outside the axes.
            i = findlast(in_axes)
            x1 = posxy[ax[1],i-1]
            y1 = posxy[ax[2],i-1]
            x2 = posxy[ax[1],i]
            y2 = posxy[ax[2],i]
            if x2-x1 ≈ 0
                @show "undef slope D"
            end

            # Fit a line where we cross the axis
            m2 = (y2-y1)/(x2-x1)
            b2 = y2-m2*x2
            if findlast(in_vert_ax) > findlast(in_horz_ax)
                # Then we simply evaluate it at that axis
                x = abs(x1-maxx) < abs(x1-minx) ? maxx : minx
                x = clamp(x,minx,maxx)
                y = m2*x+b2
            else
                # We must find where it enters the plot from
                # bottom or top
                x = abs(y1-maxy) < abs(y1-miny) ? (maxy-b2)/m2 : (miny-b2)/m2
                x = clamp(x,minx,maxx)
                y = m2*x+b2
                if abs(y-miny) < abs(y-maxy)
                    push!(tickpos1x, x)
                    push!(tickpos1w, tickv)
                    push!(tickslopes1x, atan(m2, 1))
                end
            end
        
            # From here, do a linear fit to find the intersection with the axis.
            point_exitted = [
                x 
                y
            ]
        end

        posxy_neat = [point_entered  posxy[[ax[1],ax[2]],in_axes] point_exitted]
        # TODO: do unplotted other axes also need a fit?

        gridlinexy = (
            posxy_neat[ax[1],:],
            posxy_neat[ax[2],:]
        )
        push!(gridlinesxy1, gridlinexy)
    end


    return (;
        gridlinesxy1,
        gridlinesxy2,
        tickpos1x,
        tickpos1w,
        tickslopes1x,
        tickpos2x,
        tickpos2w,
        tickslopes2x
    )
end

function wcsgridlines(wcsg::WCSGrid)
    return wcsgridlines(wcsgridspec(wcsg))
end
function wcsgridlines(gridspec::NamedTuple)
    # Unroll grid lines into a single series separated by NaNs
    xs1 = mapreduce(vcat, gridspec.gridlinesxy1, init=Float64[]) do gridline
        return vcat(gridline[1], NaN)
    end
    ys1 = mapreduce(vcat, gridspec.gridlinesxy1, init=Float64[]) do gridline
        return vcat(gridline[2], NaN)
    end
    xs2 = mapreduce(vcat, gridspec.gridlinesxy2, init=Float64[]) do gridline
        return vcat(gridline[1], NaN)
    end
    ys2 = mapreduce(vcat, gridspec.gridlinesxy2, init=Float64[]) do gridline
        return vcat(gridline[2], NaN)
    end

    xs = vcat(xs1, NaN, xs2)
    ys = vcat(ys1, NaN, ys2)
    return xs, ys
end
export wcsgridlines

export WCSGrid

