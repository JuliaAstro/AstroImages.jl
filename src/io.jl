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