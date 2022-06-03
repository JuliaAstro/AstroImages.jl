# Displaying Images


Any AbstractArray (including an AstroImage) can be displayed using `imview`. This function renders an
arbitrary array into an array of `RGBA` values using a number of parameters. If the input is an AstroImage{<:Number},
an AstroImage{RGBA} will be returned that retains headers, WCS information, etc.

```@setup 1
using AstroImages
using Plots
```

The defaults for the `imview` function are:
```@example 1
img = randn(50,50);
imview(img; clims=Percent(99.5), cmap=:magma, stretch=identity, contrast=1.0, bias=0.5)
```

We can adjust the color limits explicitly:
```@example 1
imview(img; clims=(-1, 1))
```

Or pass a function/callable object to calculate them for us:
```@example 1
imview(img; clims=Zscale())
```

We turn off the colormap and use it in grayscale mode:
```@example 1
imview(img; cmap=nothing)
```

Pass any color scheme from ColorSchemes.jl:
```@example 1
imview(img; cmap=:ice)
```
```@example 1
imview(img; cmap=:seaborn_rocket_gradient)
```

Or an RGB or named color value:
```@example 1
imview(img; cmap="#F00")
imview(img; cmap="red")
```

Let's now switch to an astronomical image:
```@example 1
fname = download(
    "http://www.astro.uvic.ca/~wthompson/astroimages/fits/656nmos.fits",
    "eagle-656nmos.fits"
);
img = AstroImage("eagle-656nmos.fits")
```

We can apply a non-linear stretch like a log-scale, power-scale, or asinh stretch:
```@example 1
imview(img, stretch=asinhstretch)
```

Once rendered, we can also tweak the bias and contrast:
```@example 1
imview(img, stretch=asinhstretch, contrast=1.5)
```
```@example 1
imview(img, stretch=asinhstretch, contrast=1.5, bias=0.6)
```
These are the parameters that change when you click and drag in some applications like DS9.

Once rendered via `imview`, the resulting image can be saved in traditional image formats like PNG, JPG, GIF, etc:
```julia
save("out.png", imview(img, cmap=:viridis))
```

Very large Images are automatically downscaled to ensure consistent performance using `restrict` from Images.jl. This function filters the data before downscaling to prevent aliasing, so it may take a moment for truly huge images. In these cases, a faster method that doesn't prevent aliasing would be `imview(img[begin:10:end, begin:10:end])` or similar.

`imview` is called automatically on `AstroImage{<:Number}` when using a Julia environment with rich graphical IO capabilities (e.g. VSCode, Jupyter, Pluto, etc.).
The defaults for this case can be modified using `AstroImages.set_clims!(...)`, `AstroImages.set_cmap!(...)`, and `AstroImages.set_stretch!(...)`.
