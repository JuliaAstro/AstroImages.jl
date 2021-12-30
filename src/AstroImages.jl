__precompile__()

module AstroImages

using FITSIO, FileIO, Images, Interact, Reproject, WCS, MappedArrays

export load, AstroImage, ccd2rgb, set_brightness!, set_contrast!, add_label!, reset!

_load(fits::FITS, ext::Int) = read(fits[ext])
# _load(fits::FITS, ext::NTuple{N, Int}) where {N} = ntuple(i-> read(fits[ext[i]]), N)
# # _load(fits::NTuple{N, FITS}, ext::NTuple{N, Int}) where {N} = ntuple(i -> _load(fits[i], ext[i]), N)

# _header(fits::FITS, ext::Int) = WCS.from_header(read_header(fits[ext], String))[1]
# _header(fits::FITS, ext::NTuple{N, Int}) where {N} = 
#     ntuple(i -> WCS.from_header(read_header(fits[ext[i]], String))[1], N)
# _header(fits::NTuple{N, FITS}, ext::NTuple{N, Int}) where {N} = 
#     ntuple(i -> _header(fits[i], ext[i]), N)
"""
    load(fitsfile::String, n=1)

Read and return the data from `n`-th extension of the FITS file.

Second argument can also be a tuple of integers, in which case a 
tuple with the data of each corresponding extension is returned.
"""
function FileIO.load(f::File{format"FITS"}, ext::Int=1)
    return FITS(f.filename) do fits
        AstroImage(fits, ext) 
    end
end


# function FileIO.load(f::File{format"FITS"}, ext::NTuple{N,Int}) where {N}
#     fits = FITS(f.filename)
#     out = _load(fits, ext)
#     header = _header(fits, ext)
#     close(fits)
#     return out, header
# end

# function FileIO.load(f::NTuple{N, String}) where {N}
#     fits = ntuple(i-> FITS(f[i]), N)
#     ext = indexer(fits)
#     out = _load(fits, ext)
#     header = _header(fits, ext)
#     for i in 1:N
#         close(fits[i])
#     end
#     return out, header
# end

# function indexer(fits::FITS)
#     ext = 0
#     for (i, hdu) in enumerate(fits)
#         if hdu isa ImageHDU && length(size(hdu)) >= 2	# check if Image is atleast 2D
#             ext = i
#             break
#         end
#     end
#     if ext > 1
#        	@info "Image was loaded from HDU $ext"
#     elseif ext == 0
#         error("There are no ImageHDU extensions in '$(fits.filename)'")
#     end
#     return ext
# end
# indexer(fits::NTuple{N, FITS}) where {N} = ntuple(i -> indexer(fits[i]), N)

# Images.jl expects data to be either a float or a fixed-point number.  Here we define some
# utilities to convert all data types supported by FITS format to float or fixed-point:
#
#   * Float numbers are left as they are
#   * Unsigned integers are mapped to [0, 1] with Normed type
#   * Signed integers are mapped to unsigned integers and then to Normed
_float(x::AbstractFloat) = x
for n in (8, 16, 32, 64)
    SIT = Symbol("Int", n) # signed integer type
    UIT = Symbol("UInt", n) # unsigned integer type
    NIT = Symbol("N0f", n) # fixed-point type for unsigned float
    @eval maxint = $UIT(big(2) ^ ($n - 1)) #
    @eval begin
        _float(x::$UIT) = reinterpret($NIT, x)
        _float(x::$SIT) = _float(xor(reinterpret($UIT, x), $maxint))
    end
end


mutable struct Properties{P <: Union{AbstractFloat, FixedPoint}}
    rgb_image::MappedArrays.MultiMappedArray{RGB{P},2,Tuple{Array{P,2},Array{P,2},Array{P,2}},Type{RGB{P}},typeof(ImageCore.extractchannels)}
    contrast::Float64
    brightness::Float64
    label::Array{Tuple{Tuple{Float64,Float64},String},1}
    function Properties{P}(;kvs...) where P
        obj = new{P}()
        obj.contrast = 1.0
        obj.brightness = 0.0
        obj.label = Array{Tuple{Tuple{Float64,Float64},String}}(undef,0)
        for (k,v) in kvs
            setproperty!(obj, k, v)
        end
        return obj
    end
end


"""
Provides access to a FITS image along with its accompanying 
headers and WCS information, if applicable.
"""
mutable struct AstroImage{T, N, TDat} <: AbstractArray{T,N}
    data::TDat
    headers::FITSHeader
    wcs::WCSTransform
    wcs_stale::Bool
end


# Think about re-creating an image wrapper type.
# This can have properties about the stretch that can
# be modified
# struct AstroImageColorView1 <: Ast
# end
# What do we want? Indexable just like it is currently
# Not settable though
# Same headers
# Would need to store:
# * clims
# * stretch
# * mappedarray
# * properties of stretches?
struct AstroImageView{T,N,TImg,TMap,#=P<:Properties=#} <: AbstractArray{T,N} 
    image::TImg
    mapper::TMap
    # properties::P
end
AstroImageView(
    img::AbstractArray{T1,N},
    mapper::AbstractArray{T2,N},
) where {T1,T2,N} = AstroImageView{T2,N,typeof(img),typeof(mapper)}(img,mapper)


"""
    Images.arraydata(img::AstroImage)
"""
Images.arraydata(img::AstroImage) = img.data
Images.arraydata(img::AstroImageView) = img.image
Images.arraydata(img::AstroImageView{T,N,AstroImage}) where {T,N} = arraydata(img.image)
headers(img::AstroImage) = img.headers
headers(img::AstroImageView) = headers(img.image)
function wcs(img::AstroImage)
    if img.wcs_stale
        img.wcs = only(WCS.from_header(string(headers(img)), ignore_rejected=true))
        img.wcs_stale = false
    end
    return img.wcs
end

export arraydata, headers, wcs

struct Comment end
export Comment

struct History end
export History

AstroImageOrView = Union{AstroImage,AstroImageView}

# extending the AbstractArray interface
Base.size(img::AstroImageOrView) = size(arraydata(img))
Base.length(img::AstroImageOrView) = length(arraydata(img))

function Base.getindex(img::AstroImage, inds...)
    dat = getindex(arraydata(img), inds...)
    if ndims(dat) == 0
        return dat
    else
        return copyheaders(img, dat)
    end
end

Base.getindex(img::AstroImageView, inds...) = getindex(img.mapper, inds...) # default fallback for operations on Array
Base.setindex!(img::AstroImage, v, inds...) = setindex!(arraydata(img), v, inds...) # default fallback for operations on Array
Base.getindex(img::AstroImage, inds::AbstractString...) = getindex(headers(img), inds...) # accesing header using strings
Base.getindex(img::AstroImageView, inds::AbstractString...) = getindex(headers(img), inds...) # accesing header using strings
function Base.setindex!(img::AstroImage, v, ind::AbstractString)  # modifying header using a string
    setindex!(headers(img), v, ind)
    # Mark the WCS object as beign out of date if this was a WCS header keyword
    if ind ∈ WCS_HEADERS_2
        img.wcs_stale = true
    end
end
function Base.setindex!(aview::AstroImageView, v, ind::AbstractString)  # modifying header using a string
    setindex!(aview.image, v, ind)
end
Base.getindex(img::AstroImage, inds::Symbol...) = getindex(img, string.(inds)...) # accessing header using symbol
Base.setindex!(img::AstroImage, v, ind::Symbol) = setindex!(img, v, string(ind))
# Getting and setting comments
Base.getindex(img::AstroImage, ind::AbstractString, ::Type{Comment}) = get_comment(headers(img), ind) # accesing header comment using strings
Base.setindex!(img::AstroImage, v,  ind::AbstractString, ::Type{Comment}) = set_comment!(headers(img), ind, v) # modifying header comment using strings
Base.getindex(img::AstroImage, ind::Symbol, ::Type{Comment}) = get_comment(headers(img), string(ind)) # accessing header comment using symbol
Base.setindex!(img::AstroImage,  v, ind::Symbol, ::Type{Comment}) = set_comment!(headers(img), string(ind), v) # modifying header comment using Symbol

# Support for special HISTORY and COMMENT entries
function Base.getindex(img::AstroImage, ::Type{History})
    hdr = headers(img)
    ii = findall(==("HISTORY"), hdr.keys)
    return view(hdr.comments, ii)
end
function Base.getindex(img::AstroImage, ::Type{Comment})
    hdr = headers(img)
    ii = findall(==("COMMENT"), hdr.keys)
    return view(hdr.comments, ii)
end
# Adding new history entries
function Base.push!(img::AstroImageOrView, ::Type{History}, history::AbstractString)
    hdr = headers(img)
    push!(hdr.keys, "HISTORY")
    push!(hdr.values, nothing)
    push!(hdr.comments, history)
end

# TODO: do we need to adjust CRPIX_ when selecting a subset of the image?
"""
    copyheaders(img::AstroImage, data) -> imgnew
Create a new image copying the headers of `img` but
using the data of the AbstractArray `data`. Note that changing the
headers of `imgnew` does not affect the headers of `img`.
See also: [`shareheaders`](@ref).
"""
copyheaders(img::AstroImage, data::AbstractArray) =
    AstroImage(data, deepcopy(headers(img)), img.wcs)

"""
    shareheaders(img::AstroImage, data) -> imgnew
Create a new image reusing the headers dictionary of `img` but
using the data of the AbstractArray `data`. The two images have
synchronized headers; modifying one also affects the other.
See also: [`copyheaders`](@ref).
""" 
shareheaders(img::AstroImage, data::AbstractArray) = AstroImage(data, headers(img), img.wcs)
maybe_shareheaders(img::AstroImage, data) = shareheaders(img, data)
maybe_shareheaders(::AbstractArray, data) = data

# Iteration
# Defer to the array object in case it has special iteration defined
Base.iterate(img::AstroImageOrView) = Base.iterate(arraydata(img))
Base.iterate(img::AstroImageOrView, s) = Base.iterate(arraydata(img), s)

# Restrict downsizes images by roughly a factor of two.
# We want to keep the wrapper but downsize the underlying array
Images.restrict(img::AstroImageOrView, ::Tuple{}) = img
Images.restrict(img::AstroImage, region::Dims) = shareheaders(img, restrict(arraydata(img), region))
Images.restrict(imgview::AstroImageView, region::Dims) = restrict(imgview.mapper, region)

# TODO: use WCS info
# ImageCore.pixelspacing(img::ImageMeta) = pixelspacing(arraydata(img))

Base.promote_rule(::Type{AstroImage{T}}, ::Type{AstroImage{V}}) where {T,V} = AstroImage{promote_type{T,V}}

# function Base.similar(img::AstroImage) where T
#     dat = similar(arraydata(img))
#     _,_,C,P = TNCP(img)
#     T2 = eltype(dat)
#     N = length(size(dat))
#     return AstroImage{T2,N,C,P}(
#         dat,
#         (zero(dat),one(dat)),
#         true,
#         # TODO:
#         # similar(img.wcs),
#         img.wcs,
#         Properties{Float64}(),
#         FITSHeader(String[],[],String[]),
#     )
# end

# Broadcasting
Base.copy(img::AstroImage) = AstroImage(
    copy(arraydata(img)),
    deepcopy(headers(img)),
    # We copy the headers but share the WCS object.
    # If the headers change such that wcs is now out of date,
    # a new wcs will be generated when needed.
    img.wcs
)
Base.convert(::Type{AstroImage}, A::AstroImage) = A
Base.convert(::Type{AstroImage}, A::AbstractArray) = AstroImage(A)
Base.convert(::Type{AstroImage{T}}, A::AstroImage{T}) where {T} = A
Base.convert(::Type{AstroImage{T}}, A::AstroImage) where {T} = shareheaders(A, convert(AbstractArray{T}, arraydata(A)))
Base.convert(::Type{AstroImage{T}}, A::AbstractArray{T}) where {T} = AstroImage(A)
Base.convert(::Type{AstroImage{T}}, A::AbstractArray) where {T} = AstroImage(convert(AbstractArray{T}, A))

Base.view(img::AstroImage, inds...) = shareheaders(img, view(arraydata(img), inds...))
# Base.selectdim(img::AstroImage, d::Integer, idxs) = AstroImage(selectdim(arraydata(img), d, idxs), headers(img))
# broadcast mechanics
Base.BroadcastStyle(::Type{<:AstroImage}) = Broadcast.ArrayStyle{AstroImage}()
function Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{AstroImage}}, ::Type{T}) where T
    img = find_img(bc)
    dat = similar(arraydata(img), T, axes(bc))
    T2 = eltype(dat)
    N = ndims(dat)
    # We copy the headers but share the WCS object.
    # If the headers change such that wcs is now out of date,
    # a new wcs will be generated when needed.
    return AstroImage{T2,N,typeof(dat)}(
        dat,
        deepcopy(headers(img)),
        img.wcs,
        false
    )
end
"`A = find_img(As)` returns the first AstroImage among the arguments."
find_img(bc::Base.Broadcast.Broadcasted) = find_img(bc.args)
find_img(args::Tuple) = find_img(find_img(args[1]), Base.tail(args))
find_img(x) = x
find_img(::Tuple{}) = nothing
find_img(a::AstroImage, rest) = a
find_img(::Any, rest) = find_img(rest)

"""
    AstroImage([color=Gray,] data::Matrix{Real})
    AstroImage(color::Type{<:Color}, data::NTuple{N, Matrix{T}}) where {T<:Real, N}

Construct an `AstroImage` object of `data`, using `color` as color map, `Gray` by default.
"""
AstroImage(img::AstroImage) = img
# AstroImage(data::AbstractArray{T,N}, headers::FITSHeader, wcs::WCSTransform) where {T,N} = 
#     AstroImage{T,N,typeof(data)}(data, headers, wcs)

# AstroImage(color::Type{<:Color}, data::AbstractArray{T,N}, wcs::WCSTransform) where {T<:Real,N<:Int} =
#     AstroImage{T, N, color, Float64}(data, extrema(data), false, wcs, Properties{Float64}())
# function AstroImage(color::Type{<:AbstractRGB}, data::NTuple{N, Matrix{T}}, wcs::NTuple{N, WCSTransform}) where {T <: Union{AbstractFloat, FixedPoint}, N}
#     if N == 3
#         img = ccd2rgb((data[1], wcs[1]),(data[2], wcs[2]),(data[3], wcs[3]))
#         return AstroImage{T,color,N, widen(T)}(data, ntuple(i -> extrema(data[i]), N), wcs, Properties{widen(T)}(rgb_image = img))
#     end
# end
# function AstroImage(color::Type{<:AbstractRGB}, data::NTuple{N, Matrix{T}}, wcs::NTuple{N, WCSTransform}) where {T<:Real, N}
#     if N == 3
#         img = ccd2rgb((data[1], wcs[1]),(data[2], wcs[2]),(data[3], wcs[3]))
#         return AstroImage{T,color,N, Float64}(data, ntuple(i -> extrema(data[i]), N), wcs, Properties{Float64}(rgb_image = img))
#     end
# end

"""
    emptyheaders()

Convenience function to create a FITSHeader with no keywords set.
"""
emptyheaders() = FITSHeader(String[],[],String[])
"""
    emptywcs()

Given an AbstractArray, return a blank WCSTransform of the appropriate
dimensionality.
"""
emptywcs(data::AbstractArray) = WCSTransform(ndims(data))

"""
    AstroImage(data::AbstractArray, [headers::FITSHeader,] [wcs::WCSTransform,])

Create an AstroImage from an array, and optionally headers or headers and a 
WCSTransform.
"""
function AstroImage(
    data::AbstractArray{T,N},
    header::FITSHeader=emptyheaders(),
    wcs::Union{WCSTransform,Nothing}=nothing
) where {T, N}
    wcs_stale = isnothing(wcs)
    if isnothing(wcs)
        wcs = emptywcs(data)
    end
    # If the user passes in a WCSTransform of their own, we use it and mark
    # wcs_stale=false. It will be kept unless they manually change a WCS header.
    # If they don't pass anythin, we start with empty WCS information regardless
    # of what's in the headers but we mark it as stale.
    # If/when the WCS info is accessed via `wcs(img)` it will be computed and cached.
    # This avoids those computations if the WCS transform is not needed.
    # It also allows us to create images with invalid WCS headers,
    # only erroring when/if they are used.
    return AstroImage{T,N,typeof(data)}(data, header, wcs, wcs_stale)
end
AstroImage(data::AbstractArray, wcs::WCSTransform) = AstroImage(data, emptyheaders(), wcs)


"""
    wcsfromheaders(data::AbstractArray, headers::FITSHeader)

Helper function to create a WCSTransform from an array and
FITSHeaders.
"""
function wcsfromheaders(data::AbstractArray, head::FITSHeader)
    wcsout = WCS.from_header(string(head), ignore_rejected=true)
    if length(wcsout) == 1
        return only(wcsout)
    elseif length(wcsout) == 0
        return emptywcs(data)
    else
        error("Mutiple WCSTransform returned from headers")
    end
end


"""
    AstroImage(fits::FITS, ext::Int=1)

Given an open FITS file from the FITSIO library,
load the HDU number `ext` as an AstroImage.
"""
AstroImage(fits::FITS, ext::Int=1) = AstroImage(fits[ext], read_header(fits[ext]))

"""
    AstroImage(hdu::HDU)

Given an open FITS HDU, load it as an AstroImage.
"""
AstroImage(hdu::HDU) = AstroImage(read(hdu), read_header(hdu))
# AstroImage(color::Type{<:Color}, fits::FITS, ext::NTuple{N, Int}) where {N} =
#     AstroImage(color, _load(fits, ext), ntuple(i -> WCS.from_header(read_header(fits[ext[i]], String))[1], N))
# AstroImage(color::Type{<:Color}, fits::NTuple{N, FITS}, ext::NTuple{N, Int}) where {N} =
#     AstroImage(color, ntuple(i -> _load(fits[i], ext[i]), N), ntuple(i -> WCS.from_header(read_header(fits[i][ext[i]], String))[1], N))

# AstroImage(files::NTuple{N,String}) where {N} = 
#     AstroImage(Gray, load(files)...)
# AstroImage(color::Type{<:Color}, files::NTuple{N,String}) where {N} = 
#     AstroImage(color, load(files)...)

"""
    img = AstroImage(filename::AbstractString, ext::Integer=1)

Load an image HDU `ext` from the  FITS file at `filename` as an AstroImage.
"""
function AstroImage(filename::AbstractString, ext::Integer=1)
    return FITS(filename,"r") do fits
        return AstroImage(fits[ext])
    end
end
"""
    img1, img2 = AstroImage(filename::AbstractString, exts)

Load multiple image HDUs `exts` from an FITS file at `filename` as an AstroImage.
`exts` must be a tuple, range, or array of Integers.

Example:
```julia
img1, img2 = AstroImage("abc.fits", (1,3)) # loads the first and third HDU as images.
imgs = AstroImage("abc.fits", 1:3) # loads the first three HDUs as images.
```
"""
function AstroImage(filename::AbstractString, exts::Union{NTuple{N, <:Integer},AbstractArray{<:Integer}}) where {N}
    return FITS(filename,"r") do fits
        return map(exts) do ext
            return AstroImage(fits[ext])
        end
    end
end


"""
    set_brightness!(img::AstroImage, value::AbstractFloat)

Sets brightness of `rgb_image` to value.
"""
function set_brightness!(img::AstroImage, value::AbstractFloat)
    if isdefined(img.property, :rgb_image)
        diff = value - img.property.brightness
        img.property.brightness = value
        img.property.rgb_image .+= RGB{typeof(value)}(diff, diff, diff)
    else
        throw(DomainError(value, "Can't apply operation. AstroImage dosen't contain :rgb_image"))
    end
end

"""
    set_contrast!(img::AstroImage, value::AbstractFloat)

Sets contrast of rgb_image to value.
"""
function set_contrast!(img::AstroImage, value::AbstractFloat)
    if isdefined(img.property, :rgb_image)
        diff = (value / img.property.contrast)
        img.property.contrast = value
        img.property.rgb_image = colorview(RGB, red.(img.property.rgb_image) .* diff, green.(img.property.rgb_image) .* diff,
                                                blue.(img.property.rgb_image) .* diff)
    else
        throw(DomainError(value, "Can't apply operation. AstroImage dosen't contain :rgb_image"))
    end
end

"""
    add_label!(img::AstroImage, x::Real, y::Real, label::String)

Stores label to coordinates (x,y) in AstroImage's property label.
"""
function add_label!(img::AstroImage, x::Real, y::Real, label::String)
    push!(img.property.label, ((x,y), label))
end

"""
    reset!(img::AstroImage)

Resets AstroImage property fields.

Sets brightness to 0.0, contrast to 1.0, empties label
and form a fresh rgb_image without any brightness, contrast operations on it.
"""
function reset!(img::AstroImage{T,N}) where {T,N}
    img.property.contrast = 1.0
    img.property.brightness = 0.0
    img.property.label = []
    if N == 3 && C == RGB
        shape_out = size(img.property.rgb_image)
        img.property.rgb_image = ccd2rgb((img.data[1], img.wcs[1]),(img.data[2], img.wcs[2]),(img.data[3], img.wcs[3]),
                                            shape_out = shape_out)
    end
end

include("wcs_headers.jl")
include("showmime.jl")
include("plot-recipes.jl")
include("ccd2rgb.jl")
include("reproject.jl")

end # module
