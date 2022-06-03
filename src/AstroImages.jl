module AstroImages

using FITSIO
using FileIO
# Rather than pulling in all of Images.jl, just grab the packages
# we need to extend to our basic functionality.
# We also need ImageShow so that user's images appear automatically.
using ImageBase, ImageShow#, ImageAxes

using WCS
using Statistics
using MappedArrays
using ColorSchemes
using DimensionalData
using Tables
using RecipesBase
using AstroAngles
using Printf
using PlotUtils: PlotUtils
using PlotUtils: optimize_ticks, AbstractColorList
using UUIDs # can remove once reigstered with FileIO


export load,
    save,
    AstroImage,
    AstroImageVec,
    AstroImageMat,
    WCSGrid,
    composecolors,
    Zscale,
    Percent,
    logstretch,
    powstretch,
    sqrtstretch,
    squarestretch,
    asinhstretch,
    sinhstretch,
    powerdiststretch,
    imview,
    render, # deprecated
    header,
    copyheader,
    shareheader,
    wcs,
    Comment,
    History,
    # Dimensions
    Centered,
    Spec,
    Pol,
    Ti,
    X, Y, Z, Dim,
    At, Near, ..,
    dims, refdims,
    recenter,
    pix_to_world,
    pix_to_world!,
    world_to_pix,
    world_to_pix!



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


"""
Provides access to a FITS image along with its accompanying 
header and WCS information, if applicable.
"""
struct AstroImage{T,N,D<:Tuple,R<:Tuple,A<:AbstractArray{T,N},W<:Tuple} <: AbstractDimArray{T,N,D,A}
    # Parent array we are wrapping
    data::A
    # Fields for DimensionalData
    dims::D
    refdims::R
    # FITS Heads beloning to this image, if any
    header::FITSHeader
    # cached WCSTransform objects for this data.
    wcs::Vector{WCSTransform}
    # A flag that is set when a user modifies a WCS header.
    # The next access to the wcs object will regenerate from
    # the new header on demand.
    wcs_stale::Base.RefValue{Bool}
    # Correspondance between dims & refdims -> WCS Axis numbers
    wcsdims::W
end
# Provide type aliases for 1D and 2D versions of our data structure.
const AstroImageVec{T,D} = AstroImage{T,1} where {T}
const AstroImageMat{T,D} = AstroImage{T,2} where {T}


"""
    Centered()

Pass centered as a dimesion range to automatically center a dimension
along that axis.

Example:
```julia
cube = load("abc.fits", (X=Centered(), Y=Centered(), Pol=[:I, :Q, :U]))
```

In that case, cube will have dimsions with the centre of the image at 0
in both the X and Y axes.
"""
struct Centered end

# Default dimension names if none are provided
const dimnames = (
    X, Y, Z,
    (Dim{i} for i in 4:10)...
)

const Spec = Dim{:Spec}
const Pol = Dim{:Pol}

"""
    wcsax(img, dim)

Return the WCS axis number associated with a dimension, even if the image
has been slices or otherwise transformed.

Internally, the order is stored in the field `wcsdims`.
"""
function wcsax(img::AstroImage, dim)
    return findfirst(di->name(di)==name(dim), img.wcsdims)
end

# Accessors
header(img::AstroImage) = getfield(img, :header)
header(::AbstractArray) = emptyheader()
function wcs(img::AstroImage)
    if getfield(img, :wcs_stale)[]
        empty!(getfield(img, :wcs))
        append!(getfield(img, :wcs), wcsfromheader(img))
        getfield(img, :wcs_stale)[] = false
    end
    return getfield(img, :wcs)
end
wcs(arr::AbstractArray) = [emptywcs(arr)]
wcs(img, ind) = wcs(img)[ind]

# Implement DimensionalData interface 
Base.parent(img::AstroImage) = getfield(img, :data)
DimensionalData.dims(A::AstroImage) = getfield(A, :dims)
DimensionalData.refdims(A::AstroImage) = getfield(A, :refdims)
DimensionalData.data(A::AstroImage) = getfield(A, :data)
DimensionalData.name(::AstroImage) = DimensionalData.NoName()
DimensionalData.metadata(::AstroImage) = DimensionalData.Dimensions.LookupArrays.NoMetadata()

@inline function DimensionalData.rebuild(
    img::AstroImage,
    data,
    # Fields for DimensionalData
    dims::Tuple=DimensionalData.dims(img),
    refdims::Tuple=DimensionalData.refdims(img),
    name::Union{Symbol,DimensionalData.AbstractName,Nothing}=nothing,
    metadata::Union{DimensionalData.LookupArrays.AbstractMetadata,Nothing}=nothing,
    # FITS Header beloning to this image, if any
    header::FITSHeader=deepcopy(header(img)),
    # A cached WCSTransform object for this data
    wcs::Vector{WCSTransform}=getfield(img, :wcs),
    wcs_stale::Bool=getfield(img, :wcs_stale)[],
    wcsdims::Tuple=(dims...,refdims...),
)
    return AstroImage(data, dims, refdims, header, wcs, Ref(wcs_stale), wcsdims)
end
# Keyword argument version. 
# We have to define this since our struct contains additional field names.
@inline function DimensionalData.rebuild(
    img::AstroImage;
    data,
    # Fields for DimensionalData
    dims::Tuple=DimensionalData.dims(img),
    refdims::Tuple=DimensionalData.refdims(img),
    name::Union{Symbol,DimensionalData.AbstractName,Nothing}=nothing,
    metadata::Union{DimensionalData.LookupArrays.AbstractMetadata,Nothing}=nothing,
    # FITS Header beloning to this image, if any
    header::FITSHeader=deepcopy(header(img)),
    # A cached WCSTransform object for this data
    wcs::Vector{WCSTransform}=getfield(img, :wcs),
    wcs_stale::Bool=getfield(img, :wcs_stale)[],
    wcsdims::Tuple=(dims...,refdims...),
)
    return AstroImage(data, dims, refdims, header, wcs, Ref(wcs_stale), wcsdims)
end
@inline DimensionalData.rebuildsliced(
    f::Function,
    img::AstroImage,
    data,
    I,
    header=deepcopy(header(img)),
    wcs=getfield(img, :wcs),
    wcs_stale=getfield(img, :wcs_stale)[],
    wcsdims=getfield(img, :wcsdims),
) = rebuild(img, data, DimensionalData.slicedims(f, img, I)..., nothing, nothing, header, wcs, wcs_stale, wcsdims)

# Return result wrapped in AstroImage
# For these functions that return lazy wrappers, we want to share header
for f in [
    :(Base.adjoint),
    :(Base.transpose),
    :(Base.view)
]
    # TODO: these functions are copying headers
    @eval ($f)(img::AstroImage) = shareheader(img, $f(parent(img)))
end


"""
    AstroImage(img::AstroImage)

Returns its argument. Useful to ensure an argument is converted to an
AstroImage before proceeding.
"""
AstroImage(img::AstroImage) = img


"""
    AstroImage(data::AbstractArray, [header::FITSHeader,] [wcs::WCSTransform,])

Create an AstroImage from an array, and optionally header or header and a 
WCSTransform.
"""
function AstroImage(
    data::AbstractArray{T,N},
    dims::Union{Tuple,NamedTuple}=(),
    refdims::Union{Tuple,NamedTuple}=(),
    header::FITSHeader=emptyheader(),
    wcs::Union{WCSTransform,Nothing}=nothing;
    wcsdims=nothing
) where {T, N}
    wcs_stale = isnothing(wcs)
    if isnothing(wcs)
        wcs = [emptywcs(data)]
    end
    # If the user passes in a WCSTransform of their own, we use it and mark
    # wcs_stale=false. It will be kept unless they manually change a WCS header.
    # If they don't pass anything, we start with empty WCS information regardless
    # of what's in the header but we mark it as stale.
    # If/when the WCS info is accessed via `wcs(img)` it will be computed and cached.
    # This avoids those computations if the WCS transform is not needed.
    # It also allows us to create images with invalid WCS header,
    # only erroring when/if they are used.

    # Fields for DimensionalData.
    # TODO: cleanup logic
    if dims == ()
        # if wcsdims
            # ourdims = Tuple(Wcs{i} for i in 1:ndims(data))
        # else
            ourdims = dimnames[1:ndims(data)]
        # end
        dims = map(ourdims, axes(data)) do dim, ax
            dim(ax)
        end
    end
    # Replace any occurences of Centered() with an automatic range
    # from the data.
    dimvals = map(dims, axes(data)) do dim, ax
        if dim isa Centered
            ax .- mean(ax)
        else
            dim
        end
    end
    if dims isa NamedTuple
        dims = NamedTuple{keys(dims)}(dimvals)
    elseif !(dims isa NTuple{N,Dimensions.Dimension} where N) &&
        !(all(d-> d isa Union{UnionAll,DataType} && d <: Dimensions.Dimension, dims))
        k = name.(dimnames[1:ndims(data)])
        dims = NamedTuple{k}(dimvals)
    end
    dims = DimensionalData.format(dims, data)
    if length(dims) != ndims(data)
        error("Number of dims does not match the shape of the data")
    end

    if isnothing(wcsdims)
        wcsdims = (dims...,refdims...)
    end

    return AstroImage(data, dims, refdims, header, wcs, Ref(wcs_stale), wcsdims)
end
function AstroImage(
    darr::AbstractDimArray,
    header::FITSHeader=emptyheader(),
    wcs::Union{Vector{WCSTransform},Nothing}=nothing;
)
    wcs_stale = isnothing(wcs)
    if isnothing(wcs)
        wcs = [emptywcs(darr)]
    end
    wcsdims = (dims(darr)..., refdims(darr)...)
    return AstroImage(parent(darr), dims(darr), refdims(darr), header, wcs, Ref(wcs_stale), wcsdims)
end
AstroImage(
    data::AbstractArray,
    dims::Union{Tuple,NamedTuple},
    header::FITSHeader,
    wcs::Union{Vector{WCSTransform},Nothing}=nothing;
) = AstroImage(data, dims, (), header, wcs)
AstroImage(
    data::AbstractArray,
    header::FITSHeader,
    wcs::Union{Vector{WCSTransform},Nothing}=nothing;
) = AstroImage(data, (), (), header, wcs)


# TODO: ensure this gets WCS dims.
AstroImage(data::AbstractArray, wcs::Vector{WCSTransform}) = AstroImage(data, emptyheader(), wcs)


"""
Index for accessing a comment associated with a header keyword
or COMMENT entry.

Example:
```
img = AstroImage(randn(10,10))
img["ABC"] = 1
img["ABC", Comment] = "A comment describing this key"

push!(img, Comment, "The purpose of this file is to demonstrate comments")
img[Comment] # ["The purpose of this file is to demonstrate comments")]
```
"""
struct Comment end

"""
Allows accessing and setting HISTORY header entries

img = AstroImage(randn(10,10))
push!(img, History, "2023-04-19: Added history entry.")
img[History] # ["2023-04-19: Added history entry."]
"""
struct History end


# We might want getproperty for header access in future.
# function Base.getproperty(img::AstroImage, ::Symbol)
#     error("getproperty reserved for future use.")
# end

# Getting and setting comments
Base.getindex(img::AstroImage, inds::AbstractString...) = getindex(header(img), inds...) # accesing header using strings
function Base.setindex!(img::AstroImage, v, ind::AbstractString)  # modifying header using a string
    setindex!(header(img), v, ind)
    # Mark the WCS object as being out of date if this was a WCS header keyword
    if ind ∈ WCS_HEADERS
        getfield(img, :wcs_stale)[] = true
    end
end
Base.getindex(img::AstroImage, inds::Symbol...) = getindex(img, string.(inds)...) # accessing header using symbol
Base.setindex!(img::AstroImage, v, ind::Symbol) = setindex!(img, v, string(ind))
Base.getindex(img::AstroImage, ind::AbstractString, ::Type{Comment}) = get_comment(header(img), ind) # accesing header comment using strings
Base.setindex!(img::AstroImage, v,  ind::AbstractString, ::Type{Comment}) = set_comment!(header(img), ind, v) # modifying header comment using strings
Base.getindex(img::AstroImage, ind::Symbol, ::Type{Comment}) = get_comment(header(img), string(ind)) # accessing header comment using symbol
Base.setindex!(img::AstroImage,  v, ind::Symbol, ::Type{Comment}) = set_comment!(header(img), string(ind), v) # modifying header comment using Symbol

# Support for special HISTORY and COMMENT entries
function Base.getindex(img::AstroImage, ::Type{History})
    hdr = header(img)
    ii = findall(==("HISTORY"), hdr.keys)
    return view(hdr.comments, ii)
end
function Base.getindex(img::AstroImage, ::Type{Comment})
    hdr = header(img)
    ii = findall(==("COMMENT"), hdr.keys)
    return view(hdr.comments, ii)
end
# Adding new comment and history entries
function Base.push!(img::AstroImage, ::Type{Comment}, history::AbstractString)
    hdr = header(img)
    push!(hdr.keys, "COMMENT")
    push!(hdr.values, nothing)
    push!(hdr.comments, history)
end
function Base.push!(img::AstroImage, ::Type{History}, history::AbstractString)
    hdr = header(img)
    push!(hdr.keys, "HISTORY")
    push!(hdr.values, nothing)
    push!(hdr.comments, history)
end

"""
    copyheader(img::AstroImage, data) -> imgnew
Create a new image copying the header of `img` but
using the data of the AbstractArray `data`. Note that changing the
header of `imgnew` does not affect the header of `img`.
See also: [`shareheader`](@ref).
"""
copyheader(img::AstroImage, data::AbstractArray) =
    AstroImage(data, dims(img), refdims(img), deepcopy(header(img)), copy(getfield(img, :wcs)), Ref(getfield(img, :wcs_stale)[]), getfield(img,:wcsdims))

"""
    shareheader(img::AstroImage, data) -> imgnew
Create a new image reusing the header dictionary of `img` but
using the data of the AbstractArray `data`. The two images have
synchronized header; modifying one also affects the other.
See also: [`copyheader`](@ref).
""" 
shareheader(img::AstroImage, data::AbstractArray) = AstroImage(data, dims(img), refdims(img), header(img), getfield(img, :wcs), Ref(getfield(img, :wcs_stale)[]), getfield(img,:wcsdims))
# Share header if an AstroImage, do nothing if AbstractArray
maybe_shareheader(img::AstroImage, data) = shareheader(img, data)
maybe_shareheader(::AbstractArray, data) = data
maybe_copyheader(img::AstroImage, data) = copyheader(img, data)
maybe_copyheader(::AbstractArray, data) = data


Base.promote_rule(::Type{AstroImage{T}}, ::Type{AstroImage{V}}) where {T,V} = AstroImage{promote_type{T,V}}



Base.copy(img::AstroImage) = rebuild(img, copy(parent(img)))
Base.convert(::Type{AstroImage}, A::AstroImage) = A
Base.convert(::Type{AstroImage}, A::AbstractArray) = AstroImage(A)
Base.convert(::Type{AstroImage{T}}, A::AstroImage{T}) where {T} = A
Base.convert(::Type{AstroImage{T}}, A::AstroImage) where {T} = shareheader(A, convert(AbstractArray{T}, parent(A)))
Base.convert(::Type{AstroImage{T}}, A::AbstractArray{T}) where {T} = AstroImage(A)
Base.convert(::Type{AstroImage{T}}, A::AbstractArray) where {T} = AstroImage(convert(AbstractArray{T}, A))
Base.convert(::Type{AstroImage{T,N,D,R,AT}}, A::AbstractArray{T,N}) where {T,N,D,R,AT} = AstroImage(convert(AbstractArray{T}, A))

# TODO: share headers in View. Needs support from DimensionalData.

"""
    emptyheader()

Convenience function to create a FITSHeader with no keywords set.
"""
emptyheader() = FITSHeader(String[],[],String[])


"""
	recenter(img::AstroImage, newcentx, newcenty, ...)

Adjust the dimensions of an AstroImage so that they are centered on the pixel locations given by `newcentx`, .. etc.

This does not affect the underlying array, it just updates the dimensions associated with it by the AstroImage.

Example:
```julia
a = AstroImage(randn(11,11))
a[1,1] # Bottom left
a[At(1),At(1)] # Bottom left
r = recenter(a, 6, 6)
r[1,1] # Still bottom left
r[At(1),At(1)] # Center pixel
```
"""
function recenter(img::AstroImage, centers::Number...)
	newdims = map(dims(img), axes(img), centers) do d, a, c
		return AstroImages.name(d) => a .- c
	end
	newdimsformatted = AstroImages.DimensionalData.format(NamedTuple(newdims), parent(img))
	l = length(newdimsformatted)
	if l < ndims(img)
		newdimsformatted = (newdimsformatted..., dims(img)[l+1:end]...)
	end
	AstroImages.rebuild(img, parent(img), newdimsformatted)
end


include("wcs.jl")
include("io.jl")
include("imview.jl")
include("showmime.jl")
include("plot-recipes.jl")

include("contrib/images.jl")
include("contrib/abstract-ffts.jl")
# include("contrib/reproject.jl")

include("ccd2rgb.jl")
include("precompile.jl")

function __init__()

    # You can only `imview` 2D slices. Add an error hint if the user
    # tries to display a cube.
    if isdefined(Base.Experimental, :register_error_hint)
        Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
            if exc.f == imview && first(argtypes) <: AbstractArray && ndims(first(argtypes)) != 2
                print(io, "\nThe `imview` function only supports 2D images. If you have a cube, try viewing one slice at a time: imview(cube[:,:,1])\n")
            end
        end
    end

    # TODO: This should be registered correctly with FileIO
    del_format(format"FITS")
    add_format(format"FITS",
        # See https://www.loc.gov/preservation/digital/formats/fdd/fdd000317.shtml#sign
        [0x53,0x49,0x4d,0x50,0x4c,0x45,0x20,0x20,0x3d,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x54],
        [".fit", ".fits", ".fts", ".FIT", ".FITS", ".FTS", ".fit",],
        [:FITSIO => UUID("525bcba6-941b-5504-bd06-fd0dc1a4d2eb")],
        [:AstroImages => UUID("fe3fc30c-9b16-11e9-1c73-17dabf39f4ad")]
    )
    
end

end # module
