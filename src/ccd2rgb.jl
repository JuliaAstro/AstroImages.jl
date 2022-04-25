"""
    ccd2rgb(red::ImageHDU, green::ImageHDU, blue::ImageHDU; stretch = identity, shape_out = size(red))
    ccd2rgb(red::Tuple{AbstractMatrix, WCSTransform}, green::Tuple{AbstractMatrix, WCSTransform},
                     blue::Tuple{AbstractMatrix, WCSTransform}; stretch = identity, shape_out = size(red[1]))

Converts 3 grayscale ImageHDU into RGB by reprojecting them.

# Arguments
- `red`: Red channel data.
- `green`: Green channel data.
- `blue`: Blue channel data.
- `stretch`: Stretch function applied.
- `shape_out`: Shape of output RGB image.

# Examples
```julia-repl
julia> ccd2rgb(r, b, g, shape_out = (1000,1000))

julia> ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = log)

julia> ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = sqrt)

julia> ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = asinh)
```
"""
function ccd2rgb(
    red::AstroImageMat,
    green::AstroImageMat,
    blue::AstroImageMat;
    stretch = identity,
    shape_out = size(red[1])
)
    red_rp = reproject(red, red, shape_out = shape_out)[1]
    green_rp = reproject(green, red, shape_out = shape_out)[1]
    blue_rp = reproject(blue, red, shape_out = shape_out)[1]
    
    I = (red_rp .+ green_rp .+ blue_rp) ./ 3
    I .= (x -> stretch(x)/x).(I)
        
    red_rp .*= I
    green_rp .*= I
    blue_rp .*= I
    
    m1 = maximum(x->isnan(x) ? -Inf : x, red_rp)
    m2 = maximum(x->isnan(x) ? -Inf : x, green_rp)
    m3 = maximum(x->isnan(x) ? -Inf : x, blue_rp)
    return colorview(RGB, red_rp./m1 , green_rp./m2, blue_rp./m3)
end

ccd2rgb(red::ImageHDU, green::ImageHDU, blue::ImageHDU; stretch = identity, shape_out = size(red)) =
    ccd2rgb((read(red), WCS.from_header(read_header(red, String))[1]), (read(green), WCS.from_header(read_header(green, String))[1]),
            (read(blue), WCS.from_header(read_header(blue, String))[1]), stretch = stretch, shape_out = shape_out)



function composechannels(
    images,
    multipliers=ones(size(images)), # 0.299 * R + 0.587 * G + 0.114 * B
    channels=["#F00", "#0F0", "#00F"];
    clims=extrema,
    stretch=identity,
    # reproject = all(==(wcs(first(images))), wcs(img) for img in images) ? false : wcs(first(images)),
    reproject = false,
    shape_out = size(first(images)),
)
    if reproject == false
        reprojected = images
    else
        if reproject == true
            reproject = first(images)
        end
        reprojected = map(images) do image
            Reproject.reproject(image, reproject; shape_out)[1]
        end
    end
    I = broadcast(+, reprojected...) ./ length(reprojected)
    I .= (x -> stretch(x)/x).(I)

    colors = parse.(Colorant, channels)
    # @show colors
        
    # red_rp .*= I
    # green_rp .*= I
    # blue_rp .*= I
    
    # m1 = maximum(x->isnan(x) ? -Inf : x, red_rp)
    # m2 = maximum(x->isnan(x) ? -Inf : x, green_rp)
    # m3 = maximum(x->isnan(x) ? -Inf : x, blue_rp)
    # return colorview(RGB, red_rp./m1 , green_rp./m2, blue_rp./m3)

    # return colorview(RGB, (reprojected .* multipliers)...)

    ## TODO: this all needs to be lazy

    colorized = map(eachindex(reprojected)) do i
        reprojected[i] .* multipliers[i] .* colors[i]
    end
    mapped = (+).(colorized...) ./ length(reprojected)
    T = coloralpha(eltype(mapped))
    mapped = T.(mapped)
    mapped[isnan.(mapped)] .= RGBA(0,0,0,0)

    # Flip image to match conventions of other programs
    flipped_view = view(mapped', reverse(axes(mapped,2)),:)

    return maybe_copyheaders(first(images), flipped_view)
    # return (reprojected .* multipliers .* colors)


    # TODO: more flexible blending
    # ColorBlnding
    # missing/NaN handling
end
export composechannels
