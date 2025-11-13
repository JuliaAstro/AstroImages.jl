using RecipesBase: apply_recipe
using AstroImages: AstroImage, ImPlot
using WCS: WCSTransform

@testset "Plot recipes" begin
    data = randn(10, 10)
    wcs1 = WCSTransform(2; ctype = ["RA---AIR", "DEC--AIR"])
    wcs2 = WCSTransform(2; ctype = ["GLON--", "GLAT--"])
    wcs3 = WCSTransform(2; ctype = ["TLON--", "TLAT--"])
    wcs4 = WCSTransform(2; ctype = ["UNK---", "UNK---"])
    wcs5 = WCSTransform(2;)

    img = AstroImage(data)
    p = ImPlot((img,))
    rec = apply_recipe(Dict{Symbol, Any}(), p)
    @test getfield(rec[1], 1) == Dict{Symbol, Any}(
        :ylims        => (0.5, 10.5),
        :grid         => false,
        :xlims        => (0.5, 10.5),
        :subplot      => 1,
        :colorbar     => false,
        :framestyle   => :box,
        :yflip        => false,
        :xflip        => false,
        :aspect_ratio => 1,
    )
    @test p.args[1].data == img.data

    img = AstroImage(data, [wcs1])
    p = ImPlot((img,))
    rec = apply_recipe(Dict{Symbol, Any}(), p)
    @test rec[1].plotattributes[:xguide] == "Right Ascension (ICRS)" && rec[1].plotattributes[:yguide] == "Declination (ICRS)"

    img = AstroImage(data, [wcs2])
    p = ImPlot((img,))
    rec = apply_recipe(Dict{Symbol, Any}(), p)
    @test rec[1].plotattributes[:xguide] == "Galactic Longitude" && rec[1].plotattributes[:yguide] == "Galactic Latitude"

    img = AstroImage(data, [wcs3])
    p = ImPlot((img,))
    rec = apply_recipe(Dict{Symbol, Any}(), p)
    @test rec[1].plotattributes[:xguide] == "ITRS" && rec[1].plotattributes[:yguide] == "TLAT--"

    img = AstroImage(data, [wcs4])
    p = ImPlot((img,))
    rec = apply_recipe(Dict{Symbol, Any}(), p)
    @test rec[1].plotattributes[:xguide] == "UNK---" && rec[1].plotattributes[:yguide] == "UNK---"

    img = AstroImage(data, [wcs5])
    p = ImPlot((img,))
    rec = apply_recipe(Dict{Symbol, Any}(), p)
    @test !haskey(rec[1].plotattributes, :xguide) && !haskey(rec[1].plotattributes, :yguide)

end

# TODO: are these needed anymore?
#@testset "formatters" begin
#    wcs1 = WCSTransform(2; ctype = ["RA---AIR", "DEC--AIR"])
#    wcs2 = WCSTransform(2; ctype = ["GLON--", "GLAT--"])
#
#    @test pix2world_xformatter(255, wcs1) == "165.58°"
#    @test pix2world_xformatter(255, wcs2) == 255.0
#
#    @test pix2world_yformatter(255, wcs1) == "13.98°"
#    @test pix2world_yformatter(255, wcs2) == 255.0
#end
