# Dimensions and World Coordinates

AstroImages are based on [DimensionalData.jl](https://github.com/rafaqz/DimensionalData.jl). Each axis is assigned a dimension name and the indices are tracked.

```@setup coords
using AstroImages
using DimensionalData
using AstroImages: restrict

AstroImages.set_clims!(Percent(99.5))
AstroImages.set_cmap!(:magma)
AstroImages.set_stretch!(identity)
```

## World Coordinates

FITS files with world coordinate system (WCS) headers contain all the information necessary to map a pixel location
into celestial coordinates & back.

Let's see how this works with a 2D image with RA & DEC coordinates:

```@example coords
using AstroImages
using Plots
using Downloads: download

# Download a Hubble image of the Eagle nebula
eagle = load(download("https://ds9.si.edu/download/data/656nmos.fits"))
```

This image contains world coordinate system headers. AstroImages.jl uses WCS.jl (and wcslib under the hood) to parse these headers. We can generate a WCSTransform object to inspect:

```@example coords
wcs(eagle, 1) # specify which coordinate system
```

Note that we specify with an index which coordinate system we'd like to use. Most images just contain one, but some contain multiple systems.

We can look up a coordinate from the image:

```@example coords
world = pix_to_world(eagle, [1, 1]) # Bottom left corner
```

Or convert back from world coordinates to pixel coordinates. We can lookup a coordinate from the image:

```@example coords
world_to_pix(eagle, world) # Bottom left corner
```

These pixel coordinates do not necessarily have to lie within the bounds of the original image, and in general lie at a fractional pixel position.

If an image contains WCS headers, we can visualize them using [`implot`](@ref):

```@example coords
implot(eagle)
```

We can adjust the color of the grid:

```@example coords
implot(eagle; gridcolor = :cyan)
```

If these aren't desired, we can turn off the grid or the WCS tick marks:

```@example coords
plot(
  implot(eagle; grid = false),
  implot(eagle, wcsticks = false);
  size = (900, 300),
  bottommargin = 10Plots.mm,
)
```

Since AstroImages are based on DimensionalData's AbstractDimArray, the mapping between pixel coordinates and world coordinates are preserved when slicing an AstroImage:

```@example coords
slice1 = eagle[1:800, 1:800]
slice2 = eagle[800:1600, 1:800]
plot(
  implot(slice1),
  implot(slice2);
  size = (900, 300),
  bottommargin = 10Plots.mm,
)
```

World coordinate queries from that slice are aware of their position in the parent image:

```@example coords
@show pix_to_world(slice1, [1, 1])
```

```@example coords
@show pix_to_world(slice2, [1, 1])
```

Note that you can query the dimensions of an image using the [`dims`](@extref DimensionalData.Dimensions.dims) function from DimensionalData:

```@example coords
dims(slice2)
```

## Named Dimensions

Each dimension of an AstroImage is named. The automatic dimension names are `X`, `Y`, `Z`, `Dim{4}`, `Dim{5}`, and so on; however you can pass in other names or orders to the load function and/or AstroImage contructor:

```julia-repl
julia> img = load("eagle-656nmos.fits", 1, (Y,Z))
1600×1600 AstroImage{Float32,2} with dimensions:
  Y Sampled 1:1600 ForwardOrdered Regular Points,
  Z Sampled 1:1600 ForwardOrdered Regular Points
```

Other useful dimension names are `Spec` for spectral axes, `Pol` for polarization data, and `Ti` for time axes. These are tracked the same way as the automatic dimension names and interact smoothly with any WCS headers. You can give a dimension an arbitrary name using `Dim{Symbol}`, e.g., `Dim{:Velocity}`.

You can access AstroImages using dimension names:

```@example coords
eagle[X = 100]
```

When indexing into a slice out of a larger parent image or cube, this named access refers to the *parent* dimensions:

```@example coords
slice1 = eagle[600:800, 600:800]
slice1[X=At(700), Y=At(700)] == eagle[X=At(700), Y=At(700)] == eagle[700, 700]
```

## Cubes

Let's see how this works with a 3D cube.

```@example coords
using AstroImages

HIcube = load(download("https://www.astropy.org/astropy-data/tutorials/FITS-cubes/reduced_TAN_C14.fits"))
```

Notice how the cube is not displayed automatically. We have to pick a specific slice:

```@example coords
HIcube[Z = 228]
```

Using [`implot`](@ref), the world coordinates are displayed automatically:

```@example coords
implot(HIcube[Z = 228]; cmap = :turbo)
```

The plot automatically reflects the world coordinates embeded in the file. It displays the x axis in galactic longitude, the y-axis in galactic latitude, and even shows the curved projection from pixel coordinates to galactic coordinates. The title is automatically set to the world coordinate along the Z axis in units of velocity. It also picks up the unit of the data (Kelvins) to display on the colorbar.

If we pick another slice, the title updates accordingly:

```@example coords
implot(HIcube[Z = 308]; cmap = :turbo)
```

This works for other slices through the cube as well:

```@example coords
implot(HIcube[Y = 45]; cmap = :turbo, aspectratio = 0.3)
```

## Custom Dimensions

```julia-repl
julia> img = load("img.fits",1,(Y=1:1600,Z=1:1600))
1600×1600 AstroImage{Float32,2} with dimensions:
  Y Sampled 1:1600 ForwardOrdered Regular Points,
  Z Sampled 1:1600 ForwardOrdered Regular Points
```

Other useful dimension names are `Spec` for spectral axes, `Pol` for polarization data, and `Ti` for time axes. These are tracked the same was as the automatic dimension names and interact smoothly with any WCS headers.

Often times we have images or cubes that we want to index with physical coordinates where setting up a full WCS transform is overkill. In these cases, it's easier to leverage custom dimensions.

For example, one may wish to

```julia-repl
julia> img = load("img.fits", 1, (X=801:2400, Y=1:2:3200))
1600×1600 AstroImage{Float32,2} with dimensions:
  X Sampled 801:2400 ForwardOrdered Regular Points,
  Y Sampled 1:2:3199 ForwardOrdered Regular Points
...
```

Unlike OffsetArrays, the usual indexing remains so `img[1, 1]` is still the bottom left of the image; however, data can be looked up according to the offset dimensions using specifiers:

```julia-repl
julia> img[X=Near(2000), Y=1..100]
50-element AstroImage{Float32,1} with dimensions:
  Y Sampled 1:2:99 ForwardOrdered Regular Points
and reference dimensions:
  X Sampled 2000:2000 ForwardOrdered Regular Points
  0.0
```

You can adjust the center of an image's dimensions using [`recenter`](@ref):

```@example coords
eagle_cen = recenter(eagle, 801, 801);
```

Unlike an OffsetArray, `eagle_cen[1,1]` still refers to the bottom left of the image. This also has no effect on broadcasting; `eagle_cen .+ ones(1600,1600)` is perfectly valid. However, we see the new centered dimensions when we go to plot the image:

```@example coords
implot(eagle_cen; wcsticks = false)
```

And we can query positions using the offset dimensions:

```@example coords
implot(eagle_cen[X=-300..300, Y=-300..300]; wcsticks = false)
```
