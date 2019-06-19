"""
    ccd2rgb(red::ImageHDU, green::ImageHDU, blue::ImageHDU; stretch::String="linear", shape_out = size(red))

Converts 3 grayscale ImageHDU into RGB by reprojecting them.

# Arguments
- `red`: Red channel data.
- `green`: Green channel data.
- `blue`: Blue channel data.
- `stretch`: Stretch function applied. Can be linear, log, sqrt or ashinh.
- `shape_out`: Shape of output RGB image.
"""
function ccd2rgb(red::ImageHDU, green::ImageHDU, blue::ImageHDU; stretch::String="linear", shape_out = size(red))
    red_rp = reproject(red, red, shape_out = shape_out)[1]
    green_rp = reproject(green, red, shape_out = shape_out)[1]
    blue_rp = reproject(blue, red, shape_out = shape_out)[1]
    
    I = (red_rp .+ green_rp .+ blue_rp) ./ 3
    
    if stretch == "linear"
        I = map(x-> (x)/x , I)
    elseif stretch == "log"
        I = map(x-> log(x)/x , I)
    elseif stretch == "sqrt"
        I = map(x-> sqrt(x)/x , I)
    elseif stretch == "asinh"
        I = map(x-> asinh(x)/x , I)
    else
        throw(DomainError(stretch, "Unknown stretch function."))
    end
                
    R = red_rp .* I
    G = green_rp .* I
    B = blue_rp .* I
    
    m1 = maximum(x->isnan(x) ? -Inf : x,R)
    m2 = maximum(x->isnan(x) ? -Inf : x,G)
    m3 = maximum(x->isnan(x) ? -Inf : x,B)
    return RGB.(R./m1 , G./m2, B./m3)
end
