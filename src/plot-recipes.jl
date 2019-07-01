using RecipesBase

@recipe function f(img::AstroImage; header_number = 1)
    seriestype   := :heatmap
    aspect_ratio := :equal
    # Right now we only support single frame images,
    # gray scale is a good choice.
    color        := :grays
    img.data[header_number]
end
