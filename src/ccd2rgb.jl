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
function ccd2rgb(red::Tuple{AbstractMatrix, WCSTransform}, green::Tuple{AbstractMatrix, WCSTransform},
                     blue::Tuple{AbstractMatrix, WCSTransform}; stretch = identity, shape_out = size(red[1]))
    red_rp = reproject(red, red[2], shape_out = shape_out)[1]
    green_rp = reproject(green, red[2], shape_out = shape_out)[1]
    blue_rp = reproject(blue, red[2], shape_out = shape_out)[1]
    
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

