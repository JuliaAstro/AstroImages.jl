using RecipesBase

@testset "Plot recipes" begin
    data = randn(10, 10)
    img = AstroImage(data)
    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img)
    @test getfield(rec[1], 1) == Dict{Symbol, Any}(:seriestype   => :heatmap,
                                                   :aspect_ratio => :equal,
                                                   :color        => :grays)
    @test rec[1].args == (img.data[1],)

    img = AstroImage((data,data,data))    
    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img, 2)
    @test getfield(rec[1], 1) == Dict{Symbol, Any}(:seriestype   => :heatmap,
                                                   :aspect_ratio => :equal,
                                                   :color        => :grays)
    @test rec[1].args == (img.data[1],)
end
