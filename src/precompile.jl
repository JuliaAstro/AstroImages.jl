


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
    precompile(parent, (TI,))
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


# From trace-compile:
precompile(Tuple{typeof(AstroImages.imview), Array{Float64, 2}})
precompile(Tuple{AstroImages.var"#imview##kw", NamedTuple{(:clims, :stretch, :cmap, :contrast, :bias), Tuple{AstroImages.Percent, typeof(Base.identity), Symbol, Int64, Float64}}, typeof(AstroImages.imview), AstroImages.AstroImage{Float64, 2, Tuple{DimensionalData.Dimensions.X{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}, DimensionalData.Dimensions.Y{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}}, Tuple{}, Array{Float64, 2}, Tuple{DimensionalData.Dimensions.X{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}, DimensionalData.Dimensions.Y{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}}}})
precompile(Tuple{AstroImages.var"#imview_colorbar##kw", NamedTuple{(:clims, :stretch, :cmap, :contrast, :bias), Tuple{AstroImages.Percent, typeof(Base.identity), Symbol, Int64, Float64}}, typeof(AstroImages.imview_colorbar), AstroImages.AstroImage{Float64, 2, Tuple{DimensionalData.Dimensions.X{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}, DimensionalData.Dimensions.Y{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}}, Tuple{}, Array{Float64, 2}, Tuple{DimensionalData.Dimensions.X{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}, DimensionalData.Dimensions.Y{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}}}})
