# Array Operations

You can operate on an [`AstroImage`](@ref) like any other Julia array:

```@example array
using AstroImages

img = AstroImage(randn(10, 10))
```

## Indexing

You can look up individual pixels (see [Conventions](@ref)):

```@example array
img[1, 1] # Bottom left
```

```@example array
img[1:5, 1:5]
```

## Broadcasting

AstroImages participate in broadcasting as expected:

```@example array
@. img + img^2 + 2img^3
```

You can update them in-place (if the underlying array you passed supports mutation):

```@example array
img[1:5, :] .= 0
img
```
