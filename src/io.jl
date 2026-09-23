## Loading

"""
    AstroImage(hdus::AbstractVector{<:HDU}, ext::Int=1)

Given FITS HDUs read by FITSFiles, load HDU number `ext` as an AstroImage.
"""
AstroImage(hdus::AbstractVector{<:HDU}, ext::Int, args...; kwargs...) =
    AstroImage(hdus[ext], args...; kwargs...)
function AstroImage(hdus::AbstractVector{<:HDU}; kwargs...)
    ext = indexer(hdus)
    return AstroImage(hdus[ext]; kwargs...)
end

"""
    AstroImage(hdu::HDU)

Given a FITSFiles HDU, load it as an AstroImage.
"""
AstroImage(hdu::HDU, args...; kwargs...) = _loadhdu(hdu, args...; kwargs...)

"""
    img = AstroImage(filename::AbstractString, ext::Integer=1; scale=true)

Load an image HDU `ext` from the FITS file at `filename` as an AstroImage.

Set `scale=false` to load the data exactly as stored on disk, without applying
the `BSCALE` and `BZERO` keywords.
"""
function AstroImage(filename::AbstractString, ext::Integer, args...; scale = true, kwargs...)
    hdus = fits(filename; scale)
    return AstroImage(hdus[ext], args...; kwargs...)
end
"""
    img1, img2 = AstroImage(filename::AbstractString, exts; scale=true)

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
function AstroImage(
        filename::AbstractString,
        exts::Union{NTuple{N, <:Integer}, AbstractArray{<:Integer}},
        args...;
        scale = true,
        kwargs...
    ) where {N}
    hdus = fits(filename; scale)
    return map(exts) do ext
        return AstroImage(hdus[ext], args...; kwargs...)
    end
end
function AstroImage(filename::AbstractString; scale = true, kwargs...)
    hdus = fits(filename; scale)
    ext = indexer(hdus)
    return AstroImage(hdus[ext]; kwargs...)
end
function AstroImage(filename::AbstractString, ::Colon, args...; scale = true, kwargs...)
    hdus = fits(filename; scale)
    return map(hdus) do hdu
        return AstroImage(hdu, args...; kwargs...)
    end
end


"""
    load(fitsfile::String)

Read and return the data from the first image HDU in a FITS file
as an AstroImage. If no image HDUs are present, an error is returned.

    load(fitsfile::String, ext::Int)

Read and return the data from the HDU `ext`. If it is an image HDU,
an AstroImage is returned. If it is a table HDU, a plain Julia
column table is returned.

    load(fitsfile::String, :)

Read and return the data from each HDU in an FITS file. Image HDUs are
returned as AstroImage, and table HDUs are returned as column tables.

    load(fitsfile::String, exts::Union{NTuple, AbstractArray})

Read and return the data from the HDUs given by `exts`. Image HDUs are
returned as AstroImage, and table HDUs are returned as column tables.

All of these accept a `scale` keyword, forwarded to FITSFiles. It defaults to
`true`, applying the `BSCALE` and `BZERO` keywords to the data; pass
`scale=false` to read the values exactly as stored on disk.

!!! Currently any header on table HDUs are not supported and are ignored.
"""
function fileio_load(f::File{format"FITS"}, ext::Union{Int, Nothing} = nothing, args...; scale = true, kwargs...)
    hdus = fits(f.filename; scale)
    if isnothing(ext)
        ext = indexer(hdus)
    end
    return _loadhdu(hdus[ext], args...; kwargs...)
end
function fileio_load(f::File{format"FITS"}, exts::Union{NTuple{N, <:Integer}, AbstractArray{<:Integer}}, args...; scale = true, kwargs...) where {N}
    hdus = fits(f.filename; scale)
    return map(exts) do ext
        _loadhdu(hdus[ext], args...; kwargs...)
    end
end
function fileio_load(f::File{format"FITS"}, ::Colon, args...; scale = true, kwargs...)
    hdus = fits(f.filename; scale)
    return map(hdus) do hdu
        _loadhdu(hdu, args...; kwargs...)
    end
end

# Header cards attached to an HDU, normalized to the invariant `Vector{Card}`
# element type that the AstroImage struct field stores.
_headercards(hdu::HDU) = convert(FITSHeader, hdu.cards)

# Convert a FITSFiles HDU into the appropriate Julia object: image HDUs become
# AstroImages, table HDUs become column tables (NamedTuples).
function _loadhdu(hdu::HDU, args...; kwargs...)
    data = hdu.data
    if data isa NamedTuple
        # Table HDU -> Tables.jl column table
        return data
    elseif data === missing || (data isa AbstractArray && size(data) == ())
        # Sometimes files have an empty data HDU that shows up as an image HDU
        # but has headers. Fall back to creating an empty AstroImage with those
        # headers.
        emptydata = fill(missing)
        return AstroImage(emptydata, (), (), _headercards(hdu), Dict(' ' => emptywcs(emptydata)), Ref(false), ())
    else
        return AstroImage(collect(data), args..., _headercards(hdu); kwargs...)
    end
end

# Index of the first image HDU (at least 1D) in a list of HDUs.
function indexer(hdus::AbstractVector{<:HDU})
    ext = 0
    for (i, hdu) in enumerate(hdus)
        data = hdu.data
        if data isa AbstractArray && ndims(data) >= 1 && size(data) != () # check if Image is atleast 1D
            ext = i
            break
        end
    end
    if ext > 1
        @info "Image was loaded from HDU $ext"
    elseif ext == 0
        error("There are no image HDU extensions in the FITS file")
    end
    return ext
end


## Saving

# Fallback for saving arbitrary arrays
function fileio_save(f::File{format"FITS"}, args...)
    return writefits(f.filename, args...)
end

# Structural / column-descriptor keywords are regenerated by FITSFiles from the
# data when building an HDU, so drop any copies carried in the AstroImage header
# to avoid duplicate or conflicting cards on write.
const _STRUCTURAL_HEADER_KEYS = Set(
    [
        "SIMPLE", "BITPIX", "NAXIS", "EXTEND", "PCOUNT", "GCOUNT", "XTENSION", "END",
        "BSCALE", "BZERO", "TFIELDS",
    ]
)
function _writablecards(cards::FITSHeader)
    return Card[
        c for c in cards
            if !(uppercase(c.key) in _STRUCTURAL_HEADER_KEYS) &&
            !occursin(r"^NAXIS\d+$", uppercase(c.key)) &&
            !occursin(r"^T(TYPE|FORM|UNIT|SCAL|ZERO|DIM|NULL|DISP)\d+$", uppercase(c.key))
    ]
end

"""
    writefits("abc.fits", img1, img2, table1,...)

Write arguments to a FITS file.

See also [`FileIO.save`](@ref)
"""
function writefits(fname, args...)
    hdus = HDU[]
    for arg in args
        # A FITS file must begin with a Primary (image) HDU. If the first
        # argument is a table, prepend an empty Primary HDU.
        if isempty(hdus) && !_isimagearg(arg)
            push!(hdus, HDU(FITSFiles.Primary, missing))
        end
        push!(hdus, _tohdu(arg, isempty(hdus)))
    end
    write(fname, hdus)
    return
end

_isimagearg(::AbstractArray) = true
_isimagearg(_) = false

parent_recurse(img::AbstractArray) = img
parent_recurse(img::AstroImage) = parent_recurse(parent(img))

# Build an HDU for a writeable argument. `primary=true` requests a Primary HDU
# (only valid as the first HDU in a file); otherwise an image extension HDU.
function _tohdu(img::AstroImage, primary::Bool)
    hdutype = primary ? FITSFiles.Primary : FITSFiles.Image
    return HDU(hdutype, collect(parent_recurse(img)), _writablecards(header(img)))
end
function _tohdu(arr::AbstractArray, primary::Bool)
    hdutype = primary ? FITSFiles.Primary : FITSFiles.Image
    return HDU(hdutype, collect(arr))
end
# For table compatible data.
# This allows users to round trip: dat = load("abc.fits", :); write("abc", dat)
# when it contains FITS tables.
function _tohdu(table, ::Bool)
    if !Tables.istable(table)
        error("Cannot save argument to FITS file. Value is not an AbstractArray or table.")
    end
    # TODO: In future, we want to be able to access and round-trip comments on
    # table HDUs.
    return HDU(FITSFiles.Bintable, Tables.columntable(table))
end
