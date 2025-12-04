# Loading & Saving Images

FITS (Flexible Image Transport System) files can be loaded and saved using AstroImages thanks to the [FITSIO.jl](https://github.com/JuliaAstro/FITSIO.jl) package.

AstroImages is registered with [FileIO.jl](https://juliaio.github.io/FileIO.jl/stable/), so if both packages are installed the `FileIO.load` function will work seamlessly with astronomical data. When you pass a file name with the appropriate file extension (".fits", ".fit", ".fits.gz", etc.), FileIO will import AstroImages automatically. For convenience, we also reexport this function from AstroImages:

```julia
using AstroImages

img = load("myfitsimg.fits");
```

!!! note
    FITS files from the web can also be downloaded and opened:

    ```julia
    using Downloads: download

    download("https://website/longfitsfilename.fits", "shortname.fits")

    img = load("shortname.fits");
    ```

You can also use the `AstroImage` constructor directly, which works on `AbstractArray` data as well:

```@repl astroimage
using AstroImages

img = AstroImage(zeros(1600, 1600))
```

!!! tip
    If you are in an interactive environment like VSCode, Jupyter, or Pluto, instead of a REPL, AstroImages are automatically rendered to images and displayed. You can see this plain text output by explicitly calling: `display(img)`.

A FITS file can contain multiple N-dimensional images and tables. When you call `load` or `AstroImage` with a file name and no other arguments, the package will search through the file and return the first image HDU. That is, it will skip any FITS tables or empty HDUs with only headers.

You can also specify an HDU number explicitly:

```julia
img = load("myfitsimg.fits", 1);
```

This way, you can load specific images from multi-extension files.

You can load all HDUs simultaneously by passing `:`:

```julia
hdus = load("multiext.fits", :);

hdus[2]; # Second HDU as an AstroImage

hdu1, hdu2, hdu3 = load("multiext.fits", :); # Can also unpack multiple HDUs
```

There is also limited support for table HDUs. In this case, a bare-bones Tables.jl compatible object is returned.

## Dimension Names

You may have noticed the entries above the image array:

```
┌ 1600×1600 AstroImage{Float64, 2} ┐
├──────────────────────────────────┴──────────────────────────── dims ┐
  ↓ X Sampled{Int64} Base.OneTo(1600) ForwardOrdered Regular Points,
  → Y Sampled{Int64} Base.OneTo(1600) ForwardOrdered Regular Points
└─────────────────────────────────────────────────────────────────────┘
```

AstroImages are based on [DimensionalData.jl](https://github.com/rafaqz/DimensionalData.jl). Each axis is assigned a dimension name and the indices are tracked. The automatic dimension names are `X`, `Y`, `Z`, `Dim{4}`, `Dim{5}`, and so on; however you can pass in other names or orders to the load function and/or AstroImage contructor:

```@repl astroimage
img = AstroImage(zeros(1600, 1600), (Y=1:1600, Z=1:1600))
```

Other useful dimension names are `Spec` for spectral axes, `Pol` for polarization data, and `Ti` for time axes.

These will be further discussed in [Dimensions and World Coordinates](@ref).

## Saving Images
You can save one or more AstroImages and tables to a FITS file using the `save` function:

```julia
save("abc.fits", astroimage1, astroimage2, table1)
```

You can also save individual images to traditional graphics formats by first rendering them with `imview` (for more on `imview`, see [Displaying Images](@ref)):

```julia
save("abc.png", imview(astroimage1))
```

You can save animated GIFs by saving a 3D datacube that has been rendered with `imview`:

```julia
cube =  imview(AstroImage(randn(100, 100, 10)));
save("abc.gif", cube; fps = 10)

# Or a more complex example (changing color schemes each frame)
img = randn(10, 10)
cube2 = [imview(img; cmap = :magma) ;;; imview(img; cmap = :plasma) ;;; imview(img; cmap = :viridis)];

# Alternative syntax:
cube2 = cat(imview(img, cmap=:magma), imview(img, cmap=:plasma), imview(img, cmap=:viridis); dims = 3);
save("abc.gif", cube; fps=10)
```
