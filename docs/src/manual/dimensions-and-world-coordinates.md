# Dimensions and World Coordinates

AstroImages are based on [Dimensional Data](https://github.com/rafaqz/DimensionalData.jl). Each axis is assigned a dimension name
and the indices are tracked.
The automatic dimension names are `X`, `Y`, `Z`, `Dim{4}`, `Dim{5}`, and so on; however you can pass in other names or orders to the load function and/or AstroImage contructor:

```julia
julia> img = load("img.fits",1,(Y=1:1600,Z=1:1600))
1600×1600 AstroImage{Float32,2} with dimensions:
  Y Sampled 1:1600 ForwardOrdered Regular Points,
  Z Sampled 1:1600 ForwardOrdered Regular Points
```
Other useful dimension names are `Spec` for spectral axes, `Pol` for polarization data, and `Ti` for time axes.

These will be further discussed in Dimensions and World Coordinates.

For certain applications, it may be useful to use offset axes or axes with different steps. 
```julia
julia> img = load("img.fits",1,(X=801:2400,Y=1:2:3200))
1600×1600 AstroImage{Float32,2} with dimensions:
  X Sampled 801:2400 ForwardOrdered Regular Points,
  Y Sampled 1:2:3199 ForwardOrdered Regular Points
...
```

Unlike OffsetArrays, the usual indexing remains so `img[1,1]` is still the bottom left of the image;
however, data can be looked up according to the offset axes when using specifiers:
```julia
julia> img[X=Near(2000),Y=1..100]
50-element AstroImage{Float32,1} with dimensions:
  Y Sampled 1:2:99 ForwardOrdered Regular Points
and reference dimensions:
  X Sampled 2000:2000 ForwardOrdered Regular Points
  0.0
```

