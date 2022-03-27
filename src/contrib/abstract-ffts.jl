using AbstractFFTs

for f in [
    :(AbstractFFTs.plan_fft),
    :(AbstractFFTs.plan_bfft),
    :(AbstractFFTs.plan_ifft),
    :(AbstractFFTs.plan_fft!),
    :(AbstractFFTs.plan_bfft!),
    :(AbstractFFTs.plan_ifft!),
    :(AbstractFFTs.plan_rfft),
    :(AbstractFFTs.fftshift),
]
    # TODO: should we try to alter the image headers to change the units?
    @eval ($f)(img::AstroImage, args...; kwargs...) = copyheader(img, $f(arraydata(img)))
end


# AbstractFFTs.complexfloat(img::AstroImage{T,N,D,R,StridedArray{T}}) where {T<:Complex{<:BlasReal}} = img
# AbstractFFTs.realfloat(img::AstroImage{T,N,D,R,StridedArray{T}}) where {T<:BlasReal} = img
