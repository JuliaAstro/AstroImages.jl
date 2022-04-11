


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


# From trace-compile:
precompile(Tuple{typeof(AstroImages.imview), Array{Float64, 2}})
precompile(Tuple{AstroImages.var"##imview#60", AstroImages.Percent, Function, Symbol, Float64, Float64, typeof(AstroImages.imview), Array{Float64, 2}})
precompile(Tuple{typeof(AstroImages._imview), Base.SubArray{Float64, 2, Array{Float64, 2}, Tuple{Base.StepRange{Int64, Int64}, Base.Slice{Base.OneTo{Int64}}}, false}, MappedArrays.ReadonlyMappedArray{Any, 2, Base.SubArray{Float64, 2, Array{Float64, 2}, Tuple{Base.StepRange{Int64, Int64}, Base.Slice{Base.OneTo{Int64}}}, false}, AstroImages.var"#118#119"{Float64}}, typeof(Base.identity), ColorSchemes.ColorScheme{Array{ColorTypes.RGB{Float64}, 1}, String, String}, Float64, Float64})
precompile(Tuple{AstroImages.var"#imview##kw", NamedTuple{(:clims, :stretch, :cmap, :contrast, :bias), Tuple{AstroImages.Percent, typeof(Base.identity), Symbol, Int64, Float64}}, typeof(AstroImages.imview), AstroImages.AstroImage{Float64, 2, Tuple{DimensionalData.Dimensions.X{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}, DimensionalData.Dimensions.Y{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}}, Tuple{}, Array{Float64, 2}, Tuple{DimensionalData.Dimensions.X{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}, DimensionalData.Dimensions.Y{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}}}})
precompile(Tuple{typeof(AstroImages._imview), Base.SubArray{Float64, 2, Array{Float64, 2}, Tuple{Base.StepRange{Int64, Int64}, Base.Slice{Base.OneTo{Int64}}}, false}, MappedArrays.ReadonlyMappedArray{Any, 2, Base.SubArray{Float64, 2, Array{Float64, 2}, Tuple{Base.StepRange{Int64, Int64}, Base.Slice{Base.OneTo{Int64}}}, false}, AstroImages.var"#118#119"{Float64}}, typeof(Base.identity), ColorSchemes.ColorScheme{Array{ColorTypes.RGB{Float64}, 1}, String, String}, Int64, Float64})
precompile(Tuple{AstroImages.var"#imview_colorbar##kw", NamedTuple{(:clims, :stretch, :cmap, :contrast, :bias), Tuple{AstroImages.Percent, typeof(Base.identity), Symbol, Int64, Float64}}, typeof(AstroImages.imview_colorbar), AstroImages.AstroImage{Float64, 2, Tuple{DimensionalData.Dimensions.X{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}, DimensionalData.Dimensions.Y{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}}, Tuple{}, Array{Float64, 2}, Tuple{DimensionalData.Dimensions.X{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}, DimensionalData.Dimensions.Y{DimensionalData.Dimensions.LookupArrays.Sampled{Int64, Base.OneTo{Int64}, DimensionalData.Dimensions.LookupArrays.ForwardOrdered, DimensionalData.Dimensions.LookupArrays.Regular{Int64}, DimensionalData.Dimensions.LookupArrays.Points, DimensionalData.Dimensions.LookupArrays.NoMetadata}}}}})