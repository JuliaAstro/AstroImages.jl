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
#   * Signed integers are mapped to [-1, 1) with Fixed type
#   * Unsigned integers are mapped to [0, 1] with Normed type
_float(x::AbstractFloat) = x
for n in (8, 16, 32, 64)
    SIT = Symbol("Int", n) # signed integer type
    FPT = Expr(:curly, :Fixed, SIT, n-1) # fixed-point type for signed float
    UIT = Symbol("UInt", n) # unsigned integer type
    NIT = Symbol("N0f", n) # fixed-point type for unsigned float
    @eval begin
        _float(x::$SIT) = reinterpret($FPT, x)
        _float(x::$UIT) = reinterpret($NIT, x)
    end
end

struct AstroImage{T<:Color}
    data::Matrix{T}
end

"""
    AstroImage(filename::String, n::Int=1)

Create an `AstroImage` object by reading the `n`-th extension from FITS file `filename`.
"""
AstroImage(file::String, ext::Int=1) =
    AstroImage(Gray.(_float.(load(file, 1))))

Base.convert(::Type{Matrix{T}}, img::AstroImage{T}) where {T<:Color} = img.data
Base.convert(::Type{Matrix{T}}, img::AstroImage{S}) where {T<:Color, S<:T} = img.data

include("showmime.jl")
include("plot-recipes.jl")

end # module
