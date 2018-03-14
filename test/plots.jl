using RecipesBase

@testset "Plot recipes" begin
    data = randn(10, 10)
    img = AstroImage(data)
    rec = RecipesBase.apply_recipe(Dict{Symbol, Any}(), img)
    @test rec[1].d == Dict{Symbol, Any}(:seriestype   => :heatmap,
                                        :aspect_ratio => :equal)
    @test rec[1].args == (img.data,)
end
