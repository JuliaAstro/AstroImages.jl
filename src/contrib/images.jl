#=
ImageTransformations
=#
# function warp(img::AstroImageMat, args...; kwargs...)
#     out = warp(arraydatat(img), args...; kwargs...)
#     return copyheaders(img, out)
# end



# Instead of using a datatype like N0f32 to interpret integers as fixed point values in [0,1],
# we use a mappedarray to map the native data range (regardless of type) to [0,1]
ImageCore.normedview(img::AstroImageMat{<:FixedPoint}) = img
function ImageCore.normedview(img::AstroImageMat{T}) where T
    imgmin, imgmax = extrema(skipmissingnan(img))
    Δ = abs(imgmax - imgmin)
    normeddata = mappedarray(
        pix -> (pix - imgmin)/Δ,
        pix_norm -> convert(T, pix_norm*Δ + imgmin),
        img
    )
    return shareheader(img, normeddata)
end

"""
    clampednormedview(arr, (min, max))

Given an AbstractArray and limits `min,max` return a view of the array
where data between [min, max] are scaled to [0, 1] and datat outside that
range are clamped to [0, 1].

See also: normedview
"""
function clampednormedview(img::AbstractArray{T}, lims) where T
    imgmin, imgmax = lims
    Δ = abs(imgmax - imgmin)
    normeddata = mappedarray(
        pix -> clamp((pix - imgmin)/Δ, zero(T), one(T)),
        pix_norm -> convert(T, pix_norm*Δ + imgmin),
        img
    )
    return maybe_shareheader(img, normeddata)
end
function clampednormedview(img::AbstractArray{T}, lims) where T <: Normed
    # If the data is in a Normed type and the limits are [0,1] then
    # it already lies in that range.
    if lims[1] == 0 && lims[2] == 1
        return img
    end
    imgmin, imgmax = lims
    Δ = abs(imgmax - imgmin)
    normeddata = mappedarray(
        pix -> clamp((pix - imgmin)/Δ, zero(T), one(T)),
        # pix_norm -> pix_norm*Δ + imgmin, # TODO
        img
    )
    return maybe_shareheader(img, normeddata)
end


# Restrict downsizes images by roughly a factor of two.
# We want to keep the wrapper but downsize the underlying array
# TODO: correct dimensions after restrict.
ImageTransformations.restrict(img::AstroImage, ::Tuple{}) = img
ImageTransformations.restrict(img::AstroImage, region::Dims) = shareheader(img, restrict(arraydata(img), region))

# TODO: use WCS info
# ImageCore.pixelspacing(img::ImageMeta) = pixelspacing(arraydata(img))


# ImageContrastAdjustment
# function ImageContrastAdjustment.adjust_histogram(::Type{T},
#     img::AstroImageMat,
#     f::Images.ImageContrastAdjustment.AbstractHistogramAdjustmentAlgorithm,
#     args...; kwargs...) where T
#     out = similar(img, axes(img))
#     adjust_histogram!(out, img, f, args...; kwargs...)
#     return out
# end



