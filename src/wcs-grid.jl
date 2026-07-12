# Backend-agnostic machinery for laying out WCS grid lines, tick positions,
# and tick labels against an image's pixel coordinates. Used by the plotting
# extensions (see ext/) via WCSGrid and wcsgridspec.

struct WCSGrid
    img::AstroImage
    extent::NTuple{4, Float64}
    wcsn::Char
end


"""
    wcsticks(img, axnum)

Generate nice tick labels for an AstroImageMat along axis `axnum`
Returns a vector of pixel positions and a vector of strings.

Example:
plot(img, xticks=wcsticks(WCSGrid(img), 1), yticks=wcsticks(WCSGrid(img), 2))
"""
function wcsticks(wcsg::WCSGrid, axnum, gs = wcsgridspec(wcsg))
    tickposx = axnum == 1 ? gs.tickpos1x : gs.tickpos2x
    tickposw = axnum == 1 ? gs.tickpos1w : gs.tickpos2w
    return tickposx, wcslabels(
            wcs(wcsg.img, wcsg.wcsn), axnum, tickposw
        )
end

# Format the coordinate components `from_i:to_i` of `vals` with their `units`,
# e.g. (23, 23, 33.6) with ("ʰ", "ᵐ", "ˢ") over 2:3 -> "23ᵐ33.60ˢ". The final
# component of the full tuple is displayed with decimal places.
function _format_label_parts(vals, units, from_i, to_i)
    return mapreduce(*, from_i:to_i; init = "") do coord_i
        str = coord_i == length(vals) ? @sprintf("%.2f", vals[coord_i]) : @sprintf("%02d", vals[coord_i])
        return str * units[coord_i]
    end
end

# Function to generate nice string coordinate labels given a WCSTransform, axis number,
# and a vector of tick positions in world coordinates.
# This is used for labelling ticks and for annotating grid lines.
#
# With `stacked=true`, ticks that would carry context beyond the finest
# changing component (the first tick, or roll-overs like `23ᵐ48.00ˢ`) are
# split onto two lines with the finest component on top and the full context
# below, e.g. "48.00ˢ\n23ʰ23ᵐ", following the pattern of Makie's
# DateTimeTicks. This keeps dense tick labels from crowding along the x axis.
function wcslabels(w::WCSTransform, axnum, tickposw; stacked::Bool = false)

    if length(tickposw) == 0
        return String[]
    end

    # Select a unit converter (e.g. 12.12 -> (a,b,c,d)) and list of units
    if w.cunit[axnum] == "deg"
        if startswith(uppercase(w.ctype[axnum]), "RA")
            converter = deg2hms
            units = hms_units
        else
            converter = deg2dmsmμ
            units = dmsmμ_units
        end
    else
        converter = x -> (x,)
        units = ("",)
    end

    # Format inital ticklabel
    ticklabels = fill("", length(tickposw))
    # We only include the part of the label that has changed since the last time.
    # Split up coordinates into e.g. sexagesimal
    parts = map(tickposw) do w
        vals = converter(w)
        return vals
    end

    # Start with something impossible of the same size:
    last_coord = Inf .* converter(first(tickposw))
    zero_coords_i = maximum(
        map(parts) do vals
            changing_coord_i = findfirst(vals .!= last_coord)
            if isnothing(changing_coord_i)
                changing_coord_i = 1
            end
            last_coord = vals
            return changing_coord_i
        end
    )


    # Loop through using only the relevant part of the label
    # Start with something impossible of the same size:
    last_coord = Inf .* converter(first(tickposw))
    for (i, vals) in enumerate(parts)
        changing_coord_i = findfirst(vals .!= last_coord)
        if isnothing(changing_coord_i)
            changing_coord_i = 1
        end
        if stacked && changing_coord_i < zero_coords_i
            # Two-line label: finest component on top, full context below.
            top = _format_label_parts(vals, units, zero_coords_i, zero_coords_i)
            bottom = _format_label_parts(vals, units, 1, zero_coords_i - 1)
            ticklabels[i] = top * "\n" * bottom
        else
            # Don't display just e.g. 00" when we should display 50'00"
            if changing_coord_i > 1 && vals[changing_coord_i] == 0
                changing_coord_i = changing_coord_i - 1
            end
            ticklabels[i] = _format_label_parts(vals, units, changing_coord_i, zero_coords_i)
        end
        last_coord = vals
    end

    return ticklabels
end

# Extended form of deg2dms that further returns mas, microas.
function deg2dmsmμ(deg)
    d, m, s = deg2dms(deg)
    s_f = floor(s)
    mas = (s - s_f) * 1.0e3
    mas_f = floor(mas)
    μas = (mas - mas_f) * 1.0e3
    return (d, m, s_f, mas_f, μas)
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

function ctype_label(ctype, radesys)
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
        # elseif startswith(ctype, "TLAT")
    elseif ctype == "STOKES"
        return "Polarization"
    else
        return ctype
    end
end


"""
    WCSGrid(img::AstroImageMat, ax=(1,2), coords=(first(axes(img,ax[1])),first(axes(img,ax[2]))))

Given an AstroImageMat, return information necessary to plot WCS gridlines in physical
coordinates against the image's pixel coordinates.
This function has to work on both plotted axes at once to handle rotation and general
curvature of the WCS grid projected on the image coordinates.

"""
function WCSGrid(img::AstroImageMat, wcsn = ' ')
    minx = first(dims(img, 2))
    maxx = last(dims(img, 2))
    miny = first(dims(img, 1))
    maxy = last(dims(img, 1))
    extent = (minx - 0.5, maxx + 0.5, miny - 0.5, maxy + 0.5)
    return WCSGrid(img, extent, wcsn)
end


# Helper: true if all elements in vector are equal to each other.
allequal(itr) = all(==(first(itr)), itr)

# This function is responsible for actually laying out grid lines for a WCSGrid,
# ensuring they don't exceed the plot bounds, finding where they intersect the axes,
# and picking tick locations at the appropriate intersections with the left and
# bottom axes.
function wcsgridspec(wsg::WCSGrid)
    # Most of the complexity of this function is making sure everything
    # generalizes to N different, possiby skewed axes, where a change in
    # the opposite coordinate or even an unplotted coordinate affects
    # the grid.

    # x and y denote pixel coordinates (along `ax`), u and v are world coordinates roughly along same.
    minx, maxx, miny, maxy = wsg.extent

    # Find the extent of this slice in world coordinates
    posxy = [
        minx minx maxx maxx
        miny maxy miny maxy
    ]
    posuv = pixel_to_world(wsg.img, posxy; wsg.wcsn, parent = true)
    (minu, maxu), (minv, maxv) = extrema(posuv, dims = 2)

    # In general, grid can be curved when plotted back against the image,
    # so we will need to sample multiple points along the grid.
    # TODO: find a good heuristic for this based on the curvature.
    N_points = 50
    urange = range(minu, maxu, length = N_points)
    vrange = range(minv, maxv, length = N_points)

    # Find nice grid spacings using PlotUtils.optimize_ticks
    # These heuristics can probably be improved
    # TODO: this does not handle coordinates that wrap around
    Q = [(1.0, 1.0), (3.0, 0.8), (2.0, 0.7), (5.0, 0.5)]
    k_min = 3
    k_ideal = 5
    k_max = 10

    tickpos2x = Float64[]
    tickpos2w = Float64[]
    gridlinesxy2 = NTuple{2, Vector{Float64}}[]
    # Not all grid lines will intersect the x & y axes nicely.
    # If we don't get enough valid tick marks (at least 2) loop again
    # requesting more locations up to three times.
    local tickposv
    j = 5
    while length(tickpos2x) < 2 && j > 0
        k_min += 2
        k_ideal += 2
        k_max += 2
        j -= 1

        tickposv = optimize_ticks(6minv, 6maxv; Q, k_min, k_ideal, k_max)[1] ./ 6

        empty!(tickpos2x)
        empty!(tickpos2w)
        empty!(gridlinesxy2)
        for tickv in tickposv
            # Make sure we handle unplotted slices correctly.
            griduv = repeat(posuv[:, 1], 1, N_points)
            griduv[1, :] .= urange
            griduv[2, :] .= tickv
            posxy = world_to_pixel(wsg.img, griduv; wsg.wcsn, parent = true)

            # Now that we have the grid in pixel coordinates,
            # if we find out where the grid intersects the axes we can put
            # the labels in the correct spot

            # We can use these masks to determine where, and in what direction
            # the gridlines leave the plot extent
            in_horz_ax = minx .<= posxy[1, :] .<= maxx
            in_vert_ax = miny .<= posxy[2, :] .<= maxy
            in_axes = in_horz_ax .& in_vert_ax
            if count(in_axes) < 2
                continue
            elseif all(in_axes)
                point_entered = [
                    posxy[1, begin]
                    posxy[2, begin]
                ]
                point_exitted = [
                    posxy[1, end]
                    posxy[2, end]
                ]
            elseif allequal(posxy[1, findfirst(in_axes):findlast(in_axes)])
                point_entered = [
                    posxy[1, max(begin, findfirst(in_axes) - 1)]
                    # posxy[2,max(begin,findfirst(in_axes)-1)]
                    miny
                ]
                point_exitted = [
                    posxy[1, min(end, findlast(in_axes) + 1)]
                    # posxy[2,min(end,findlast(in_axes)+1)]
                    maxy
                ]
                # Vertical grid lines
            elseif allequal(posxy[2, findfirst(in_axes):findlast(in_axes)])
                point_entered = [
                    minx #posxy[1,max(begin,findfirst(in_axes)-1)]
                    posxy[2, max(begin, findfirst(in_axes) - 1)]
                ]
                point_exitted = [
                    maxx #posxy[1,min(end,findlast(in_axes)+1)]
                    posxy[2, min(end, findlast(in_axes) + 1)]
                ]
            else
                # Use the masks to pick an x,y point inside the axes and an
                # x,y point outside the axes.
                i = findfirst(in_axes)
                x1 = posxy[1, i]
                y1 = posxy[2, i]
                x2 = posxy[1, i + 1]
                y2 = posxy[2, i + 1]
                if x2 - x1 ≈ 0
                    @warn "undef slope"
                end

                # Fit a line where we cross the axis
                m1 = (y2 - y1) / (x2 - x1)
                b1 = y1 - m1 * x1
                # If the line enters via the vertical axes...
                if findfirst(in_vert_ax) <= findfirst(in_horz_ax)
                    # Then we simply evaluate it at that axis
                    x = abs(x1 - maxx) < abs(x1 - minx) ? maxx : minx
                    x = clamp(x, minx, maxx)
                    y = m1 * x + b1
                else
                    # We must find where it enters the plot from
                    # bottom or top
                    x = abs(y1 - maxy) < abs(y1 - miny) ? (maxy - b1) / m1 : (miny - b1) / m1
                    x = clamp(x, minx, maxx)
                    y = m1 * x + b1
                end

                # From here, do a linear fit to find the intersection with the axis.
                point_entered = [
                    x
                    y
                ]


                # Use the masks to pick an x,y point inside the axes and an
                # x,y point outside the axes.
                i = findlast(in_axes)
                x1 = posxy[1, i - 1]
                y1 = posxy[2, i - 1]
                x2 = posxy[1, i]
                y2 = posxy[2, i]
                if x2 - x1 ≈ 0
                    @warn "undef slope"
                end

                # Fit a line where we cross the axis
                m2 = (y2 - y1) / (x2 - x1)
                b2 = y2 - m2 * x2
                if findlast(in_vert_ax) > findlast(in_horz_ax)
                    # Then we simply evaluate it at that axis
                    x = abs(x1 - maxx) < abs(x1 - minx) ? maxx : minx
                    x = clamp(x, minx, maxx)
                    y = m2 * x + b2
                else
                    # We must find where it enters the plot from
                    # bottom or top
                    x = abs(y1 - maxy) < abs(y1 - miny) ? (maxy - b2) / m2 : (miny - b2) / m2
                    x = clamp(x, minx, maxx)
                    y = m2 * x + b2
                end

                # From here, do a linear fit to find the intersection with the axis.
                point_exitted = [
                    x
                    y
                ]
            end


            if point_entered[1] == minx
                push!(tickpos2x, point_entered[2])
                push!(tickpos2w, tickv)
            end
            if point_exitted[1] == minx
                push!(tickpos2x, point_exitted[2])
                push!(tickpos2w, tickv)
            end


            posxy_neat = [point_entered  posxy[[1, 2], in_axes] point_exitted]
            # posxy_neat = posxy
            # TODO: do unplotted other axes also need a fit?

            gridlinexy = (
                posxy_neat[1, :],
                posxy_neat[2, :],
            )
            push!(gridlinesxy2, gridlinexy)
        end
    end

    # Then do the opposite coordinate
    k_min = 3
    k_ideal = 5
    k_max = 10
    tickpos1x = Float64[]
    tickpos1w = Float64[]
    gridlinesxy1 = NTuple{2, Vector{Float64}}[]
    # Not all grid lines will intersect the x & y axes nicely.
    # If we don't get enough valid tick marks (at least 2) loop again
    # requesting more locations up to three times.
    local tickposu
    j = 5
    while length(tickpos1x) < 2 && j > 0
        k_min += 2
        k_ideal += 2
        k_max += 2
        j -= 1

        tickposu = optimize_ticks(6minu, 6maxu; Q, k_min, k_ideal, k_max)[1] ./ 6

        empty!(tickpos1x)
        empty!(tickpos1w)
        empty!(gridlinesxy1)
        for ticku in tickposu
            # Make sure we handle unplotted slices correctly.
            griduv = repeat(posuv[:, 1], 1, N_points)
            griduv[1, :] .= ticku
            griduv[2, :] .= vrange
            posxy = world_to_pixel(wsg.img, griduv; wsg.wcsn, parent = true)

            # Now that we have the grid in pixel coordinates,
            # if we find out where the grid intersects the axes we can put
            # the labels in the correct spot

            # We can use these masks to determine where, and in what direction
            # the gridlines leave the plot extent
            in_horz_ax = minx .<= posxy[1, :] .<= maxx
            in_vert_ax = miny .<= posxy[2, :] .<= maxy
            in_axes = in_horz_ax .& in_vert_ax


            if count(in_axes) < 2
                continue
            elseif all(in_axes)
                point_entered = [
                    posxy[1, begin]
                    posxy[2, begin]
                ]
                point_exitted = [
                    posxy[1, end]
                    posxy[2, end]
                ]
                # Horizontal grid lines
            elseif allequal(posxy[1, findfirst(in_axes):findlast(in_axes)])
                point_entered = [
                    posxy[1, findfirst(in_axes)]
                    miny
                ]
                point_exitted = [
                    posxy[1, findlast(in_axes)]
                    maxy
                ]
                # push!(tickpos1x, posxy[1,findfirst(in_axes)])
                # push!(tickpos1w, ticku)
                # Vertical grid lines
            elseif allequal(posxy[2, findfirst(in_axes):findlast(in_axes)])
                point_entered = [
                    minx
                    posxy[2, findfirst(in_axes)]
                ]
                point_exitted = [
                    maxx
                    posxy[2, findfirst(in_axes)]
                ]
            else
                # Use the masks to pick an x,y point inside the axes and an
                # x,y point outside the axes.
                i = findfirst(in_axes)
                x1 = posxy[1, i]
                y1 = posxy[2, i]
                x2 = posxy[1, i + 1]
                y2 = posxy[2, i + 1]
                if x2 - x1 ≈ 0
                    @warn "undef slope"
                end

                # Fit a line where we cross the axis
                m1 = (y2 - y1) / (x2 - x1)
                b1 = y1 - m1 * x1
                # If the line enters via the vertical axes...
                if findfirst(in_vert_ax) < findfirst(in_horz_ax)
                    # Then we simply evaluate it at that axis
                    x = abs(x1 - maxx) < abs(x1 - minx) ? maxx : minx
                    x = clamp(x, minx, maxx)
                    y = m1 * x + b1
                else
                    # We must find where it enters the plot from
                    # bottom or top
                    x = abs(y1 - maxy) < abs(y1 - miny) ? (maxy - b1) / m1 : (miny - b1) / m1
                    x = clamp(x, minx, maxx)
                    y = m1 * x + b1
                end

                # From here, do a linear fit to find the intersection with the axis.
                point_entered = [
                    x
                    y
                ]

                # Use the masks to pick an x,y point inside the axes and an
                # x,y point outside the axes.
                i = findlast(in_axes)
                x1 = posxy[1, i - 1]
                y1 = posxy[2, i - 1]
                x2 = posxy[1, i]
                y2 = posxy[2, i]
                if x2 - x1 ≈ 0
                    @warn "undef slope"
                end

                # Fit a line where we cross the axis
                m2 = (y2 - y1) / (x2 - x1)
                b2 = y2 - m2 * x2
                if findlast(in_vert_ax) > findlast(in_horz_ax)
                    # Then we simply evaluate it at that axis
                    x = abs(x1 - maxx) < abs(x1 - minx) ? maxx : minx
                    x = clamp(x, minx, maxx)
                    y = m2 * x + b2
                else
                    # We must find where it enters the plot from
                    # bottom or top
                    x = abs(y1 - maxy) < abs(y1 - miny) ? (maxy - b2) / m2 : (miny - b2) / m2
                    x = clamp(x, minx, maxx)
                    y = m2 * x + b2
                end

                # From here, do a linear fit to find the intersection with the axis.
                point_exitted = [
                    x
                    y
                ]
            end

            posxy_neat = [point_entered  posxy[[1, 2], in_axes] point_exitted]
            # TODO: do unplotted other axes also need a fit?

            if point_entered[2] == miny
                push!(tickpos1x, point_entered[1])
                push!(tickpos1w, ticku)
            end
            if point_exitted[2] == miny
                push!(tickpos1x, point_exitted[1])
                push!(tickpos1w, ticku)
            end

            gridlinexy = (
                posxy_neat[1, :],
                posxy_neat[2, :],
            )
            push!(gridlinesxy1, gridlinexy)
        end
    end

    # Grid annotations are simpler:
    annotations1w = Float64[]
    annotations1x = Float64[]
    annotations1y = Float64[]
    annotations1θ = Float64[]
    for ticku in tickposu
        # Make sure we handle unplotted slices correctly.
        griduv = posuv[:, 1]
        griduv[1] = ticku
        griduv[2] = mean(vrange)
        posxy = world_to_pixel(wsg.img, griduv; wsg.wcsn, parent = true)
        if !(minx < posxy[1] < maxx) || !(miny < posxy[2] < maxy)
            continue
        end
        push!(annotations1w, ticku)
        push!(annotations1x, posxy[1])
        push!(annotations1y, posxy[2])

        # Now find slope (TODO: stepsize)
        # griduv[ax[2]] -= 1
        griduv[2] += 0.1step(vrange)
        posxy2 = world_to_pixel(wsg.img, griduv; wsg.wcsn, parent = true)
        θ = atan(posxy2[2] - posxy[2], posxy2[1] - posxy[1])
        push!(annotations1θ, θ)
    end
    annotations2w = Float64[]
    annotations2x = Float64[]
    annotations2y = Float64[]
    annotations2θ = Float64[]
    for tickv in tickposv
        # Make sure we handle unplotted slices correctly.
        griduv = posuv[:, 1]
        griduv[1] = mean(urange)
        griduv[2] = tickv
        posxy = world_to_pixel(wsg.img, griduv; wsg.wcsn, parent = true)
        if !(minx < posxy[1] < maxx) || !(miny < posxy[2] < maxy)
            continue
        end
        push!(annotations2w, tickv)
        push!(annotations2x, posxy[1])
        push!(annotations2y, posxy[2])

        griduv[1] += 0.1step(urange)
        posxy2 = world_to_pixel(wsg.img, griduv; wsg.wcsn, parent = true)
        θ = atan(posxy2[2] - posxy[2], posxy2[1] - posxy[1])
        push!(annotations2θ, θ)
    end

    return (;
        gridlinesxy1,
        gridlinesxy2,
        tickpos1x,
        tickpos1w,
        tickpos2x,
        tickpos2w,

        annotations1w,
        annotations1x,
        annotations1y,
        annotations1θ,

        annotations2w,
        annotations2x,
        annotations2y,
        annotations2θ,
    )
end

# From a WCSGrid, return just the grid lines as a single pair of x & y coordinates
# suitable for plotting.
function wcsgridlines(wcsg::WCSGrid)
    return wcsgridlines(wcsgridspec(wcsg))
end
function wcsgridlines(gridspec::NamedTuple)
    # Unroll grid lines into a single series separated by NaNs
    xs1 = mapreduce(vcat, gridspec.gridlinesxy1, init = Float64[]) do gridline
        return vcat(gridline[1], NaN)
    end
    ys1 = mapreduce(vcat, gridspec.gridlinesxy1, init = Float64[]) do gridline
        return vcat(gridline[2], NaN)
    end
    xs2 = mapreduce(vcat, gridspec.gridlinesxy2, init = Float64[]) do gridline
        return vcat(gridline[1], NaN)
    end
    ys2 = mapreduce(vcat, gridspec.gridlinesxy2, init = Float64[]) do gridline
        return vcat(gridline[2], NaN)
    end

    xs = vcat(xs1, NaN, xs2)
    ys = vcat(ys1, NaN, ys2)
    return xs, ys
end
