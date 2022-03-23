module AstroImages

using FITSIO
using FileIO
using Images # TODO: maybe this can be ImagesCore
using Interact
using Reproject
using WCS
using Statistics
using MappedArrays
using ColorSchemes
using PlotUtils: zscale
using DimensionalData
using Tables
using RecipesBase
using AstroAngles
using Printf
using PlotUtils: optimize_ticks



export load,
    save,
    AstroImage,
    WCSGrid,
    ccd2rgb,
    composechannels,
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
    imview,
    clampednormedview,
    # wcsticks,
    # wcsgridlines,
    arraydata,
    header,
    wcs,
    Comment,
    History


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
struct AstroImage{T,N,D<:Tuple,R<:Tuple,A<:AbstractArray{T,N}} <: AbstractDimArray{T,N,D,A}
    # Parent array we are wrapping
    data::A
    # Fields for DimensionalData
    dims::D
    refdims::R
    # FITS Heads beloning to this image, if any
    header::FITSHeader
    # A cached WCSTransform object for this data
    wcs::Base.RefValue{WCSTransform}
    # A flag that is set when a user modifies a WCS header.
    # The next access to the wcs object will regenerate from
    # the new header on demand.
    wcs_stale::Base.RefValue{Bool}
end
# Provide type aliases for 1D and 2D versions of our data structure.
const AstroImageVec{T,D,R,A} = AstroImage{T,1,D,R,A} where {T,D,R,A}
const AstroImageMat{T,D,R,A} = AstroImage{T,2,D,R,A} where {T,D,R,A}
export AstroImage, AstroImageVec, AstroImageMat

# Re-export symbols from DimensionalData that users will need 
# for indexing.
export X, Y, Z, Dim
export At, Near, Between, ..
export dims, refdims

# We need to keep a canonical order of dimensions to match back with WCS
# dimension numbers. E.g. if we see Z(), we need to know this is WCSTransform(..).ctype[3].
# Currently this is supported up to dimension 10, but this feels arbitrary.
# In future, let's just hardcode X,Y,Z and then use the dimension number itself
# after that.
const dimnames = (
    X, Y, Z,
    (Dim{i} for i in 4:10)...
)

# Export WCS coordinate conversion functions
export pix_to_world, pix_to_world!, world_to_pix, world!_to_pix

# Accessors
"""
    Images.arraydata(img::AstroImage)
"""
Images.arraydata(img::AstroImage) = getfield(img, :data)
header(img::AstroImage) = getfield(img, :header)
function wcs(img::AstroImage)
    if getfield(img, :wcs_stale)[]
        getfield(img, :wcs)[] = wcsfromheader(img)
        getfield(img, :wcs_stale)[] = false
    end
    return getfield(img, :wcs)[]
end


# Implement DimensionalData interface
Base.parent(img::AstroImage) = arraydata(img)
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
    wcs::WCSTransform=getfield(img, :wcs)[],
    wcs_stale::Bool=getfield(img, :wcs_stale)[],
)
    return AstroImage(data, dims, refdims, header, Ref(wcs), Ref(wcs_stale))
end
# Stub for when a name or metadata are passed along (we don't implement that functionality)
# @inline function DimensionalData.rebuild(
#     img::AstroImage,
#     data,
#     dims::Tuple,
#     refdims::Tuple,
#     name::Union{Symbol,DimensionalData.AbstractName},
#     metadata::Union{DimensionalData.LookupArrays.AbstractMetadata,Nothing},
# )
#     # name and metadata are dropped
#     return DimensionalData.rebuild(img, data, dims, refdims, name, metadata)
# end
@inline DimensionalData.rebuildsliced(
    f::Function,
    img::AstroImage,
    data,
    I,
    header=deepcopy(header(img)),
    wcs=getfield(img, :wcs)[],
    wcs_stale=getfield(img, :wcs_stale)[],
) = rebuild(img, data, DimensionalData.slicedims(f, img, I)..., nothing, nothing, header, wcs, wcs_stale)

# For these functions that return lazy wrappers, we want to 
# share header
# Return result wrapped in array
for f in [
    :(Base.adjoint),
    :(Base.transpose),
    :(Base.view)
]
    # TODO: these functions are copying headers
    @eval ($f)(img::AstroImage) = shareheader(img, $f(arraydata(img)))
end

"""
    AstroImage(fits::FITS, ext::Int=1)

Given an open FITS file from the FITSIO library,
load the HDU number `ext` as an AstroImage.
"""
AstroImage(fits::FITS, ext::Int=1) = AstroImage(fits[ext])

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
    header::FITSHeader=emptyheader(),
    wcs::Union{WCSTransform,Nothing}=nothing
) where {T, N}
    wcs_stale = isnothing(wcs)
    if isnothing(wcs)
        wcs = emptywcs(data)
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
    # Name dimensions always as X,Y,Z, then Dim{4}, Dim{5}, etc.
    # If we wanted to do something smarter e.g. time axes we would have
    # to look at the WCSTransform, and we want to avoid doing this on construction
    # for the reasons described above.
    dimnames = (
        X, Y, Z
    )[1:min(3,N)]
    if N > 3
        dimnames = (
            dimnames...,
            (Dim{i} for i in 4:N)...
        )
    end
    dimaxes = map(dimnames, axes(data)) do dim, ax
        dim(ax)
    end
    dims = DimensionalData.format(dimaxes, data)
    refdims = ()

    return AstroImage(data, dims, refdims, header, Ref(wcs), Ref(wcs_stale))
end
AstroImage(data::AbstractArray, wcs::WCSTransform) = AstroImage(data, emptyheader(), wcs)



"""
    load(fitsfile::String)

Read and return the data from the first ImageHDU in a FITS file
as an AstroImage. If no ImageHDUs are present, an error is returned.

    load(fitsfile::String, ext::Int)

Read and return the data from the HDU `ext`. If it is an ImageHDU,
as AstroImage is returned. If it is a TableHDU, a plain Julia
column table is returned.

    load(fitsfile::String, :)

Read and return the data from each HDU in an FITS file. ImageHDUs are
returned as AstroImage, and TableHDUs are returned as column tables.

    load(fitsfile::String, exts::Union{NTuple, AbstractArray})

Read and return the data from the HDUs given by `exts`. ImageHDUs are
returned as AstroImage, and TableHDUs are returned as column tables.

!! Currently comments on TableHDUs are not supported and are ignored.
"""
function fileio_load(f::File{format"FITS"}, ext::Union{Int,Nothing}=nothing) where N
    return FITS(f.filename, "r") do fits
        if isnothing(ext)
            ext = indexer(fits)
        end
        _loadhdu(fits[ext])
    end
end
function fileio_load(f::File{format"FITS"}, exts::Union{NTuple{N, <:Integer},AbstractArray{<:Integer}}) where N
    return FITS(f.filename, "r") do fits
        map(exts) do ext
            _loadhdu(fits[ext])
        end
    end
end
function fileio_load(f::File{format"FITS"}, exts::Colon) where N
    return FITS(f.filename, "r") do fits
        exts_resolved = 1:length(fits)
        map(exts_resolved) do ext
            _loadhdu(fits[ext])
        end
    end
end

_loadhdu(hdu::FITSIO.TableHDU) = Tables.columntable(hdu)
function _loadhdu(hdu::FITSIO.ImageHDU)
    if size(hdu) != ()
        return AstroImage(hdu)
    else
        # Sometimes files have an empty data HDU that shows up as an image HDU but has headers.
        # Fallback to creating an empty AstroImage with those headers.
        emptydata = fill(0, (0,0))
        return AstroImage(emptydata, (), (), read_header(hdu), Ref(emptywcs(emptydata)), Ref(false))
    end
end
function indexer(fits::FITS)
    ext = 0
    for (i, hdu) in enumerate(fits)
        if hdu isa ImageHDU && length(size(hdu)) >= 2	# check if Image is atleast 2D
            ext = i
            break
        end
    end
    if ext > 1
       	@info "Image was loaded from HDU $ext"
    elseif ext == 0
        error("There are no ImageHDU extensions in '$(fits.filename)'")
    end
    return ext
end
indexer(fits::NTuple{N, FITS}) where {N} = ntuple(i -> indexer(fits[i]), N)


# Fallback for saving arbitrary arrays
function fileio_save(f::File{format"FITS"}, args...)
    FITS(f.filename, "w") do fits
        for arg in args
            writearg(fits, arg)
        end
    end
end
writearg(fits, img::AstroImage) = write(fits, arraydata(img), header=header(img))
# Fallback for writing plain arrays
writearg(fits, arr::AbstractArray) = write(fits, arr)
# For table compatible data.
# This allows users to round trip: dat = load("abc.fits", :); write("abc", dat) 
# when it contains FITS tables.
function writearg(fits, table)
    if !Tables.istable(table)
        error("Cannot save argument to FITS file. Value is not an AbstractArray or table.")
    end
    # FITSIO has fairly restrictive input types for writing tables (assertions for documentation only)
    colname_strings = string.(collect(Tables.columnnames(table)))::Vector{String}
    columns = collect(Tables.columns(table))::Vector
    write(
        fits,
        colname_strings,
        columns;
        hdutype=TableHDU,
        # TODO: In future, we want to be able to access and round-trip coments
        # on table HDUs
        # header=nothing
    )
end


export load, save




struct Comment end
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
    AstroImage(data, dims(img), refdims(img), deepcopy(header(img)), Ref(getfield(img, :wcs)[]), Ref(getfield(img, :wcs_stale)[]))
export copyheader

"""
    shareheader(img::AstroImage, data) -> imgnew
Create a new image reusing the header dictionary of `img` but
using the data of the AbstractArray `data`. The two images have
synchronized header; modifying one also affects the other.
See also: [`copyheader`](@ref).
""" 
shareheader(img::AstroImage, data::AbstractArray) = AstroImage(data, dims(img), refdims(img), header(img), Ref(getfield(img, :wcs)[]), Ref(getfield(img, :wcs_stale)[]))
export shareheader
# Share header if an AstroImage, do nothing if AbstractArray
maybe_shareheader(img::AstroImage, data) = shareheader(img, data)
maybe_shareheader(::AbstractArray, data) = data
maybe_copyheader(img::AstroImage, data) = copyheader(img, data)
maybe_copyheader(::AbstractArray, data) = data


# Restrict downsizes images by roughly a factor of two.
# We want to keep the wrapper but downsize the underlying array
# TODO: correct dimensions after restrict.
Images.restrict(img::AstroImage, ::Tuple{}) = img
Images.restrict(img::AstroImage, region::Dims) = shareheader(img, restrict(arraydata(img), region))

# TODO: use WCS info
# ImageCore.pixelspacing(img::ImageMeta) = pixelspacing(arraydata(img))

Base.promote_rule(::Type{AstroImage{T}}, ::Type{AstroImage{V}}) where {T,V} = AstroImage{promote_type{T,V}}



Base.copy(img::AstroImage) = rebuild(img, copy(parent(img)))
Base.convert(::Type{AstroImage}, A::AstroImage) = A
Base.convert(::Type{AstroImage}, A::AbstractArray) = AstroImage(A)
Base.convert(::Type{AstroImage{T}}, A::AstroImage{T}) where {T} = A
Base.convert(::Type{AstroImage{T}}, A::AstroImage) where {T} = shareheader(A, convert(AbstractArray{T}, arraydata(A)))
Base.convert(::Type{AstroImage{T}}, A::AbstractArray{T}) where {T} = AstroImage(A)
Base.convert(::Type{AstroImage{T}}, A::AbstractArray) where {T} = AstroImage(convert(AbstractArray{T}, A))

# TODO: share headers in View. Needs support from DimensionalData.

"""
    emptyheader()

Convenience function to create a FITSHeader with no keywords set.
"""
emptyheader() = FITSHeader(String[],[],String[])


include("wcs.jl")
include("imview.jl")
include("showmime.jl")
include("plot-recipes.jl")

include("ccd2rgb.jl")
# include("patches.jl")
using UUIDs

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
    # TODO: How to add FileIO support for fits.gz files? We can open these
    # with AstroImage("...fits.gz") but not load, since the .gz takes precedence.
    # add_format(format"FITS.GZ",
    #     [0x1f, 0x8b, 0x08],
    #     [".fits.gz", ".fts.gz", ".FIT.gz", ".FITS.gz", ".FTS.gz"],
    #     [:FITSIO => UUID("525bcba6-941b-5504-bd06-fd0dc1a4d2eb")],
    #     [:AstroImages => UUID("fe3fc30c-9b16-11e9-1c73-17dabf39f4ad")]
    # )
    
end

end # module


#=
TODO:


* properties?
* contrast/bias?
* interactive (Jupyter)
* Plots & Makie recipes
* RGB and other composites
* tests
* histogram equaization

* FileIO Registration. 
* fits.gz support
* Table wrapper for TableHDUs that preserves comment access, units.
* Reading/writing subbarrays
* Specifying what kind of table, ASCII or TableHDU when wriring.

* FITSIO PR/issue (performance)
* PlotUtils PR/issue (zscale with iteratble)

=#