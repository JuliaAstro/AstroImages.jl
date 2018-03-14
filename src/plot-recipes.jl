using RecipesBase

@recipe function f(img::AstroImage)
    seriestype   := :heatmap
    aspect_ratio := :equal
    # Right now we only support single frame images,
    # gray scale is a good choice.
    color        := :grays
    img.data
end
