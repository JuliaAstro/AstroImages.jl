using RecipesBase
using AstroImages: pix2world_xformatter, pix2world_yformatter

@testset "Plot recipes" begin
    data = randn(10, 10)
    img = AstroImage(data)
    wcs1 = WCSTransform(2; ctype = ["RA---AIR", "DEC--AIR"])
    wcs2 = WCSTransform(2; ctype = ["GLON--", "GLAT--"])
    wcs3 = WCSTransform(2; ctype = ["TLON--", "TLAT--"])
    wcs4 = WCSTransform(2; ctype = ["UNK---", "UNK---"])
    wcs5 = WCSTransform(2;) 
    
    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, 1)
    @test getfield(rec[1], 1) == Dict{Symbol, Any}(:seriestype   => :heatmap,
                                                   :aspect_ratio => :equal,
                                                   :color        => :grays)
    
                                                   rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img)
    @test getfield(rec[1], 1) == Dict{Symbol, Any}(:seriestype   => :heatmap,
                                                   :aspect_ratio => :equal,
                                                   :color        => :grays)
    @test rec[1].args == (img.data[1],)
    
    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, wcs1)
    @test rec[1].plotattributes[:xlabel] == "Right Ascension (ICRS)" && rec[1].plotattributes[:ylabel] == "Declination (ICRS)"
    
    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, wcs2)
    @test rec[1].plotattributes[:xlabel] == "Galactic Coordinate" && rec[1].plotattributes[:ylabel] == "Galactic Coordinate"
    
    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, wcs3)
    @test rec[1].plotattributes[:xlabel] == "ITRS" && rec[1].plotattributes[:ylabel] == "ITRS"
    
    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, wcs4)
    @test rec[1].plotattributes[:xlabel] == "UNK---" && rec[1].plotattributes[:ylabel] == "UNK---"
    
    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, wcs5)
    @test rec[1].plotattributes[:xlabel] == "" && rec[1].plotattributes[:ylabel] == ""

end

@testset "formatters" begin
    wcs1 = WCSTransform(2; ctype = ["RA---AIR", "DEC--AIR"])
    wcs2 = WCSTransform(2; ctype = ["GLON--", "GLAT--"])
    
    @test pix2world_xformatter(255, wcs1) == "165.58°"
    @test pix2world_xformatter(255, wcs2) == 255.0
    
    @test pix2world_yformatter(255, wcs1) == "13.98°"
    @test pix2world_yformatter(255, wcs2) == 255.0
end
