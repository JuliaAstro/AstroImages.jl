using AbstractFFTs

for f in [
    :(AbstractFFTs.fft),
    :(AbstractFFTs.bfft),
    :(AbstractFFTs.ifft),
    :(AbstractFFTs.fft!),
    :(AbstractFFTs.bfft!),
    :(AbstractFFTs.ifft!),
    :(AbstractFFTs.rfft),
]
    # TODO: should we try to alter the image headers to change the units?
    @eval ($f)(img::AstroImage, args...; kwargs...) = copyheader(img, $f(arraydata(img)))
end

for f in [
    :(AbstractFFTs.fftshift),
]
    # TODO: should we try to alter the image headers to change the units?
    @eval ($f)(img::AstroImage, args...; kwargs...) = shareheader(img, $f(arraydata(img)))
end




# AbstractFFTs.complexfloat(img::AstroImage{T,N,D,R,StridedArray{T}}) where {T<:Complex{<:BlasReal}} = img
# AbstractFFTs.realfloat(img::AstroImage{T,N,D,R,StridedArray{T}}) where {T<:BlasReal} = img
