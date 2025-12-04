# Preserving the AstroImage Wrapper

Wherever possible, overloads have been added to DimensionalData and AstroImages so that common operations retain the `AstroImage` wrapper with associated dimensions, FITS header, and WCS information. Most of the time this works automatically if libraries follow good patterns like allocating outputs using `Base.similar`.
However, some other library functions may follow patterns like allocating a plain `Array` of the correct size and then filling it.

To make it easier to work with these libraries, AstroImages exports two functions [`copyheader`](@ref) and [`shareheader`](@ref). These functions wrap an AbstractArray in an AstroImage while copying over the header, dimensions, and WCS info.

Consider the function:

```julia
function badfunc(arr)
    out = zeros(size(arr)) # instead of similar(arr)
    out .= arr.^2
    return out
end
```

Calling `badfunc(astroimg)` will return a plain `Array` .

We can use `copyheader` to retain the `AstroImage` wrapper:

```julia
copyheader(astroimg, badfunc(astroimg))
```

For particularly incompatible functions that require an Array (not subtype of AbstractArray) we can go one step further:

```julia
copyheader(astroimg, worsefunc(parent(astroimg)))

# Or:
copyheader(astroimg, worsefunc(collect(astroimg)))
```
