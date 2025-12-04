# AstroImages.jl

| **Documentation** | **Build Status**                          | **Code Coverage**               |
|:------------------|:-----------------------------------------:|:-------------------------------:|
| [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliaastro.org/AstroImages/stable/) [![](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaastro.org/AstroImages.jl/dev/) | [![CI](https://github.com/JuliaAstro/AstroImages.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaAstro/AstroImages.jl/actions/workflows/CI.yml) | [![codecov](http://codecov.io/github/JuliaAstro/AstroImages.jl/coverage.svg)](http://codecov.io/github/JuliaAstro/AstroImages.jl)

## Introduction

`AstroImages.jl` allows you load and visualize  images from a astronomical [`FITS`](https://en.wikipedia.org/wiki/FITS) files using the popular [`Images.jl`](https://github.com/JuliaImages/Images.jl) and [`Plots.jl`](https://github.com/JuliaPlots/Plots.jl) Julia packages. `AstroImages.jl` uses [`FITSIO.jl`](https://github.com/JuliaAstro/FITSIO.jl) to read FITS files.

## Installation

`AstroImages.jl` is available for Julia 1.6 and later versions, and can be installed with [Julia built-in package manager](https://docs.julialang.org/en/v1/stdlib/Pkg/).

```julia-repl
pkg> add AstroImages
```

You may also need to install `ImageIO.jl` for images to display in certain environments.

## Usage

After installing the package, you can start using it with:

```julia-repl
julia> using AstroImages
```

Images will automatically display in many environments, including VS Code, Jupyter, and Pluto. If you're using a REPL, you may want to install an external viewer like ImageShow.jl, ElectronDisplay.jl, or ImageInTerminal.jl.

## Reading extensions from FITS file

You can load and read the the first *image* extension of a FITS file with the `load` function, from [`FileIO.jl`](https://github.com/JuliaIO/FileIO.jl):

```julia-repl
julia> load("file.fits")
1300×1200 Array{UInt16,2}:
[...]
```

You may also pass an explicit extension number to load, which will return the data of that extension (image or table). Read the third extension of the file with:

```julia-repl
julia> load("file.fits", 3)
1300×1200 Array{UInt16,2}:
[...]
```

## AstroImage type

The package provides a  type, `AstroImage` to integrate FITS images with Julia packages for plotting and image processing. The `AstroImage` function has the same syntax as `load`. This command:

```julia-repl
julia> img = AstroImage("file.fits")
```

will read the first valid extension from the `file.fits` file. `AstroImage` also works if the file extension is not `.fit` or `.fits`, e.g. if it's a compressed FITS file with extension `.fits.gz`. You can load data in any format supported by [FITSIO.jl](https://juliaastro.github.io/FITSIO.jl/stable/) / [the FITSIO C library](https://heasarc.gsfc.nasa.gov/fitsio/).

If you are working in a Jupyter notebook, an `AstroImage` object is automatically rendered as a PNG image.

You can extract a WCSTransform object from the image using `wcs(img,1)`.

## Headers

FITS Headers can be accessed directly from an AstroImage:

```julia-repl
julia> img["HEAD1"] = 1.0

julia> img["HEAD1",Comment] = "A comment describes the meaning of a header keyword"

julia> img["HEAD1"]
1.0

julia> push!(img, History, "We can record the history of processes applied to this image in header HISTORY entries.")
```

## Visualization

Any AbstractArray (including an AstroImage) can be displayed using `imview`. This function renders an arbitrary array into an array of `RGBA` values using a number of parameters. If the input is an AstroImage{<:Number}, an AstroImage{RGBA} will be returned that retains headers, WCS information, etc.

```julia-repl
julia> imview(img; clims=Percent(99.5), cmap=:magma, stretch=identity, contrast=1.0, bias=0.5)
```

Very large Images are automatically downscaled to ensure consistent performance using `restrict` from Images.jl. This function filters the data before downscaling to prevent aliasing, so it may take a moment for truly huge images. In these cases, a faster method that doesn't prevent aliasing would be `imview(img[begin:10:end, begin:10:end])` or similar.

`imview` is called automatically on `AstroImage{<:Number}` when using a Julia environment with rich graphical IO capabilities (e.g. VSCode, Jupyter, Pluto, etc.). The defaults for this case can be modified using `AstroImages.set_clims!(...)`, `AstroImages.set_cmap!(...)`, and `AstroImages.set_stretch!(...)`.

## Forming Color Composite Images

A color composite image (e.g. RGB) can be constructed using the `composecolors` function:

```julia-repl
julia> rgb = composecolors([img1, img2, img3])
```

Where `img1`, `img2`, `img3` are arrays or AstroImages containing data of red, blue and  green channels respectively.

`composecolors` also supports more complex mappings,  for example merging two bands according to color schemes from ColorSchemes.jl. Note that when the number of bands does not equal the default value, 3, colors must be inserted explicitly, e.g., `composecolors([antred, antblue], ["red", "blue"])`. See [the docs](https://juliaastro.org/AstroImages.jl/stable/manual/converting-to-rgb) for more information.

## Plotting an AstroImage

An `AstroImage` object can be plotted with `Plots.jl` package. Just use:

```julia-repl
julia> using Plots

julia> implot(img)
```

and the image will be displayed as an image series using your favorite backend. Plotly, PyPlot, and GR backends have been tested.

`implot` supports all the same syntax as `imview` in addition to keyword arguments for controlling axis tick marks, WCS grid lines, and the colorbar.

## Resolving World Coordinates

If your FITS file contains world coordinate system headers, AstroImages.jl can use WCS.jl to convert between pixel and world coordinates. This works even if you have sliced or your image to select a region of interest:

```julia-repl
julia> img_slice = img[100:200,100:200]

julia> coords_world = pix_to_world(img_slice, [5,5])
[..., ...]

julia> world_to_pix(img_slice, coords_world)
[5.0,5.0] # approximately
```

## Migrating from Pre-0.3

This package has changed significantly between 0.2 and 0.3 with a new AstroImage type, new recipes, and a new approach to rendering.

* Previously, one would construct an AstroImage out of a FITS HDU and a specific color that was used for display purposes. Now, display settings like color, contrast, and brightness are not stored in the AstroImage but are specified when calling the function `imview`, which returns a view with those settings applied.
* `render` has been replaced by `imview`. 
* The functionality of `ccd2rgb` has been subsumed into `composecolors`.

## License

The `AstroImages.jl` package is licensed under the MIT "Expat" License. The original author is Mosè Giordano.
