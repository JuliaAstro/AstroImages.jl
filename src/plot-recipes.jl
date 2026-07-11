@userplot ImPlot
@recipe function f(h::ImPlot)
    if length(h.args) != 1 || !(typeof(h.args[1]) <: AbstractArray)
        error("Image plots require an arugment that is a subtype of AbstractArray.  Got: $(typeof(h.args))")
    end
    data = only(h.args)
    if !(typeof(data) <: AstroImage)
        data = AstroImage(only(h.args))
    end
    T = eltype(data)
    if ndims(data) != 2
        error("Image passed to `implot` must be two-dimensional.  Got ndims(img)=$(ndims(data))")
    end

    wcsn = get(plotattributes, :wcsn, ' ')
    # Show WCS coordinates if wcsticks is true or unspecified, and has at least one WCS axis present.
    showwcsticks = get(plotattributes, :wcsticks, true) &&  !all(==(""), wcs(data, wcsn).ctype)
    showwcstitle = get(plotattributes, :wcstitle, true) &&  length(refdims(data)) > 0 && !all(==(""), wcs(data, wcsn).ctype)


    minx = first(parent(dims(data, 1)))
    maxx = last(parent(dims(data, 1)))
    miny = first(parent(dims(data, 2)))
    maxy = last(parent(dims(data, 2)))
    extent = (minx - 0.5, maxx + 0.5, miny - 0.5, maxy + 0.5)
    if haskey(plotattributes, :xlims)
        extent = (plotattributes[:xlims]..., extent[3:4]...)
    end
    if haskey(plotattributes, :ylims)
        extent = (extent[1:2]..., plotattributes[:ylims]...)
    end
    if showwcsticks
        wcsg = WCSGrid(data, Float64.(extent), wcsn)
        gridspec = wcsgridspec(wcsg)
    end

    # Use package defaults if not user provided.
    clims = get(plotattributes, :clims, _default_clims[])
    stretch = get(plotattributes, :stretch, _default_stretch[])
    # cmap now gets normalized to `seriescolor` where it didn't previously
    # Check for both.
    cmap = get(plotattributes, :seriescolor, _default_cmap[])
    cmap = get(plotattributes, :cmap, cmap)

    # Plotly is now failing if the user passes through a function as a keyword value
    # even if that function is only used by the recipe. Guard against this.
    if haskey(plotattributes, :clims)
        delete!(plotattributes, :clims)
    end
    if haskey(plotattributes, :stretch)
        delete!(plotattributes, :stretch)
    end
    if haskey(plotattributes, :cmap)
        delete!(plotattributes, :cmap)
    end

    bias = get(plotattributes, :bias, 0.5)
    contrast = get(plotattributes, :contrast, 1)
    platescale = get(plotattributes, :platescale, 1)

    grid := false
    # In most cases, a grid framestyle is a nicer looking default for images
    # but the user can override.
    framestyle --> :box


    if T <: Colorant
        imgv = data
    else
        if T <: Complex
            img = abs.(data)
            img["UNIT"] = "magnitude"
        else
            img = data
        end
        imgv = imview(img; clims, stretch, cmap, contrast, bias)
        imgv = shareheader(img, imgv)
    end

    # Reduce large images using the same heuristic as Images.jl
    maxpixels = get(plotattributes, :maxpixels, 10^6)
    _length1(A::AbstractArray) = length(eachindex(A))
    _length1(A) = length(A)
    while _length1(imgv) > maxpixels
        imgv = restrict(imgv)
    end

    # We have to do a lot of flipping to keep the orientation corect
    yflip := false
    xflip := false


    # Disable equal aspect ratios if the scales are totally different
    displayed_data_ratio = (extent[2] - extent[1]) / (extent[4] - extent[3])
    if displayed_data_ratio >= 7
        aspect_ratio --> :none
    end


    # we have a wcs flag (from the image by default) so that users can skip over
    # plotting in physical coordinates. This is especially important
    # if the WCS headers are mallformed in some way.
    showgrid = get(plotattributes, :xgrid, true) && get(plotattributes, :ygrid, true)
    # Display a title giving our position along unplotted dimensions
    if length(refdims(imgv)) > 0
        if showwcstitle
            refdimslabel = join(
                map(refdims(imgv)) do d
                    # match dimension with the wcs axis number
                    i = wcsax(imgv, d)
                    ct = wcs(imgv, wcsn).ctype[i]
                    label = ctype_label(ct, wcs(imgv, wcsn).radesys)
                    if label == "NONE"
                        label = name(d)
                    end
                    value = pixel_to_world(imgv, [1, 1]; wcsn, all = true, parent = true)[i]
                    unit = wcs(imgv, wcsn).cunit[i]
                    if ct == "STOKES"
                        return _stokes_name(_stokes_symbol(value))
                    else
                        return @sprintf("%s = %.5g %s", label, value, unit)
                    end
                end, ", "
            )
        else
            refdimslabel = join(map(d -> "$(name(d))= $(d[1])", refdims(imgv)), ", ")
        end
        title --> refdimslabel
    end

    # To ensure the physical axis tick labels are correct the axes must be
    # tight to the image
    xl = (first(dims(imgv, 1)) - 0.5) * platescale, (last(dims(imgv, 1)) + 0.5) * platescale
    yl = (first(dims(imgv, 2)) - 0.5) * platescale, (last(dims(imgv, 2)) + 0.5) * platescale
    ylims --> yl
    xlims --> xl

    subplot_i = 0
    # Actual image series (RGB pixels by this point)
    @series begin
        subplot_i += 1
        subplot := subplot_i
        colorbar := false
        aspect_ratio --> 1

        # Note: if the axes are on unusual sides (e.g. y-axis at right, x-axis at top)
        # then these coordinates are not correct. They are only correct exactly
        # along the axis.
        # In astropy, the ticks are actually tilted to reflect this, though in general
        # the transformation from pixel to coordinates can be non-linear and curved.

        if showwcsticks
            xticks --> (gridspec.tickpos1x, wcslabels(wcs(imgv, wcsn), wcsax(imgv, dims(imgv, 1)), gridspec.tickpos1w))
            xguide --> ctype_label(wcs(imgv, wcsn).ctype[wcsax(imgv, dims(imgv, 1))], wcs(imgv, wcsn).radesys)

            yticks --> (gridspec.tickpos2x, wcslabels(wcs(imgv, wcsn), wcsax(imgv, dims(imgv, 2)), gridspec.tickpos2w))
            yguide --> ctype_label(wcs(imgv, wcsn).ctype[wcsax(imgv, dims(imgv, 2))], wcs(imgv, wcsn).radesys)
        end


        ax1 = collect(parent(dims(imgv, 1))) .* platescale
        ax2 = collect(parent(dims(imgv, 2))) .* platescale
        # Views of images are not currently supported by plotly() so we have to collect them.
        # ax1, ax2, view(parent(imgv), reverse(axes(imgv,1)),:)
        ax1, ax2, parent(imgv)[reverse(axes(imgv, 1)), :]
    end

    # If wcs=true (default) and grid=true (not default), overplot a WCS
    # grid.
    if showgrid && showwcsticks

        # Plot the WCSGrid as a second series (actually just lines)
        @series begin
            subplot := 1
            # Use a default grid color that shows up across more
            # color maps
            if !haskey(plotattributes, :xforeground_color_grid) && !haskey(plotattributes, :yforeground_color_grid)
                gridcolor --> :lightgray
            end

            wcsg, gridspec
        end
    end


    # Disable the colorbar.
    # Plots.jl does not give us sufficient control to make sure the range and ticks
    # are correct after applying a non-linear stretch.
    # We attempt to make our own colorbar using a second plot.
    showcolorbar = !(T <: Colorant) && get(plotattributes, :colorbar, true) != :none
    if T <: Complex
        layout := @layout [
            imgmag{0.5h}
            imgangle{0.5h}
        ]
    end
    if showcolorbar
        if T <: Complex
            layout := @layout [
                imgmag{0.95w, 0.5h}         colorbar{0.5h}
                imgangle{0.95w, 0.5h}  colorbarangle{0.5h}
            ]
        else
            layout := @layout [
            img{0.95w} colorbar
            ]
        end
        colorbar_title = get(plotattributes, :colorbar_title, "")
        if !haskey(plotattributes, :colorbar_title)
            if haskey(header(img), "UNIT")
                colorbar_title = string(img[:UNIT])
            elseif haskey(header(img), "BUNIT")
                colorbar_title = string(img[:BUNIT])
            end
        end

        subplot_i += 1
        @series begin
            subplot := subplot_i
            aspect_ratio := :none
            colorbar := false
            cbimg, cbticks = imview_colorbar(img; clims, stretch, cmap, contrast, bias)
            xticks := []
            ymirror := true
            yticks := cbticks
            yguide := colorbar_title
            xguide := ""
            xlims := Tuple(extrema(axes(cbimg, 2)))
            ylims := Tuple(extrema(axes(cbimg, 1)))
            title := ""
            # Views of images are not currently supported by plotly so we have to collect them
            # view(cbimg, reverse(axes(cbimg,1)),:)
            cbimg[reverse(axes(cbimg, 1)), :]
        end
    end


    # TODO: refactor to reduce duplication
    if T <: Complex
        img = angle.(data)
        img["UNIT"] = "angle (rad)"
        imgv = imview(img, clims = (-1pi, 1pi), stretch = identity, cmap = :cyclic_mygbm_30_95_c78_n256_s25)
        @series begin
            subplot_i += 1
            subplot := subplot_i
            colorbar := false
            title := ""
            aspect_ratio --> 1


            # Note: if the axes are on unusual sides (e.g. y-axis at right, x-axis at top)
            # then these coordinates are not correct. They are only correct exactly
            # along the axis.
            # In astropy, the ticks are actually tilted to reflect this, though in general
            # the transformation from pixel to coordinates can be non-linear and curved.

            if showwcsticks
                xticks --> (gridspec.tickpos1x, wcslabels(wcs(imgv, wcsn), wcsax(imgv, dims(imgv, 1)), gridspec.tickpos1w))
                xguide --> ctype_label(wcs(imgv, wcsn).ctype[wcsax(imgv, dims(imgv, 1))], wcs(imgv, wcsn).radesys)

                yticks --> (gridspec.tickpos2x, wcslabels(wcs(imgv, wcsn), wcsax(imgv, dims(imgv, 2)), gridspec.tickpos2w))
                yguide --> ctype_label(wcs(imgv, wcsn).ctype[wcsax(imgv, dims(imgv, 2))], wcs(imgv, wcsn).radesys)
            end

            ax1 = collect(parent(dims(imgv, 1))) .* platescale
            ax2 = collect(parent(dims(imgv, 2))) .* platescale
            # Views of images are not currently supported by plotly() so we have to collect them.
            # ax1, ax2, view(parent(imgv), reverse(axes(imgv,1)),:)
            ax1, ax2, parent(imgv)[reverse(axes(imgv, 1)), :]
        end

        if showcolorbar
            colorbar_title = get(plotattributes, :colorbar_title, "")
            if !haskey(plotattributes, :colorbar_title) && haskey(header(img), "UNIT")
                colorbar_title = string(img[:UNIT])
            end


            @series begin
                subplot_i += 1
                subplot := subplot_i
                aspect_ratio := :none
                colorbar := false
                cbimg, _ = imview_colorbar(img; stretch = identity, clims = (-pi, pi), cmap = :cyclic_mygbm_30_95_c78_n256_s25)
                xticks := []
                ymirror := true
                ax = axes(cbimg, 1)
                yticks := ([first(ax), mean(ax), last(ax)], ["-π", "0", "π"])
                yguide := colorbar_title
                xguide := ""
                xlims := Tuple(extrema(axes(cbimg, 2)))
                ylims := Tuple(extrema(axes(cbimg, 1)))
                title := ""
                view(cbimg, reverse(axes(cbimg, 1)), :)
            end
        end

    end


    return
end


"""
    implot(
        img::AbstractArray;
        clims=Percent(99.5),
        stretch=identity,
        cmap=:magma,
        bias=0.5,
        contrast=1,
        wcsticks=true,
        grid=true,
        platescale=1
    )

Create a read only view of an array or AstroImageMat mapping its data values
to an array of Colors. Equivalent to:

    implot(
        imview(
            img::AbstractArray;
            clims=Percent(99.5),
            stretch=identity,
            cmap=:magma,
            bias=0.5,
            contrast=1,
        ),
        wcsn=' ',
        wcsticks=true,
        wcstitle=true,
        grid=true,
        platescale=1
    )

### Image Rendering
See `imview` for how data is mapped to RGBA pixel values.

### WCS & Image Coordinates
If provided with an AstroImage that has WCS headers set, the tick marks and plot grid
are calculated using FITSWCS.jl. By default, use the primary WCS coordinate system.
The underlying pixel coordinates are those returned by `dims(img)` multiplied by `platescale`.
This allows you to overplot lines, regions, etc. using pixel coordinates.
If you wish to compute the pixel coordinate of a point in world coordinates, see `world_to_pixel`.

* `wcsn` (default `' '`) select which WCS transform in the headers to use for ticks & grid,
  by version character (`' '` for the primary system, `'A'`–`'Z'` for alternates)
* `wcsticks` (default `true` if WCS headers present) display ticks and labels, and title
  using world coordinates
* `wcstitle` (default `true` if WCS headers present and `length(refdims(img))>0`). When
  slicing a cube, display the location along unseen axes in world coordinates instead of
  pixel coordinates.
* `grid` (default `true`) show a grid over the plot. Uses WCS coordinates if `wcsticks`
  is true, otherwise pixel coordinates multiplied by `platescale`.
* `platescale` (default `1`). Scales the underlying pixel coordinates to ease overplotting,
  etc. If `wcsticks` is false, the displayed pixel coordinates are also scaled.


### Defaults
The default values of `clims`, `stretch`, and `cmap` are `extrema`, `identity`, and `nothing`
respectively.
You may alter these defaults using `AstroImages.set_clims!`,  `AstroImages.set_stretch!`, and
`AstroImages.set_cmap!`.
"""
implot

# Recipe for a WCSGrid with lines, optional ticks (on by default),
# and optional grid labels (off by defaut).
# The AstroImageMat plotrecipe uses this recipe for grid lines if `grid=true`.
@recipe function f(wcsg::WCSGrid, gridspec = wcsgridspec(wcsg))
    label --> ""
    xs, ys = wcsgridlines(gridspec)

    if haskey(plotattributes, :foreground_color_grid)
        color --> plotattributes[:foreground_color_grid]
    elseif haskey(plotattributes, :foreground_color)
        color --> plotattributes[:foreground_color]
    else
        color --> :black
    end
    if haskey(plotattributes, :foreground_color_text)
        textcolor = plotattributes[:foreground_color_text]
    else
        textcolor = plotattributes[:color]
    end
    annotate = haskey(plotattributes, :gridlabels) && plotattributes[:gridlabels]

    xguide --> ctype_label(wcs(wcsg.img, wcsg.wcsn).ctype[wcsax(wcsg.img, dims(wcsg.img, 1))], wcs(wcsg.img, wcsg.wcsn).radesys)
    yguide --> ctype_label(wcs(wcsg.img, wcsg.wcsn).ctype[wcsax(wcsg.img, dims(wcsg.img, 2))], wcs(wcsg.img, wcsg.wcsn).radesys)

    xlims --> wcsg.extent[1], wcsg.extent[2]
    ylims --> wcsg.extent[3], wcsg.extent[4]

    grid := false
    tickdirection := :none

    xticks --> wcsticks(wcsg, 1, gridspec)
    yticks --> wcsticks(wcsg, 2, gridspec)

    @series xs, ys

    # We can optionally annotate the grid with their coordinates.
    # These come after the grid lines so they appear overtop.
    if annotate
        @series begin
            # TODO: why is this reverse necessary?
            rotations = reverse(rad2deg.(gridspec.annotations1θ))
            ticklabels = wcslabels(wcs(wcsg.img), 1, gridspec.annotations1w)
            seriestype := :line
            linewidth := 0
            # TODO: we need to use requires to load in Plots for the necessary text control. Future versions of RecipesBase might fix this.
            series_annotations := [
                Main.Plots.text(" $l", :right, :bottom, textcolor, 8, rotation = (-95 <= r <= 95) ? r : r + 180)
                    for (l, r) in zip(ticklabels, rotations)
            ]
            gridspec.annotations1x, gridspec.annotations1y
        end
        @series begin
            rotations = rad2deg.(gridspec.annotations2θ)
            ticklabels = wcslabels(wcs(wcsg.img), 2, gridspec.annotations2w)
            seriestype := :line
            linewidth := 0
            series_annotations := [
                Main.Plots.text(" $l", :right, :bottom, textcolor, 8, rotation = (-95 <= r <= 95) ? r : r + 180)
                    for (l, r) in zip(ticklabels, rotations)
            ]
            gridspec.annotations2x, gridspec.annotations2y
        end

    end

    return
end


@userplot PolQuiver
@recipe function f(h::PolQuiver)
    cube = only(h.args)
    bins = get(plotattributes, :bins, 4)
    ticklen = get(plotattributes, :ticklen, nothing)
    minpol = get(plotattributes, :minpol, 0.1)

    i = cube[Pol = At(:I)]
    q = cube[Pol = At(:Q)]
    u = cube[Pol = At(:U)]
    polinten = @. sqrt(q^2 + u^2)
    linpolfrac = polinten ./ i

    binratio = 1 / bins
    xs = imresize([x for x in dims(cube, 1), y in dims(cube, 2)], ratio = binratio)
    ys = imresize([y for x in dims(cube, 1), y in dims(cube, 2)], ratio = binratio)
    qx = imresize(q, ratio = binratio)
    qy = imresize(u, ratio = binratio)
    qlinpolfrac = imresize(linpolfrac, ratio = binratio)
    qpolintenr = imresize(polinten, ratio = binratio)


    # We want the longest ticks to be around 1 bin long by default.
    qmaxlen = quantile(filter(isfinite, qpolintenr), 0.98)
    if isnothing(ticklen)
        a = bins / qmaxlen
    else
        a = ticklen / qmaxlen
    end
    # Only show arrows where the data is finite, and more than a couple pixels
    # long.
    mask = (isfinite.(qpolintenr)) .& (qpolintenr .>= minpol .* qmaxlen)
    pointstmp = map(xs[mask], ys[mask], qx[mask], qy[mask]) do x, y, qxi, qyi
        return ([x, x + a * qxi, NaN], [y, y + a * qyi, NaN])
    end
    xs = reduce(vcat, getindex.(pointstmp, 1))
    ys = reduce(vcat, getindex.(pointstmp, 2))

    colors = qlinpolfrac[mask]
    if !isnothing(colors)
        line_z := repeat(colors, inner = 3)
    end

    label --> ""
    color --> :turbo
    framestyle --> :box
    aspect_ratio --> 1
    linewidth --> 1.5
    colorbar --> true
    colorbar_title --> "Linear polarization fraction"

    xl = first(dims(i, 2)), last(dims(i, 2))
    yl = first(dims(i, 1)), last(dims(i, 1))
    ylims --> yl
    xlims --> xl

    @series begin
        xs, ys
    end
end

"""
    polquiver(polqube::AstroImage)

Given a data cube (of at least 2 spatial dimensions, plus a polarization axis),
plot a vector field of polarization data.
The tick length represents the polarization intensity, sqrt(q^2 + u^2),
and the color represents the linear polarization fraction, sqrt(q^2 + u^2) / i.

There are several ways you can adjust the appearance of the plot using keyword arguments:
* `bins` (default = 1) By how much should we bin down the polarization data
  before drawing the ticks? This reduced clutter from higher resolution datasets.
  Can be fractional.
* `ticklen` (default = bins) How long the 98th percentile arrow should be. By default, 1 bin long.
  Make this larger to draw longer arrows.
* `color` (default = :turbo) What colorscheme should be used for linear polarization fraction.
* `minpol` (default = 0.2) Hides arrows that are shorter than `minpol` times the 98th percentile
  arrow to make a cleaner image. Set to 0 to display all data.

Use `implot` and `polquiver!` to overplot polarization data over an image.
"""
polquiver
