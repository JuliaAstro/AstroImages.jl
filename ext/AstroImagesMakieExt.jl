# Makie plotting extension for AstroImages.jl.
#
# Implements `implot`/`implot!` and `polquiver`/`polquiver!` as Makie recipes
# (requires Makie 0.25+, i.e. the compute-graph recipe API).
#
# Unlike the old Plots.jl recipe, images are *not* pre-rendered to RGBA with
# `imview`. Instead the raw data is passed through Makie's colormapping
# pipeline: `clims` become `colorrange`, `stretch` becomes a `colorscale`
# (a `ReversibleScale` applied to the clims-normalized value, matching the
# DS9/`imview` convention), and `contrast`/`bias` are folded into a resampled
# colormap. This means `Makie.Colorbar(fig[1, 2], plt)` works natively and
# shows data values with correctly-placed ticks under non-linear stretches.
module AstroImagesMakieExt

using AstroImages
using Makie
using Makie: automatic, Automatic, ReversibleScale, DataAspect, Point2f

using AstroImages: AstroImageMat, WCSGrid, wcsgridspec, wcsgridlines, wcslabels, wcsax,
    ctype_label, _resolve_clims, _default_clims, _default_stretch, _default_cmap,
    _stokes_name, _stokes_symbol, Colorant
using AstroImages.DimensionalData: name
using AstroImages.Statistics: mean, quantile
using AstroImages.Printf: @sprintf
import AstroImages: implot, implot!, polquiver, polquiver!

# ---------------------------------------------------------------------------
# Colormapping helpers: translate the imview clims/stretch/cmap/contrast/bias
# pipeline into Makie colorrange/colorscale/colormap.
# ---------------------------------------------------------------------------

# Inverses of the stretch functions exported by AstroImages (each maps [0,1]
# back to [0,1]); used to build ReversibleScales so Colorbar can place ticks.
stretchinverse(::typeof(identity)) = identity
stretchinverse(::typeof(logstretch)) = y -> expm1(y * log(1000)) / 1000
stretchinverse(::typeof(powstretch)) = y -> log1p(1000 * y) / log(1000)
stretchinverse(::typeof(sqrtstretch)) = y -> y^2
stretchinverse(::typeof(squarestretch)) = sqrt
stretchinverse(::typeof(asinhstretch)) = y -> sinh(3y) / 10
stretchinverse(::typeof(sinhstretch)) = y -> asinh(10y) / 3
stretchinverse(::typeof(powerdiststretch)) = y -> log1p(999 * y) / log(1000)
stretchinverse(::Any) = nothing

# Apply `stretch` to the clims-normalized (and clamped) value, following the
# SAO DS9 / `imview` convention. Note this differs from passing e.g. a log
# scale directly as `colorscale`, which Makie would apply to the raw data.
struct NormStretch{F} <: Function
    stretch::F
    lo::Float64
    hi::Float64
end
(s::NormStretch)(x) = s.stretch(clamp((x - s.lo) / (s.hi - s.lo), 0.0, 1.0))

struct InvNormStretch{F} <: Function
    invstretch::F
    lo::Float64
    hi::Float64
end
(s::InvNormStretch)(y) = s.lo + (s.hi - s.lo) * s.invstretch(y)

function stretchscale(stretch, lo, hi)
    stretch isa Automatic && (stretch = _default_stretch[])
    stretch === identity && return identity
    limits = (lo, hi)
    if stretch isa ReversibleScale
        # Re-normalize a Makie scale (e.g. Makie.LuptonAsinhScale()) to the
        # clims interval so it behaves like the other stretches.
        return ReversibleScale(
            NormStretch(stretch.forward, lo, hi), InvNormStretch(stretch.inverse, lo, hi);
            limits, name = stretch.name
        )
    end
    fwd = NormStretch(stretch, lo, hi)
    inv = stretchinverse(stretch)
    if isnothing(inv)
        # Still usable for plotting, but Colorbar won't be able to invert it
        # to place ticks.
        return fwd
    end
    return ReversibleScale(fwd, InvNormStretch(inv, lo, hi); limits, name = Symbol(stretch))
end

function resolvedcolorrange(data, clims)
    clims isa Automatic && (clims = _default_clims[])
    lo, hi = Float64.(_resolve_clims(data, clims))
    if !(hi > lo) # degenerate or empty data guard
        lo, hi = lo - 0.5, lo + 0.5
    end
    return (lo, hi)
end

# Resolve the AstroImages `cmap` (Symbol / colorant / ColorScheme / nothing)
# to a Makie colormap, folding in the DS9-style contrast/bias parameters by
# resampling: imview colors a stretched value s with cmap[(s-bias)*contrast+0.5].
function adjustedcolormap(cmap, contrast, bias)
    cmap isa Automatic && (cmap = _default_cmap[])
    isnothing(cmap) && (cmap = :grays)
    cmap isa AstroImages.ColorSchemes.ColorScheme && (cmap = cmap.colors)
    base = Makie.to_colormap(cmap)
    (contrast == 1 && bias == 0.5) && return base
    cg = Makie.cgrad(base)
    ts = clamp.((range(0, 1, length = length(base)) .- bias) .* contrast .+ 0.5, 0, 1)
    return Makie.to_colormap([cg[t] for t in ts])
end

# Convert image data to a plain Float32 matrix Makie can colormap, mapping
# missing to NaN (rendered as `nan_color`, matching imview).
plotdata(data::AbstractMatrix{<:Real}) = Float32.(data)
plotdata(data::AbstractMatrix) = Float32[ismissing(x) ? NaN32 : Float32(x) for x in data]
plotdata(data::AbstractMatrix{<:Colorant}) = collect(data)

# Pixel-centered extent of the image in (possibly platescale-multiplied)
# pixel coordinates: (xmin, xmax, ymin, ymax).
function imgextent(img, platescale = 1)
    d1, d2 = dims(img, 1), dims(img, 2)
    return (first(d1) - 0.5, last(d1) + 0.5, first(d2) - 0.5, last(d2) + 0.5) .* platescale
end

haswcsaxes(img, wcsn) = !all(==(""), wcs(img, wcsn).ctype)

# ---------------------------------------------------------------------------
# implot recipe
# ---------------------------------------------------------------------------

"""
Display an `AstroImage` with Makie, with support for astronomical image
rendering (clims/stretch/colormap) and world coordinate system (WCS) axes.

See the AstroImages.jl documentation for details.
"""
@recipe ImPlot (img::AstroImageMat,) begin
    "Color limits: a (lo, hi) tuple or a callable like `Percent(99.5)` or `Zscale()` applied to the finite data values."
    clims = automatic
    "Monotonic function applied to the clims-normalized data, e.g. `asinhstretch` or `logstretch`."
    stretch = automatic
    "Colormap: any Makie colormap, ColorScheme, or colorant. `nothing` for grayscale."
    cmap = automatic
    "DS9-style colormap contrast."
    contrast = 1.0
    "DS9-style colormap bias."
    bias = 0.5
    "Which WCS transform in the headers to use (`' '` primary, `'A'`-`'Z'` alternates)."
    wcsn = ' '
    "Display ticks, labels, and title in world coordinates (applies when the Axis is created by this plot)."
    wcsticks = true
    "When slicing a cube, display the location along unseen axes in the axis title."
    wcstitle = true
    "Overplot the (possibly curved) WCS coordinate grid. `automatic`: on when WCS headers are present."
    wcsgrid = automatic
    "Color of the WCS grid lines."
    gridcolor = :lightgray
    "Line width of the WCS grid lines."
    gridwidth = 1.0
    "Scale the underlying pixel coordinates to ease overplotting."
    platescale = 1.0
    "Sets whether colors should be interpolated between pixels."
    interpolate = false
    "The color for NaN and missing pixels."
    nan_color = :transparent
    "The color for any value below the color range."
    lowclip = automatic
    "The color for any value above the color range."
    highclip = automatic
    "The alpha value of the colormap."
    alpha = 1.0
    Makie.mixin_generic_plot_attributes()...
end

Makie.convert_arguments(::Type{<:ImPlot}, img::AbstractMatrix) = (AstroImage(img),)
function Makie.convert_arguments(::Type{<:ImPlot}, img::AbstractArray)
    throw(ArgumentError("`implot` requires a two-dimensional image. Got ndims=$(ndims(img)). Slice the cube first, e.g. `implot(cube[:, :, 1])`."))
end

Makie.plottype(::AstroImageMat) = ImPlot

# Common compute nodes shared by the plot! methods.
function registerextents!(p)
    return map!(p.attributes, [:img, :platescale], [:xext, :yext]) do img, platescale
        ext = imgextent(img, platescale)
        return ((ext[1], ext[2]), (ext[3], ext[4]))
    end
end

# Overplot the WCS coordinate grid as (possibly curved) lines in pixel coords.
function wcsgridoverlay!(p)
    attr = p.attributes
    map!(attr, [:img, :wcsn, :wcsgrid, :platescale], [:gridpoints, :gridvisible]) do img, wcsn, wcsgrid, platescale
        show = wcsgrid isa Automatic ? haswcsaxes(img, wcsn) : (wcsgrid && haswcsaxes(img, wcsn))
        show || return (Point2f[], false)
        gs = wcsgridspec(WCSGrid(img, Float64.(imgextent(img)), wcsn))
        xs, ys = wcsgridlines(gs)
        return (Point2f.(xs .* platescale, ys .* platescale), true)
    end
    lines!(
        p, p.gridpoints;
        color = p.gridcolor, linewidth = p.gridwidth, visible = p.gridvisible,
        inspectable = false,
    )
    return
end

function Makie.plot!(p::ImPlot{<:Tuple{<:AstroImageMat{<:Union{Real, Missing}}}})
    attr = p.attributes
    registerextents!(p)
    map!(img -> plotdata(parent(img)), attr, :img, :rawdata)
    map!(attr, [:img, :clims], :computed_colorrange) do img, clims
        return resolvedcolorrange(parent(img), clims)
    end
    map!(attr, [:stretch, :computed_colorrange], :computed_colorscale) do stretch, crange
        return stretchscale(stretch, crange...)
    end
    map!(adjustedcolormap, attr, [:cmap, :contrast, :bias], :computed_colormap)
    image!(
        p, p.attributes, p.xext, p.yext, p.rawdata;
        colormap = p.computed_colormap,
        colorrange = p.computed_colorrange,
        colorscale = p.computed_colorscale,
    )
    wcsgridoverlay!(p)
    return p
end

# Colorant-valued images (e.g. from imview or composecolors) are displayed
# directly without colormapping.
function Makie.plot!(p::ImPlot{<:Tuple{<:AstroImageMat{<:Colorant}}})
    registerextents!(p)
    map!(img -> plotdata(parent(img)), p.attributes, :img, :rawdata)
    image!(p, p.attributes, p.xext, p.yext, p.rawdata)
    wcsgridoverlay!(p)
    return p
end

# Tell Colorbar which of our compute nodes hold the colormapping, so that
# `Makie.Colorbar(fig[1, 2], plt)` works on the recipe as a whole (it cannot
# choose automatically between the image and grid-line children).
function Makie._extract_colormap(p::ImPlot{<:Tuple{<:AstroImageMat{<:Union{Real, Missing}}}})
    return Dict{Symbol, Any}(
        :color => p.rawdata,
        :colormap => p.computed_colormap,
        :colorrange => p.computed_colorrange,
        :colorscale => p.computed_colorscale,
        :lowclip => p.lowclip,
        :highclip => p.highclip,
    )
end

function Makie.plot!(::ImPlot{<:Tuple{<:AstroImageMat{<:Complex}}})
    throw(
        ArgumentError(
            "`implot` of complex-valued images is not supported with Makie yet. " *
                "Plot the magnitude and phase separately, e.g. `implot(abs.(img))` and `implot(angle.(img), clims=(-pi, pi))`."
        )
    )
end

# ---------------------------------------------------------------------------
# Axis integration: when implot creates the Axis, configure it with WCS
# ticks, labels, title, and tight, aspect-correct limits.
# ---------------------------------------------------------------------------

# Attribute access on a partially initialized plot, with fallback.
function plotattr(p, s::Symbol, default)
    return try
        x = getproperty(p, s)[]
        x isa Automatic ? default : x
    catch
        default
    end
end

# Describe our position along sliced-away dimensions (matches the Plots recipe).
function refdimstitle(img, wcsn, usewcs)
    return join(
        map(refdims(img)) do d
            if usewcs
                i = wcsax(img, d)
                w = wcs(img, wcsn)
                ct = w.ctype[i]
                label = ctype_label(ct, w.radesys)
                if label == "NONE"
                    label = string(name(d))
                end
                value = pixel_to_world(img, [1, 1]; wcsn, all = true, parent = true)[i]
                if ct == "STOKES"
                    return _stokes_name(_stokes_symbol(value))
                else
                    return @sprintf("%s = %.5g %s", label, value, w.cunit[i])
                end
            else
                return "$(name(d))= $(d[1])"
            end
        end, ", "
    )
end

function Makie.preferred_axis_attributes(::Type{Makie.Axis}, p::ImPlot, img)
    if !(img isa AstroImageMat)
        img isa AbstractMatrix || return NamedTuple()
        img = AstroImage(img)
    end
    return wcsaxisattributes(
        img;
        wcsn = plotattr(p, :wcsn, ' '),
        platescale = plotattr(p, :platescale, 1),
        wcsticks = plotattr(p, :wcsticks, true),
        wcstitle = plotattr(p, :wcstitle, true),
    )
end

# Axis attributes (ticks, labels, title, limits, aspect) appropriate for
# displaying `img`. Usable directly for manually created axes:
# `Axis(fig[1, 1]; AstroImagesMakieExt.wcsaxisattributes(img)...)`.
function wcsaxisattributes(img::AstroImageMat; wcsn = ' ', platescale = 1, wcsticks = true, wcstitle = true)
    haswcs = haswcsaxes(img, wcsn)
    showticks = wcsticks && haswcs
    showtitle = wcstitle && haswcs && !isempty(refdims(img))

    extent = Float64.(imgextent(img))
    attrs = Dict{Symbol, Any}(
        :limits => ((extent[1], extent[2]) .* platescale, (extent[3], extent[4]) .* platescale),
    )
    # Equal data aspect, except when the axes have wildly different scales.
    ratio = (extent[2] - extent[1]) / (extent[4] - extent[3])
    if 1 / 7 < ratio < 7
        attrs[:aspect] = DataAspect()
    end
    if !isempty(refdims(img))
        attrs[:title] = refdimstitle(img, wcsn, showtitle)
    end
    if showticks
        gs = wcsgridspec(WCSGrid(img, extent, wcsn))
        w = wcs(img, wcsn)
        ax1, ax2 = wcsax(img, dims(img, 1)), wcsax(img, dims(img, 2))
        if !isempty(gs.tickpos1x)
            attrs[:xticks] = (gs.tickpos1x .* platescale, wcslabels(w, ax1, gs.tickpos1w))
        end
        if !isempty(gs.tickpos2x)
            attrs[:yticks] = (gs.tickpos2x .* platescale, wcslabels(w, ax2, gs.tickpos2w))
        end
        attrs[:xlabel] = ctype_label(w.ctype[ax1], w.radesys)
        attrs[:ylabel] = ctype_label(w.ctype[ax2], w.radesys)
        # The straight Axis grid would be drawn at the tick positions; the
        # correct (possibly curved) WCS grid is overplotted by the recipe.
        attrs[:xgridvisible] = false
        attrs[:ygridvisible] = false
    end
    return attrs
end

# ---------------------------------------------------------------------------
# ImPlotView: a complex recipe block (new in Makie 0.25) bundling an Axis with
# WCS ticks and a Colorbar — what the Plots.jl recipe approximated with
# @layout. Usage: `fig, iv = ImPlotView(img)` or `ImPlotView(fig[1, 1], img)`.
# ---------------------------------------------------------------------------

@Block ImPlotView (img,) begin
    @attributes begin
        "Color limits, see `implot`."
        clims = automatic
        "Stretch function, see `implot`."
        stretch = automatic
        "Colormap, see `implot`."
        cmap = automatic
        "DS9-style colormap contrast."
        contrast = 1.0
        "DS9-style colormap bias."
        bias = 0.5
        "Which WCS transform in the headers to use."
        wcsn = ' '
        "Display ticks, labels, and title in world coordinates."
        wcsticks = true
        "Display the location along sliced-away axes in the title."
        wcstitle = true
        "Overplot the WCS coordinate grid."
        wcsgrid = automatic
        "Color of the WCS grid lines."
        gridcolor = :lightgray
        "Scale the underlying pixel coordinates."
        platescale = 1.0
        "Interpolate colors between pixels."
        interpolate = false
        "Display a colorbar."
        colorbar = true
        "Colorbar label. Defaults to the UNIT/BUNIT header if present."
        colorbar_label = automatic
    end
end

function Makie.convert_arguments(::Type{<:ImPlotView}, img::AbstractMatrix)
    return (img isa AstroImageMat ? img : AstroImage(img),)
end

function Makie.initialize_block!(bl::ImPlotView)
    img = bl.img[]
    axattrs = wcsaxisattributes(
        img;
        wcsn = bl.wcsn[], platescale = bl.platescale[],
        wcsticks = bl.wcsticks[], wcstitle = bl.wcstitle[],
    )
    ax = Makie.Axis(bl[1, 1]; axattrs...)
    plt = implot!(
        ax, bl.img;
        clims = bl.clims, stretch = bl.stretch, cmap = bl.cmap,
        contrast = bl.contrast, bias = bl.bias, wcsn = bl.wcsn,
        wcsgrid = bl.wcsgrid, gridcolor = bl.gridcolor,
        platescale = bl.platescale, interpolate = bl.interpolate,
    )
    if bl.colorbar[] && !(eltype(img) <: Colorant)
        label = bl.colorbar_label[]
        if label isa Automatic
            label = string(something(img["UNIT"], img["BUNIT"], ""))
        end
        Makie.Colorbar(bl[1, 2], plt; label)
    end
    return
end

# ---------------------------------------------------------------------------
# polquiver recipe
# ---------------------------------------------------------------------------

# Block-average (bin down) a matrix by an integer factor. NaNs propagate.
function blockmean(A::AbstractMatrix, b::Int)
    b <= 1 && return float.(collect(A))
    m, n = cld.(size(A), b)
    out = Matrix{Float64}(undef, m, n)
    for j in 1:n, i in 1:m
        is = ((i - 1) * b + 1):min(i * b, size(A, 1))
        js = ((j - 1) * b + 1):min(j * b, size(A, 2))
        out[i, j] = mean(float(A[i′, j′]) for i′ in is, j′ in js)
    end
    return out
end

"""
Plot a vector field of linear polarization data from a cube with a `Pol` axis
holding at least the `:I`, `:Q`, and `:U` Stokes parameters.

See the AstroImages.jl documentation for details.
"""
@recipe PolQuiver (cube::AstroImage{<:Any, 3},) begin
    "Bin the polarization data down by this factor before drawing the segments."
    bins = 4
    "Length of the 98th-percentile segment, in pixels. Defaults to `bins`."
    ticklen = automatic
    "Hide segments shorter than `minpol` times the 98th-percentile intensity."
    minpol = 0.1
    "Colormap for the linear polarization fraction."
    colormap = :turbo
    "Line width of the segments."
    linewidth = 1.5
    Makie.mixin_generic_plot_attributes()...
end

function Makie.plot!(p::PolQuiver)
    attr = p.attributes
    map!(attr, [:cube, :bins, :ticklen, :minpol], [:segments, :segcolors]) do cube, bins, ticklen, minpol
        i = cube[Pol = At(:I)]
        q = cube[Pol = At(:Q)]
        u = cube[Pol = At(:U)]
        polinten = @. sqrt(q^2 + u^2)
        linpolfrac = polinten ./ i

        b = max(1, round(Int, bins))
        xs = blockmean([float(x) for x in dims(cube, 1), _ in dims(cube, 2)], b)
        ys = blockmean([float(y) for _ in dims(cube, 1), y in dims(cube, 2)], b)
        qx = blockmean(parent(q), b)
        qy = blockmean(parent(u), b)
        qlinpolfrac = blockmean(parent(linpolfrac), b)
        qpolinten = blockmean(parent(polinten), b)

        # By default the longest segments are about one bin long.
        qmaxlen = quantile(filter(isfinite, vec(qpolinten)), 0.98)
        a = (ticklen isa Automatic ? b : ticklen) / qmaxlen
        # Only show segments where the data is finite and long enough.
        mask = isfinite.(qpolinten) .& (qpolinten .>= minpol .* qmaxlen)

        segments = Point2f[]
        colors = Float32[]
        for (x, y, qxi, qyi, c) in zip(xs[mask], ys[mask], qx[mask], qy[mask], qlinpolfrac[mask])
            push!(segments, Point2f(x, y), Point2f(x + a * qxi, y + a * qyi))
            push!(colors, c, c)
        end
        return (segments, colors)
    end
    linesegments!(p, p.attributes, p.segments; color = p.segcolors)
    return p
end

end # module
