"""
    ccd2rgb(red::ImageHDU, green::ImageHDU, blue::ImageHDU; stretch::Function = x -> x, shape_out = size(red))

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

julia> ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = x -> log(x))

julia> ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = x -> sqrt(x))

julia> ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = x -> asinh(x))
```
"""
function ccd2rgb(red::ImageHDU, green::ImageHDU, blue::ImageHDU; stretch::Function = x -> x, shape_out = size(red))
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
