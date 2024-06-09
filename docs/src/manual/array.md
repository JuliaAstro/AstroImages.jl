# Array Operations

You can operate on an [`AstroImage`](@ref AstroImage) like any other Julia array.


```@example 1
using AstroImages

img = AstroImage(randn(10,10))
```

## Indexing
You can look up individual pixels (see [Conventions](@ref Conventions))
```@example 1
img[1,1] # Bottom left
```

```@example 1
img[1:5,1:5]
```

## Broadcasting
AstroImages participate in broadcasting as expected:
```@example 1
@. img + img^2 + 2img^3
```

You can update them in-place (if the underlying array you passed supports mutation)
```@example 1
img[1:5,:] .= 0
img
```
