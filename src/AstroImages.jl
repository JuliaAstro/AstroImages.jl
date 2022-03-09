module AstroImages

using FITSIO, FileIO, Images, Interact, Reproject, WCS, MappedArrays
using Statistics
using MappedArrays
using ColorSchemes
using PlotUtils: zscale
using OffsetArrays

using OffsetArrays

export load,
    save,
    AstroImage,
    WCSGrid,
    ccd2rgb,
    composechannels,
    set_brightness!,
    set_contrast!,
    add_label!,
    reset!,
    zscale,
    percent,
    logstretch,
    powstretch,
    sqrtstretch,
    squarestretch,
    asinhstretch,
    sinhstretch,
    powerdiststretch,
    clampednormedview,
    imview,
    clampednormedview,
    wcsticks,
    wcsgridlines,
    arraydata,
    headers,
    wcs,
    Comment,
    History

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
export load, save

# using UUIDs
# del_format(format"FITS")
# add_format(format"FITS",
#     # See https://www.loc.gov/preservation/digital/formats/fdd/fdd000317.shtml#sign
#     [0x53,0x49,0x4d,0x50,0x4c,0x45,0x20,0x20,0x3d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x54],
#     [".fit", ".fits", ".fts", ".FIT", ".FITS", ".FTS"],
#     [:FITSIO => UUID("525bcba6-941b-5504-bd06-fd0dc1a4d2eb")],
#     [:AstroImages => UUID("fe3fc30c-9b16-11e9-1c73-17dabf39f4ad")]
# )

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
struct AstroImage{T, N, TDat} <: AbstractArray{T,N}
    data::TDat
    headers::FITSHeader
    wcs::Ref{WCSTransform}
    wcs_stale::Ref{Bool}
    wcs_axes::NTuple{N,Union{Int,Colon}} where N
end
# Provide a type alias for a 1D version of our data structure. This is useful when extracting e.g. a spectrum from a data cube and
# retaining the headers and spectral axis information.
const AstroVec{T,TDat} = AstroImage{T,1,TDat} where {T,TDat}
export AstroVec

AstroImage(data::AbstractArray{T,N}, headers, wcs, wcs_stale, wcs_axes) where {T,N} = AstroImage{T,N,typeof(data)}(data,headers,Ref(wcs),Ref(wcs_stale),wcs_axes)


"""
    Images.arraydata(img::AstroImage)
"""
Images.arraydata(img::AstroImage) = getfield(img, :data)
headers(img::AstroImage) = getfield(img, :headers)
function wcs(img::AstroImage)
    if getfield(img, :wcs_stale)[]
        getfield(img, :wcs)[] = wcsfromheaders(img)
        getfield(img, :wcs_stale)[] = false
    end
    return getfield(img, :wcs)[]
end

struct Comment end
struct History end



# extending the AbstractArray interface
# and delegating calls to the wrapped array

# Simple delegation
for f in [
    :(Base.size),
    :(Base.length),
]
    @eval ($f)(img::AstroImage) = $f(arraydata(img))
end
# Return result wrapped in array
for f in [
    :(Base.adjoint),
    :(Base.transpose)
]
    @eval ($f)(img::AstroImage) = shareheaders(img, $f(arraydata(img)))
end

Base.parent(img::AstroImage) = arraydata(img)

# We might want property access for headers in future.
function Base.getproperty(img::AstroImage, ::Symbol)
    error("getproperty reserved for future use.")
end

# Getting and setting data is forwarded to the underlying array
# Accessing a single value or a vector returns just the data.
# Accering a 2+D slice copies the headers and re-wraps the data.
function Base.getindex(img::AstroImage, inds...)
    dat = getindex(arraydata(img), inds...)
    # ndims is defined for Numbers but not Missing.
    # This check is therefore necessary for img[1,1]->missing to work.
    if !(eltype(dat) <: Number) || ndims(dat) == 0
        return dat
    else
        ax_in = collect(getfield(img, :wcs_axes))
        ax_mask = ax_in .=== (:)
        ax_out = Vector{Union{Int,Colon}}(ax_in)
        ax_out[ax_mask] .= _filter_inds(inds)
        @show ax_out
        @show _ranges(inds)
        @show typeof(dat) size(dat)
        return AstroImage(
            OffsetArray(dat, _ranges(inds)...),
            deepcopy(headers(img)),
            getfield(img, :wcs)[],
            getfield(img, :wcs_stale)[],
            tuple(ax_out...)
        )
        # return copyheaders(img, dat)
    end
end
_filter_inds(inds) = tuple((
    typeof(ind) <: Union{AbstractRange,Colon} ? (:) : ind
    for ind in inds 
)...)
_ranges(args) = filter(arg -> typeof(arg) <:  Union{AbstractRange,Colon}, args)

Base.getindex(img::AstroImage{T}, inds...) where {T<:Colorant} = getindex(arraydata(img), inds...)
Base.setindex!(img::AstroImage, v, inds...) = setindex!(arraydata(img), v, inds...) # default fallback for operations on Array

# Getting and setting comments
Base.getindex(img::AstroImage, inds::AbstractString...) = getindex(headers(img), inds...) # accesing header using strings
function Base.setindex!(img::AstroImage, v, ind::AbstractString)  # modifying header using a string
    setindex!(headers(img), v, ind)
    # Mark the WCS object as being out of date if this was a WCS header keyword
    if ind ∈ WCS_HEADERS
        getfield(img, :wcs_stale)[] = true
    end
end
Base.getindex(img::AstroImage, inds::Symbol...) = getindex(img, string.(inds)...) # accessing header using symbol
Base.setindex!(img::AstroImage, v, ind::Symbol) = setindex!(img, v, string(ind))
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
# Adding new comment and history entries
function Base.push!(img::AstroImage, ::Type{Comment}, history::AbstractString)
    hdr = headers(img)
    push!(hdr.keys, "HISTORY")
    push!(hdr.values, nothing)
    push!(hdr.comments, history)
end
function Base.push!(img::AstroImage, ::Type{History}, history::AbstractString)
    hdr = headers(img)
    push!(hdr.keys, "HISTORY")
    push!(hdr.values, nothing)
    push!(hdr.comments, history)
end

"""
    copyheaders(img::AstroImage, data) -> imgnew
Create a new image copying the headers of `img` but
using the data of the AbstractArray `data`. Note that changing the
headers of `imgnew` does not affect the headers of `img`.
See also: [`shareheaders`](@ref).
"""
copyheaders(img::AstroImage, data::AbstractArray) =
    AstroImage(data, deepcopy(headers(img)), getfield(img, :wcs)[], getfield(img, :wcs_stale)[], getfield(img, :wcs_axes))
export copyheaders

"""
    shareheaders(img::AstroImage, data) -> imgnew
Create a new image reusing the headers dictionary of `img` but
using the data of the AbstractArray `data`. The two images have
synchronized headers; modifying one also affects the other.
See also: [`copyheaders`](@ref).
""" 
shareheaders(img::AstroImage, data::AbstractArray) = AstroImage(data, headers(img), getfield(img, :wcs)[], getfield(img, :wcs_stale)[], getfield(img, :wcs_axes))
export shareheaders
# Share headers if an AstroImage, do nothing if AbstractArray
maybe_shareheaders(img::AstroImage, data) = shareheaders(img, data)
maybe_shareheaders(::AbstractArray, data) = data
maybe_copyheaders(img::AstroImage, data) = copyheaders(img, data)
maybe_copyheaders(::AbstractArray, data) = data

# Iteration
# Defer to the array object in case it has special iteration defined
Base.iterate(img::AstroImage) = Base.iterate(arraydata(img))
Base.iterate(img::AstroImage, s) = Base.iterate(arraydata(img), s)

# Delegate axes to the backing array
Base.axes(img::AstroImage) = Base.axes(arraydata(img))

# Restrict downsizes images by roughly a factor of two.
# We want to keep the wrapper but downsize the underlying array
Images.restrict(img::AstroImage, ::Tuple{}) = img
Images.restrict(img::AstroImage, region::Dims) = shareheaders(img, restrict(arraydata(img), region))

# TODO: use WCS info
# ImageCore.pixelspacing(img::ImageMeta) = pixelspacing(arraydata(img))

Base.promote_rule(::Type{AstroImage{T}}, ::Type{AstroImage{V}}) where {T,V} = AstroImage{promote_type{T,V}}


function Base.similar(img::AstroImage) where T
    dat = similar(arraydata(img))
    return AstroImage(
        dat,
        deepcopy(headers(img)),
        getfield(img, :wcs),
        getfield(img, :wcs_stale),
        getfield(img, :wcs_axes),
    )
end
# Getting a similar AstroImage with specific indices will typyically
# return an OffsetArray
function Base.similar(img::AstroImage, dims::Tuple) where T
    dat = similar(arraydata(img), dims)
    # Similar creates a new AstroImage with a similar array.
    # We start with empty headers, except we copy any 
    # WCS headers from the original image.
    # The idea being we get an array that represents the same patch
    # of the sky in the same coordinate system.
    return AstroImage(
        dat,
        deepcopy(headers(img)),
        getfield(img, :wcs),
        getfield(img, :wcs_stale),
        getfield(img, :wcs_axes)
    )
end


Base.copy(img::AstroImage) = AstroImage(
    copy(arraydata(img)),
    deepcopy(headers(img)),
    # We copy the headers but share the WCS object.
    # If the headers change such that wcs is now out of date,
    # a new wcs will be generated when needed.
    getfield(img, :wcs),
    getfield(img, :wcs_stale)
)
Base.convert(::Type{AstroImage}, A::AstroImage) = A
Base.convert(::Type{AstroImage}, A::AbstractArray) = AstroImage(A)
Base.convert(::Type{AstroImage{T}}, A::AstroImage{T}) where {T} = A
Base.convert(::Type{AstroImage{T}}, A::AstroImage) where {T} = shareheaders(A, convert(AbstractArray{T}, arraydata(A)))
Base.convert(::Type{AstroImage{T}}, A::AbstractArray{T}) where {T} = AstroImage(A)
Base.convert(::Type{AstroImage{T}}, A::AbstractArray) where {T} = AstroImage(convert(AbstractArray{T}, A))

# TODO: offset arrays
Base.view(img::AstroImage, inds...) = shareheaders(img, view(arraydata(img), inds...))

# Broadcasting
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
        getfield(img, :wcs),
        getfield(img, :wcs_stale),
        getfield(img, :wcs_axes)
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
emptywcs(img::AstroImage) = WCSTransform(length(getfield(img, :wcs_axes)))



"""
    filterwcsheaders(hdrs::FITSHeader)

Return a new FITSHeader containing WCS headers from `hdrs`.
This is useful for creating a new image with the same coordinates
as another.
"""
function filterwcsheaders(hdrs::FITSHeader)
    include_keys = intersect(keys(hdrs), WCS_HEADERS)
    return FITSHeader(
        include_keys,
        map(key -> hdrs[key], include_keys),
        map(key -> get_comment(hdrs, key), include_keys),
    )
end

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
    return AstroImage{T,N,typeof(data)}(data, header, wcs, wcs_stale, tuple(((:) for _ in 1:N)...))
end
AstroImage(data::AbstractArray, wcs::WCSTransform) = AstroImage(data, emptyheaders(), wcs)


"""
    wcsfromheaders(img::AstroImage; relax=WCS.HDR_ALL, ignore_rejected=true)

Helper function to create a WCSTransform from an array and
FITSHeaders.
"""
function wcsfromheaders(img::AstroImage; relax=WCS.HDR_ALL)
    # We only need to stringify WCS headers. This might just be 4-10 header keywords
    # out of thousands.
    local wcsout
    # Load the headers without ignoring rejected to get error messages
    try
        wcsout = WCS.from_header(
            string(headers(img));
            ignore_rejected=false,
            relax
        )
    catch err
        # Load them again ignoring error messages
        wcsout = WCS.from_header(
            string(headers(img));
            ignore_rejected=true,
            relax
        )
        # If that still fails, the use gets the stack trace here
        # If not, print a warning about rejected headers
        @warn "WCSTransform was generated by ignoring rejected headers. It may not be valid." exception=err
    end

    if length(wcsout) == 1
        return only(wcsout)
    elseif length(wcsout) == 0
        return emptywcs(img)
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
`exts` must be a tuple, range, :, or array of Integers.
All listed HDUs in `exts` must be image HDUs or an error will occur.

Example:
```julia
img1, img2 = AstroImage("abc.fits", (1,3)) # loads the first and third HDU as images.
imgs = AstroImage("abc.fits", 1:3) # loads the first three HDUs as images.
imgs = AstroImage("abc.fits", :) # loads all HDUs as images.
```
"""
function AstroImage(filename::AbstractString, exts::Union{NTuple{N, <:Integer},AbstractArray{<:Integer}}) where {N}
    return FITS(filename,"r") do fits
        return map(exts) do ext
            return AstroImage(fits[ext])
        end
    end
end
function AstroImage(filename::AbstractString, ::Colon) where {N}
    return FITS(filename,"r") do fits
        return map(fits) do hdu
            return AstroImage(hdu)
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
include("imview.jl")
include("showmime.jl")
include("plot-recipes.jl")

include("ccd2rgb.jl")
include("patches.jl")

function __init__()

    # You can only `imview` 2D slices. Add an error hint if the user
    # tries to display a cube.
    if isdefined(Base.Experimental, :register_error_hint)
        Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
            if exc.f == imview && first(argtypes) <: AbstractArray && ndims(first(argtypes)) != 2
                print(io, "\nThe `imview` function only supports 2D images. If you have a cube, try viewing one slice at a time.\n")
            end
        end
    end
end

end # module


#=
TODO:
* properties?
* contrast/bias?
* interactive (Jupyter)
* Plots & Makie recipes
* Plots: vertical/horizotat axes from m106
* indexing
* recenter that updates indexes and CRPIX
* cubes
* RGB and other composites
* tests

* histogram equaization

* fileio

* FITSIO PR/issue (performance)
* PlotUtils PR/issue (zscale with iteratble)

=#