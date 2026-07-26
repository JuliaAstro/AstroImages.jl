using AstroImages
using AstroImages: AstroImage
using AstroImages.DimensionalData: X, Y
using FITSWCS: WCS
using Makie
using Statistics
using Test

# These cover ext/AstroImagesMakieExt.jl. Makie figures are constructed and
# laid out but never rasterized, so no backend (CairoMakie/GLMakie) is needed.
const MExt = Base.get_extension(AstroImages, :AstroImagesMakieExt)

wcsimg(ny = 10, nx = 10) = AstroImage(randn(ny, nx), WCS(2; ctype = ["RA---AIR", "DEC--AIR"]))

@testset "makie: colormapping helpers" begin
    @testset "stretch inverses" begin
        for st in (logstretch, powstretch, sqrtstretch, squarestretch, asinhstretch, sinhstretch, powerdiststretch)
            inv = MExt.stretchinverse(st)
            for x in (0.0, 0.25, 0.5, 0.9, 1.0)
                @test inv(st(x)) ≈ x atol = 1.0e-8
            end
        end
        @test MExt.stretchinverse(identity) === identity
        @test isnothing(MExt.stretchinverse(x -> x^3))
    end

    @testset "stretchscale" begin
        @test MExt.stretchscale(identity, 0.0, 1.0) === identity
        # default stretch is identity
        @test MExt.stretchscale(Makie.automatic, 0.0, 1.0) === identity

        s = MExt.stretchscale(asinhstretch, 2.0, 4.0)
        @test s isa Makie.ReversibleScale
        @test s.forward(2.0) ≈ 0 atol = 1.0e-8
        @test s.inverse(s.forward(3.0)) ≈ 3.0
        # values outside the clims interval clamp to its ends
        @test s.forward(5.0) == s.forward(4.0)
        @test s.forward(1.0) == s.forward(2.0)

        # a Makie ReversibleScale is re-normalized to the clims interval
        rs = Makie.ReversibleScale(sqrt, x -> x^2; limits = (0.0, 1.0), name = :sqrt)
        s2 = MExt.stretchscale(rs, 0.0, 2.0)
        @test s2 isa Makie.ReversibleScale
        @test s2.forward(2.0) ≈ 1.0
        @test s2.inverse(s2.forward(0.5)) ≈ 0.5

        # a stretch with no known inverse still works for plotting, it is
        # just not a ReversibleScale (Colorbar cannot invert it)
        s3 = MExt.stretchscale(x -> x^3, 0.0, 2.0)
        @test !(s3 isa Makie.ReversibleScale)
        @test s3(1.0) ≈ 0.125
    end

    @testset "resolvedcolorrange" begin
        data = [1.0 2.0; 3.0 4.0]
        @test MExt.resolvedcolorrange(data, (2, 3)) == (2.0, 3.0)
        lo, hi = MExt.resolvedcolorrange(data, Makie.automatic) # default Percent(99.5)
        @test lo < hi
        lo, hi = MExt.resolvedcolorrange(data, Zscale())
        @test lo < hi
        # degenerate (constant) data still yields a valid range
        @test MExt.resolvedcolorrange(fill(3.0, 4, 4), (3, 3)) == (2.5, 3.5)
    end

    @testset "adjustedcolormap" begin
        base = MExt.adjustedcolormap(:viridis, 1.0, 0.5)
        @test base == Makie.to_colormap(:viridis)
        @test MExt.adjustedcolormap(nothing, 1.0, 0.5) == Makie.to_colormap(:grays)
        @test !isempty(MExt.adjustedcolormap(Makie.automatic, 1.0, 0.5))
        cs = AstroImages.ColorSchemes.viridis
        @test MExt.adjustedcolormap(cs, 1.0, 0.5) == Makie.to_colormap(cs.colors)
        # contrast/bias resample the colormap without changing its length
        adj = MExt.adjustedcolormap(:viridis, 2.0, 0.7)
        @test length(adj) == length(base)
        @test adj != base
    end

    @testset "plotdata and extents" begin
        @test MExt.plotdata([1.0 2.0; 3.0 4.0]) isa Matrix{Float32}
        pd = MExt.plotdata([1.0 missing; 2.0 3.0])
        @test isnan(pd[1, 2]) && pd[2, 1] == 2.0f0
        rgba = collect(imview(randn(4, 4)))
        @test MExt.plotdata(rgba) isa AbstractMatrix{<:AstroImages.Colorant}

        img = AstroImage(randn(10, 8))
        @test MExt.imgextent(img) == (0.5, 10.5, 0.5, 8.5)
        @test MExt.imgextent(img, 2) == (1.0, 21.0, 1.0, 17.0)
        # offset dims (a slice) keep their parent pixel coordinates
        @test MExt.imgextent(AstroImage(randn(10, 8))[3:10, :]) == (2.5, 10.5, 0.5, 8.5)

        @test MExt.haswcsaxes(wcsimg(), ' ')
        @test !MExt.haswcsaxes(AstroImage(randn(4, 4)), ' ')
    end
end

@testset "makie: implot recipe" begin
    img = wcsimg()
    @test Makie.plottype(img) == MExt.ImPlot

    fig, ax, plt = implot(img)
    lo, hi = plt.computed_colorrange[]
    @test lo < hi
    @test plt.xext[] == (0.5, 10.5)
    @test plt.yext[] == (0.5, 10.5)
    # WCS headers present: grid overlay on by default
    @test plt.gridvisible[]
    @test !isempty(plt.gridpoints[])
    # the recipe-created axis gets WCS ticks and labels
    @test ax.xticks[] isa MExt.WCSTicks
    @test occursin("Right Ascension", ax.xlabel[])
    @test occursin("Declination", ax.ylabel[])
    Makie.update_state_before_display!(fig)

    # Colorbar hooks into the recipe's compute nodes (_extract_colormap)
    cb = Makie.Colorbar(fig[1, 2], plt)
    @test cb isa Makie.Colorbar

    @testset "WCSTicks" begin
        t = ax.xticks[]
        pos, labels = Makie.get_ticks(t, identity, Makie.automatic, 0.5, 10.5)
        @test length(pos) == length(labels)
        @test !isempty(pos)
        @test all(p -> 0.5 <= p <= 10.5, pos)
        @test all(!isempty, labels)
        # degenerate ranges produce no ticks
        @test Makie.get_ticks(t, identity, Makie.automatic, 5.0, 5.0) == (Float64[], String[])
        # a user-supplied formatter overrides the sexagesimal labels
        _, custom = Makie.get_ticks(ax.yticks[], identity, vs -> ["v" for _ in vs], 0.5, 10.5)
        @test all(==("v"), custom)
    end

    @testset "attribute variations" begin
        _, _, p2 = implot(img; wcsgrid = false)
        @test !p2.gridvisible[]
        _, ax3, _ = implot(img; wcsticks = false)
        @test !(ax3.xticks[] isa MExt.WCSTicks)
        _, _, p4 = implot(img; platescale = 2)
        @test p4.xext[] == (1.0, 21.0)
        _, _, p5 = implot(img; stretch = asinhstretch, cmap = :viridis, clims = (-1, 1), contrast = 1.5, bias = 0.4)
        @test p5.computed_colorrange[] == (-1.0, 1.0)
        @test p5.computed_colorscale[] isa Makie.ReversibleScale
        @test !isempty(p5.computed_colormap[])
    end

    @testset "fixed panel sizes" begin
        _, axw, _ = implot(img; width = 300)
        @test axw.width[] == 300
        @test axw.height[] == 300.0
        wide = AstroImage(randn(20, 10), WCS(2; ctype = ["RA---AIR", "DEC--AIR"]))
        _, axh, _ = implot(wide; width = 300)
        @test axh.height[] == 150.0
    end

    @testset "input handling" begin
        # plain matrices are wrapped in AstroImage; pixel ticks, no WCS grid
        _, axm, pm = implot(randn(6, 4))
        @test pm.img[] isa AstroImage
        @test size(pm.img[]) == (6, 4)
        @test !pm.gridvisible[]
        @test !(axm.xticks[] isa MExt.WCSTicks)
        # colorant-valued images are displayed as-is
        cimg = AstroImage(collect(imview(randn(8, 8))))
        _, _, pc = implot(cimg)
        @test pc isa MExt.ImPlot
        # cubes must be sliced first, complex images are not supported
        @test_throws ArgumentError implot(randn(3, 3, 3))
        @test_throws ArgumentError implot(AstroImage(fill(1.0im, 4, 4)))
        # preferred_axis_attributes on a non-image argument is a no-op
        @test Makie.preferred_axis_attributes(Makie.Axis, plt, [1.0, 2.0]) == NamedTuple()
    end
end

@testset "makie: axis attributes" begin
    img = wcsimg()
    attrs = MExt.wcsaxisattributes(img)
    @test attrs[:limits] == ((0.5, 10.5), (0.5, 10.5))
    @test attrs[:aspect] isa Makie.DataAspect
    @test attrs[:xticks] isa MExt.WCSTicks
    @test attrs[:xgridvisible] == false
    # usable directly on a manually created axis
    figm = Makie.Figure()
    axm = Makie.Axis(figm[1, 1]; attrs...)
    @test axm isa Makie.Axis

    nowcs = MExt.wcsaxisattributes(AstroImage(randn(10, 10)))
    @test !haskey(nowcs, :xticks)

    @testset "sliced cube titles" begin
        vcube = AstroImage(randn(6, 6, 3), WCS(3; ctype = ["RA---AIR", "DEC--AIR", "VRAD"]))
        slice = vcube[:, :, 2]
        attrs = MExt.wcsaxisattributes(slice)
        @test haskey(attrs, :title)
        @test occursin("=", attrs[:title])
        # wcstitle = false falls back to the dimension name and value
        plain = MExt.wcsaxisattributes(slice; wcstitle = false)
        @test occursin("=", plain[:title])

        scube = AstroImage(randn(6, 6, 2), WCS(3; ctype = ["RA---AIR", "DEC--AIR", "STOKES"], crpix = [1, 1, 1], crval = [0, 0, 1]))
        stitle = MExt.wcsaxisattributes(scube[:, :, 1])[:title]
        @test stitle == "Stokes Unpolarized" # value 1 -> :I
    end

    @testset "panel size derivation" begin
        d = Dict{Symbol, Any}(:width => 100)
        MExt.derivepanelsize!(d, (0.0, 10.0, 0.0, 5.0))
        @test d[:height] == 50.0
        d = Dict{Symbol, Any}(:height => 100)
        MExt.derivepanelsize!(d, (0.0, 10.0, 0.0, 5.0))
        @test d[:width] == 200.0
        # nothing to derive from
        @test !haskey(MExt.derivepanelsize!(Dict{Symbol, Any}(), (0.0, 1.0, 0.0, 1.0)), :width)
    end

    @testset "cellaspectratio" begin
        @test MExt.cellaspectratio(Dict{Symbol, Any}(:aspect => 2.0)) == 2.0
        @test isnothing(MExt.cellaspectratio(Dict{Symbol, Any}()))
        d = Dict{Symbol, Any}(:aspect => Makie.DataAspect(), :limits => ((0, 10), (0, 5)))
        @test MExt.cellaspectratio(d) == 2.0
        d = Dict{Symbol, Any}(:aspect => Makie.DataAspect(), :limits => (0, 10, 0, 5))
        @test MExt.cellaspectratio(d) == 2.0
        d = Dict{Symbol, Any}(:aspect => Makie.DataAspect(), :limits => ((nothing, 10), (0, 5)))
        @test isnothing(MExt.cellaspectratio(d))
        @test isnothing(MExt.cellaspectratio(Dict{Symbol, Any}(:aspect => Makie.DataAspect())))
    end
end

@testset "makie: implotview" begin
    img = wcsimg()
    fig, iv = implotview(img)
    @test iv isa MExt.ImPlotView
    @test iv.ax isa Makie.Axis
    @test iv.plt isa MExt.ImPlot
    # an unsized view keeps its cell aspect-locked to the image
    @test iv.layout.colsizes[1] isa Makie.GridLayoutBase.Aspect ||
        iv.layout.rowsizes[1] isa Makie.GridLayoutBase.Aspect
    # a colorbar is included by default
    @test any(c -> c.content isa Makie.Colorbar, iv.layout.content)

    # zooming updates the WCS grid overlay extent through finallimits
    @test iv.plt.viewextent[] isa Makie.Automatic
    Makie.limits!(iv.ax, 2, 8, 3, 7)
    @test iv.plt.viewextent[] isa NTuple{4, Float64}

    @testset "colorbar options" begin
        unitful = AstroImage(randn(6, 6))
        unitful["BUNIT"] = "Jy/beam"
        _, ivu = implotview(unitful)
        cbs = [c.content for c in ivu.layout.content if c.content isa Makie.Colorbar]
        @test length(cbs) == 1
        @test cbs[1].label[] == "Jy/beam"

        _, ivl = implotview(img; colorbar_label = "counts")
        cbs = [c.content for c in ivl.layout.content if c.content isa Makie.Colorbar]
        @test cbs[1].label[] == "counts"

        _, ivn = implotview(img; colorbar = false)
        @test !any(c -> c.content isa Makie.Colorbar, ivn.layout.content)

        # colorant-valued images have nothing to put on a colorbar
        _, ivc = implotview(AstroImage(collect(imview(randn(6, 6)))))
        @test !any(c -> c.content isa Makie.Colorbar, ivc.layout.content)
    end

    @testset "sizing" begin
        # axis overrides merge over the WCS defaults; fixing one dimension
        # derives the other from the image aspect and skips the Aspect cells
        _, ivs = implotview(img; axis = (; height = 200, title = "hi"))
        @test ivs.ax.title[] == "hi"
        @test ivs.ax.height[] == 200
        @test ivs.ax.width[] == 200.0
        @test !(ivs.layout.colsizes[1] isa Makie.GridLayoutBase.Aspect)
        @test !(ivs.layout.rowsizes[1] isa Makie.GridLayoutBase.Aspect)

        # an explicit figure size wins over the shrink-wrap
        figf, _ = implotview(img; figure = (; size = (333, 222)))
        @test Tuple(Makie.widths(Makie.viewport(figf.scene)[])) == (333, 222)

        # placing into an existing figure never resizes it
        host = Makie.Figure(size = (400, 300))
        ivp = implotview(host[1, 1], img)
        @test ivp isa MExt.ImPlotView
        @test Tuple(Makie.widths(Makie.viewport(host.scene)[])) == (400, 300)
    end
end

@testset "makie: polquiver" begin
    @testset "blockmean" begin
        A = reshape(1.0:20.0, 4, 5)
        @test MExt.blockmean(A, 1) == A
        bm = MExt.blockmean(A, 3)
        @test size(bm) == (2, 2)
        @test bm[1, 1] ≈ mean(A[1:3, 1:3])
        @test bm[2, 2] ≈ mean(A[4:4, 4:5]) # ragged tail blocks
        @test isnan(MExt.blockmean([NaN 1.0; 2.0 3.0], 2)[1, 1])
    end

    data = ones(12, 12, 3)
    data[:, :, 2] .= 0.3 # Q
    data[:, :, 3] .= 0.2 # U
    cube = AstroImage(data, (X(1:12), Y(1:12), Pol([:I, :Q, :U])))

    fig, ax, plt = polquiver(cube)
    segs = plt.segments[]
    @test !isempty(segs)
    @test length(segs) == length(plt.segcolors[])
    # a uniform field draws every segment at exactly `ticklen`
    _, _, pt = polquiver(cube; ticklen = 5.0, bins = 4)
    s = pt.segments[]
    @test hypot((s[2] - s[1])...) ≈ 5.0
    # minpol hides segments below the cutoff; in a uniform field a cutoff
    # above 1 hides everything
    _, _, pm = polquiver(cube; minpol = 2.0)
    @test isempty(pm.segments[])
end
