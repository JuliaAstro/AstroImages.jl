__precompile__()

module AstroImages

using FITSIO, FileIO, Images, Interact

export load, AstroImage

_load(fits::FITS, ext::Int) = read(fits[ext])
_load(fits::FITS, ext::NTuple{N, Int}) where {N} = ntuple(i-> read(fits[ext[i]]), N)

"""
    load(fitsfile::String, n=1)

Read and return the data from `n`-th extension of the FITS file.

Second argument can also be a tuple of integers, in which case a 
tuple with the data of each corresponding extension is returned.
"""
function FileIO.load(f::File{format"FITS"}, ext::Int=1)
    fits = FITS(f.filename)
    out = _load(fits, ext)
    close(fits)
    return out
end

function FileIO.load(f::File{format"FITS"}, ext::NTuple{N,Int}) where {N}
    fits = FITS(f.filename)
    out = ntuple(i -> read(fits[ext[i]]), N)
    close(fits)
    return out
end

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

struct AstroImage{T<:Real,C<:Color, N}
    data::NTuple{N, Matrix{T}}
end

"""
    AstroImage([color=Gray,] data::Matrix{Real})
    AstroImage(color::Type{<:Color}, data::NTuple{N, Matrix{T}}) where {T<:Real, N}

Construct an `AstroImage` object of `data`, using `color` as color map, `Gray` by default.
"""
AstroImage(color::Type{<:Color}, data::Matrix{T}) where {T<:Real} =
    AstroImage{T,color, 1}((data,))
AstroImage(color::Type{<:Color}, data::NTuple{N, Matrix{T}}) where {T<:Real, N} =
    AstroImage{T,color, N}(data)
AstroImage(data::Matrix{T}) where {T<:Real} = AstroImage{T,Gray,1}((data, ))
AstroImage(data::NTuple{N, Matrix{T}}) where {T<:Real, N} = AstroImage{T,Gray,N}(data)

"""
    AstroImage([color=Gray,] filename::String, n::Int=1)
    AstroImage(color::Type{<:Color}, file::String, n::NTuple{N, Int}) where {N}

Create an `AstroImage` object by reading the `n`-th extension from FITS file `filename`.

Use `color` as color map, this is `Gray` by default.
"""
AstroImage(color::Type{<:Color}, file::String, ext::Int) =
    AstroImage(color, load(file, ext))
AstroImage(color::Type{<:Color}, file::String, ext::NTuple{N, Int}) where {N} =
    AstroImage(color, load(file, ext))

AstroImage(file::String, ext::Int) = AstroImage(Gray, file, ext)
AstroImage(file::String, ext::NTuple{N, Int}) where {N} = AstroImage(Gray, file, ext)

AstroImage(color::Type{<:Color}, fits::FITS, ext::Int) =
    AstroImage(color, _load(fits, ext))
AstroImage(color::Type{<:Color}, fits::FITS, ext::NTuple{N, Int}) where {N} =
    AstroImage(color, _load(fits, ext))
function AstroImage(file::String)
    fits = FITS(file)
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
        error("There are no ImageHDU extensions in \"$file\"")
    end
    out = AstroImage(Gray, fits, ext)
    close(fits)
    return out
end

# Lazily render the image as a Matrix{Color}, upon request.
function render(img::AstroImage{T,C,N}, header_number = 1) where {T,C,N}
    imgmin, imgmax = extrema(img.data[header_number])
    # Add one to maximum to work around this issue:
    # https://github.com/JuliaMath/FixedPointNumbers.jl/issues/102
    f = scaleminmax(_float(imgmin), _float(max(imgmax, imgmax + one(T))))
    return colorview(C, f.(_float.(img.data[header_number])))
end

Images.colorview(img::AstroImage) = render(img)

Base.size(img::AstroImage) = Base.size.(img.data)

Base.length(img::AstroImage{T,C,N}) where{T,C,N} = N

include("showmime.jl")
include("plot-recipes.jl")

end # module
