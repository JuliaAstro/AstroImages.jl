


for T in [Float32, Float64, Int, Int8, UInt8, N0f8]

    a = rand(T, 5, 5)
    i = AstroImage(a)
    for stretch in [
        logstretch,
        powstretch,
        sqrtstretch,
        squarestretch,
        asinhstretch,
        sinhstretch,
        powerdiststretch
    ]
        # Easiest way to precompile everything we need is just to call these functions.
        # They have no side-effects.
        imview(a; stretch)

        # And precompile on an astroimage
        imview(i; stretch)
    end
    TI = typeof(i)
    precompile(arraydata, (TI,))
    precompile(header, (TI,))
    precompile(wcs, (TI,))
    precompile(getindex, (TI, Symbol))
    precompile(getindex, (TI, String))
    precompile(getindex, (TI, Int))
    precompile(getindex, (TI, Int, Int))
    precompile(getindex, (TI, Vector{Int}))
    precompile(getindex, (TI, Vector{Bool}))
    precompile(getindex, (TI, Matrix{Bool}))
    precompile(setindex!, (TI, Matrix{Bool}))
    precompile(world_to_pix, (TI, Vector{Float64}))
    precompile(pix_to_world, (TI, Vector{Float64}))
end