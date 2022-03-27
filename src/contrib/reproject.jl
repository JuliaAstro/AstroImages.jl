


#=
Additional methods to allow Reproject to work.
=#

using Reproject

"""
    img_proj, mask = reproject(img_in::AstroImageMat, img_out::AstroImageMat)

Reprojects the AstroImageMat `img_in` to the coordinates of `img_out`
according to the WCS information/headers using interpolation.
"""
function Reproject.reproject(img_in::AstroImageMat, img_out::AstroImageMat)
    data_out, mask = reproject(img_in, img_out)
    # TODO: should copy the WCS headers from img_out and the remaining
    # headers from img_in.
    return copyheaders(img_in, data_out)
end

function Reproject.parse_input_data(input_data::AstroImageMat, hdu)
    input_data, input_data.wcs
end
function Reproject.parse_output_projection(output_data::AstroImageMat, hdu)
    output_data.wcs, size(output_data)
end
function Reproject.pad_edges(array_in::AstroImageMat{T}) where {T}
    image = Matrix{T}(undef, size(array_in)[1] + 2, size(array_in)[2] + 2)
    image[2:end-1,2:end-1] = array_in
    image[2:end-1,1] = array_in[:,1]
    image[2:end-1,end] = array_in[:,end]
    image[1,:] = image[2,:]
    image[end,:] = image[end-1,:]
    return AstroImageMat(image, headers(array_in), wcs(array_in))
end
