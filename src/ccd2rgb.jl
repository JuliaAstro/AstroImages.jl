"""
    composecolors(
        images,
        cmap=["#F00", "#0F0", "#00F"];
        clims,
        stretch,
        contrast,
        bias,
        multiplier
    )

Create a color composite of multiple images by applying `imview` and blending 
the results. This function can be used to create RGB composites using any number of channels
(e.g. red, green, blue, and hydrogen alpha) as well as more exotic images like blending
radio and optical data using two different colormaps.

`cmap` should be a list of colorants, named colors (see Colors.jl), or colorschemes (see ColorSchemes.jl).
`clims`, `stretch`, `contrast`, and `bias` are passed on to `imview`. They can be a single value or
a list of different values for each image.

The headers of the returned image are copied from the first image.

Examples:
```julia
# Basic RGB
composecolors([redimage, greenimage, blueimage])
# Non-linear stretch before blending
composecolors([redimage, greenimage, blueimage], stretch=asinhstretch)
# More than three channels are allowed (H alpha in pink)
composecolors(
    [antred, antgreen, antblue, anthalp],
    ["red", "green", "blue", "maroon1"],
    multiplier=[1,2,1,1]
)
# Can mix 
composecolors([radioimage, xrayimage], [:ice, :magma], clims=extrema)
composecolors([radioimage, xrayimage], [:magma, :viridis], clims=[Percent(99), Zscale()])
```
"""
function composecolors(
    images,
    cmap=nothing;
    clims=Percent(99.5),
    stretch=identity,
    contrast=1.0,
    bias=0.5,
    multiplier=1.0
)
    if isempty(images)
        error("At least one image is required.")
    end
    if !allequal(size.(images))
        error("Images must have the same dimensions to compose them.")
    end
    if length(images) == 3 && isnothing(cmap)
        cmap = ["red", "green", "blue"]
    end
    if length(cmap) < length(images)
        error("Please provide a color channel for each image")
    end

    # Use imview to render each channel to RGBA
    images_rendered = broadcast(images, cmap, clims, stretch, contrast, bias) do image, cmap, clims, stretch, contrast, bias
        imview(image; cmap, clims, stretch, contrast, bias)
    end

    # Now blend, ensuring each color channel never exceeds [0,1]
    combined = mappedarray(images_rendered...) do channels...
        pxblended = sum(channels .* multiplier)
        return typeof(pxblended)(
            clamp(pxblended.r,0,1),
            clamp(pxblended.g,0,1),
            clamp(pxblended.b,0,1),
            clamp(pxblended.alpha,0,1)
        )
    end
    return combined
end
export composechannels
