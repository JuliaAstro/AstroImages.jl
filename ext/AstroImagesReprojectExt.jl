module AstroImagesReprojectExt

using AstroImages: AstroImages, AstroImageMat, copyheader
using Reproject: Reproject

# The WCS of an image's own pixel grid. For a cutout or slice of a larger image (e.g., a
# moment map of a data cube), this differs from the WCS of the full image in its header.
gridwcs(img::AstroImageMat) = AstroImages._slicedwcs(img, ' ')

# Reproject's per-type hooks for the input image and the output projection
Reproject.data_and_wcs(img::AstroImageMat) = parent(img), gridwcs(img)
Reproject.wcs_and_shape(img::AstroImageMat, shape_out) = gridwcs(img), something(shape_out, size(img))

"""
    img, footprint = reproject(img_in::AstroImageMat, img_out::AstroImageMat; order = 1)

Reproject `img_in` onto the pixel grid of `img_out` by interpolation, according to their WCS information. `img` carries the header of `img_out`.
"""
function Reproject.reproject(img_in::AstroImageMat, img_out::AstroImageMat; kwargs...)
    data, footprint = invoke(Reproject.reproject, Tuple{Any, Any}, img_in, img_out; kwargs...)
    return copyheader(img_out, data), footprint
end

end
