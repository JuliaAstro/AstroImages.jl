__precompile__()

module AstroImages

using FITSIO, FileIO, Images

export load

FileIO.load(f::File{format"FITS"}, ext::Int) = read(FITS(f.filename)[ext])

function FileIO.load(f::File{format"FITS"}, ext::NTuple{N,Int}) where {N}
    fits = FITS(f.filename)
    return ntuple(i -> read(fits[ext[i]]), N)
end

struct AstroImage{T<:Color}
    data::Matrix{T}
end

end # module
