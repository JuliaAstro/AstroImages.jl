
#=
ImageContrastAdjustment
=#
function Images.ImageContrastAdjustment.adjust_histogram(::Type{T},
    img::AstroImage,
    f::Images.ImageContrastAdjustment.AbstractHistogramAdjustmentAlgorithm,
    args...; kwargs...) where T
    out = similar(img, axes(img))
    adjust_histogram!(out, img, f, args...; kwargs...)
    return out
end


#=
ImageTransformations
=#
# function warp(img::AstroImage, args...; kwargs...)
#     out = warp(arraydatat(img), args...; kwargs...)
#     return copyheaders(img, out)
# end

#=
Additional methods to allow Reproject to work.
=#

using Reproject

"""
    img_proj, mask = reproject(img_in::AstroImage, img_out::AstroImage)

Reprojects the AstroImage `img_in` to the coordinates of `img_out`
according to the WCS information/headers using interpolation.
"""
function Reproject.reproject(img_in::AstroImage, img_out::AstroImage)
    data_out, mask = reproject(img_in, img_out)
    # TODO: should copy the WCS headers from img_out and the remaining
    # headers from img_in.
    return copyheaders(img_in, data_out)
end

function Reproject.parse_input_data(input_data::AstroImage, hdu)
    input_data, input_data.wcs
end
function Reproject.parse_output_projection(output_data::AstroImage, hdu)
    output_data.wcs, size(output_data)
end
function Reproject.pad_edges(array_in::AstroImage{T}) where {T}
    image = Matrix{T}(undef, size(array_in)[1] + 2, size(array_in)[2] + 2)
    image[2:end-1,2:end-1] = array_in
    image[2:end-1,1] = array_in[:,1]
    image[2:end-1,end] = array_in[:,end]
    image[1,:] = image[2,:]
    image[end,:] = image[end-1,:]
    return AstroImage(image, headers(array_in), wcs(array_in))
end