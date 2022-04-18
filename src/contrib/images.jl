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
    # Do not introduce NaNs if limits are identical
    if Δ == 0
        Δ = one(imgmin)
    end
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
    Δ = imgmax - imgmin
    # Do not introduce NaNs if colorlimits are identical
    if Δ == 0
        Δ = one(imgmin)
    end
    normeddata = mappedarray(
        pix -> clamp((pix - imgmin)/Δ, zero(pix), one(pix)),
        img
    )
    return maybe_shareheader(img, normeddata)
end

# Restrict downsizes images by roughly a factor of two.
# We want to keep the wrapper but downsize the underlying array
# TODO: correct dimensions after restrict.
ImageTransformations.restrict(img::AstroImage, ::Tuple{}) = img
function ImageTransformations.restrict(img::AstroImage, region::Dims)
    restricted = restrict(arraydata(img), region)
    steps = cld.(size(img), size(restricted))
    newdims = Tuple(d[begin:s:end] for (d,s) in zip(dims(img),steps))
    return rebuild(img, restricted, newdims)
end


ImageCore.pixelspacing(img::AstroImage) = step.(dims(img))


# ImageContrastAdjustment
# function ImageContrastAdjustment.adjust_histogram(::Type{T},
#     img::AstroImageMat,
#     f::Images.ImageContrastAdjustment.AbstractHistogramAdjustmentAlgorithm,
#     args...; kwargs...) where T
#     out = similar(img, axes(img))
#     adjust_histogram!(out, img, f, args...; kwargs...)
#     return out
# end



