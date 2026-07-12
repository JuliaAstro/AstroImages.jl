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

@testset "component-exact tick labels" begin
    # Ticks stepping by 3°20′ change at the degree level every tick, but must
    # not be truncated to whole degrees; the exact integer decomposition also
    # avoids float fuzz like deg2dmsmμ(-46°40′) = (-46, 39, 59, 999, 999.99…).
    w = WCS(2; ctype = ["GLON-TAN", "GLAT-TAN"], cunit = ["deg", "deg"])
    labels = AstroImages.wcslabels(w, 2, [-50.0, -140 / 3, -130 / 3, -40.0])
    @test labels == ["-50°00'", "-46°40'", "-43°20'", "-40°00'"]

    # Whole-degree ticks stay compact
    @test AstroImages.wcslabels(w, 2, [-50.0, -45.0, -40.0]) == ["-50°", "-45°", "-40°"]

    # RA in hours: exact at whole seconds, fractional otherwise
    wra = WCS(2; ctype = ["RA---TAN", "DEC--TAN"], cunit = ["deg", "deg"])
    labels = AstroImages.wcslabels(wra, 1, [350.9, 350.95])
    @test labels == ["23ʰ23ᵐ36.00ˢ", "48.00ˢ"]
end

@testset "no-WCS image" begin
    img = AstroImage(randn(10, 10))
    # With no WCS headers set, all ctypes are empty: the plotting code uses
    # this to fall back to pixel coordinates.
    @test all(==(""), AstroImages.wcs(img, ' ').ctype)
end
