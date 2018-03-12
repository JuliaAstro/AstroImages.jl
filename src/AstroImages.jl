__precompile__()

module AstroImages

using FITSIO, FileIO

export load

FileIO.load(f::File{format"FITS"}, ext::Int) = read(FITS(f.filename)[ext])

function FileIO.load(f::File{format"FITS"}, ext::NTuple{N,Int}) where {N}
    fits = FITS(f.filename)
    return ntuple(i -> read(fits[ext[i]]), N)
end

end # module
