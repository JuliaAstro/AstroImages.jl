using RecipesBase: apply_recipe
using AstroImages: AstroImage, ImPlot
using WCS: WCSTransform

@testset "Plot recipes" begin
    data = randn(10, 10)
    img = AstroImage(data)
    p = ImPlot((img,))
    wcs1 = WCSTransform(2; ctype = ["RA---AIR", "DEC--AIR"])
    wcs2 = WCSTransform(2; ctype = ["GLON--", "GLAT--"])
    wcs3 = WCSTransform(2; ctype = ["TLON--", "TLAT--"])
    wcs4 = WCSTransform(2; ctype = ["UNK---", "UNK---"])
    wcs5 = WCSTransform(2;)

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
#    @test rec[1].args == (img.data[1],)
#
#    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, wcs1)
#    @test rec[1].plotattributes[:xlabel] == "Right Ascension (ICRS)" && rec[1].plotattributes[:ylabel] == "Declination (ICRS)"
#
#    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, wcs2)
#    @test rec[1].plotattributes[:xlabel] == "Galactic Coordinate" && rec[1].plotattributes[:ylabel] == "Galactic Coordinate"
#
#    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, wcs3)
#    @test rec[1].plotattributes[:xlabel] == "ITRS" && rec[1].plotattributes[:ylabel] == "ITRS"
#
#    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, wcs4)
#    @test rec[1].plotattributes[:xlabel] == "UNK---" && rec[1].plotattributes[:ylabel] == "UNK---"
#
#    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, wcs5)
#    @test rec[1].plotattributes[:xlabel] == "" && rec[1].plotattributes[:ylabel] == ""
#
end

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
