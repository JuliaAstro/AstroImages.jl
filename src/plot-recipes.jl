using RecipesBase

@recipe function f(img::AstroImage)
    seriestype := :heatmap
    aspect_ratio := :equal
    img.data
end
