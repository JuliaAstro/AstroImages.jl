__precompile__()

module AstroImages

using FITSIO, FileIO, Images

export load, AstroImage


"""
    load(fitsfile::String, n=1)

Read and return the data from `n`-th extension of the FITS file.  Second argument can also
be a tuple of integers, in which case a tuple with the data of each corresponding extension
is returned.
"""
FileIO.load(f::File{format"FITS"}, ext::Int=1) = read(FITS(f.filename)[ext])

function FileIO.load(f::File{format"FITS"}, ext::NTuple{N,Int}) where {N}
    fits = FITS(f.filename)
    return ntuple(i -> read(fits[ext[i]]), N)
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

struct AstroImage{T<:Real,C<:Color}
    data::Matrix{T}
    minmax::Tuple{T,T}
end

"""
    AstroImage([color=Gray,] data::Matrix{Real})

Construct an `AstroImage` object of `data`, using `color` as color map, `Gray` by default.
"""
AstroImage(color::Type{<:Color}, data::Matrix{T}) where {T<:Real} =
    AstroImage{T,color}(data, extrema(data))
AstroImage(data::Matrix{T}) where {T<:Real} = AstroImage{T,Gray}(data, extrema(data))

"""
    AstroImage([color=Gray,] filename::String, n::Int=1)

Create an `AstroImage` object by reading the `n`-th extension from FITS file `filename`.
Use `color` as color map, this is `Gray` by default.
"""
AstroImage(color::Type{<:Color}, file::String, ext::Int=1) =
    AstroImage(color, load(file, ext))
AstroImage(file::String, ext::Int=1) = AstroImage(Gray, file, ext)

# Lazily reinterpret the image as a Matrix{Color}, upon request.
function render(img::AstroImage{T,C}) where {T,C}
    imgmin, imgmax = img.minmax
    # Add one to maximum to work around this issue:
    # https://github.com/JuliaMath/FixedPointNumbers.jl/issues/102
    f = scaleminmax(_float(imgmin), _float(max(imgmax, imgmax + one(T))))
    return colorview(C, f.(_float.(img.data)))
end

Images.colorview(img::AstroImage) = render(img)

include("showmime.jl")
include("plot-recipes.jl")

end # module
