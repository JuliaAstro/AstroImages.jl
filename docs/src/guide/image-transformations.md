# Image Transformations

The [ImageTransformations.jl](https://juliaimages.org/latest/pkgs/transformations/) package contains many useful functions for manipulating astronomical images.

Note however that many of these functions drop the AstroImage wrapper and return plain arrays or OffsetArrays. They can be re-wrapped using `copyheader` or `shareheader` if you'd like to preserve the FITS header, dimension labels, WCS information, etc.

You can install ImageTransformations by running `] add ImageTransformations` at the REPL.

```@setup transforms
using AstroImages
AstroImages.set_clims!(Percent(99.5))
AstroImages.set_cmap!(:magma)
AstroImages.set_stretch!(identity)
```

For these examples, we'll download an image of the Antenae galaxies from Hubble:

```@example transforms
using AstroImages
using ImageTransformations
using Downloads: download

antblue = load(download("https://esahubble.org/static/projects/fits_liberator/datasets/antennae/blue.fits"))

# We'll change the defaults to avoid setting them each time
AstroImages.set_clims!(Percent(99))
AstroImages.set_cmap!(:ice)
AstroImages.set_stretch!(asinhstretch)

imview(antblue)
```

## Rotations

We can rotate images using the `imrotate` function:

```@example transforms
imrotate(antblue, 3π/4) |> imview
```

The rotation angle is in radians, but you can use the function `rad2deg` to convert from degrees.

## Resizing

We can resize images using the `imresize` function:

```@example transforms
imresize(antblue; ratio = 0.2) |> imview
```

## Arbitrary Transformations

Arbitrary transformations can be performed using ImageTransformation's `warp` function. See the documentation linked above for more details.

## Mapping from One Coordinate System to Another

For transforming an image from one coordiante system (say, RA & DEC) to another (e.g., galactic lattitude & logitude), see [Reprojecting Images](@ref).
