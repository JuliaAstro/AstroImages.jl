using AstroImages: AstroImages, AstroImage, WCSGrid, wcsgridspec, wcsgridlines, wcsticks, ctype_label
using FITSWCS: WCS
using Test

# These cover the backend-agnostic plotting machinery in src/wcs-grid.jl,
# which the Makie extension builds on (see ext/AstroImagesMakieExt.jl).

@testset "ctype axis labels" begin
    @test ctype_label("RA---AIR", "ICRS") == "Right Ascension (ICRS)"
    @test ctype_label("DEC--AIR", "ICRS") == "Declination (ICRS)"
    @test ctype_label("GLON--", "ICRS") == "Galactic Longitude"
    @test ctype_label("GLAT--", "ICRS") == "Galactic Latitude"
    @test ctype_label("TLON--", "ICRS") == "ITRS"
    @test ctype_label("TLAT--", "ICRS") == "TLAT--"
    @test ctype_label("UNK---", "ICRS") == "UNK---"
    @test ctype_label("", "ICRS") == "ICRS"
end

@testset "WCS grid lines and ticks" begin
    data = randn(10, 10)
    img = AstroImage(data, WCS(2; ctype = ["RA---AIR", "DEC--AIR"]))

    wcsg = WCSGrid(img)
    gs = wcsgridspec(wcsg)
    @test length(gs.tickpos1x) >= 2
    @test length(gs.tickpos2x) >= 2

    for axnum in (1, 2)
        pos, labels = wcsticks(wcsg, axnum, gs)
        @test length(pos) == length(labels)
        @test all(!isempty, labels)
        # Tick positions are in pixel coordinates and must lie on the axis.
        lo, hi = axnum == 1 ? wcsg.extent[1:2] : wcsg.extent[3:4]
        @test all(p -> lo <= p <= hi, pos)
    end

    # Grid lines come as a single NaN-separated series in pixel coordinates.
    xs, ys = wcsgridlines(gs)
    @test length(xs) == length(ys)
    @test any(isnan, xs)
    @test length(xs) > 10
end

@testset "no-WCS image" begin
    img = AstroImage(randn(10, 10))
    # With no WCS headers set, all ctypes are empty: the plotting code uses
    # this to fall back to pixel coordinates.
    @test all(==(""), AstroImages.wcs(img, ' ').ctype)
end
