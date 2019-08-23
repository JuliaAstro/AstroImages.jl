# AstroImages.jl

| **Build Status**                          | **Code Coverage**               |
|:-----------------------------------------:|:-------------------------------:|
| [![Build Status][travis-img]][travis-url] | [![][coveral-img]][coveral-url] |
| [![Build Status][appvey-img]][appvey-url] | [![][codecov-img]][codecov-url] |

Introduction
------------

`AstroImage.jl` allows you to plot images from an
astronomical [`FITS`](https://en.wikipedia.org/wiki/FITS) file using the
popular [`Images.jl`](https://github.com/JuliaImages/Images.jl)
and [`Plots.jl`](https://github.com/JuliaPlots/Plots.jl) Julia packages.
`AstroImage.jl` uses [`FITSIO.jl`](https://github.com/JuliaAstro/FITSIO.jl) to
read FITS files.

Installation
------------

`AstroImage.jl` is available for Julia 1.0 and later versions, and can be
installed with [Julia built-in package
manager](https://docs.julialang.org/en/v1/stdlib/Pkg/).

```julia
pkg> add AstroImages
```

Usage
-----

After installing the package, you can start using it with

```julia
julia> using AstroImages
```

## Reading extensions from FITS file

You can load and read the the first extension of a FITS file with the `load`
function, from [`FileIO.jl`](https://github.com/JuliaIO/FileIO.jl):

```julia
julia> load("file.fits")
1300×1200 Array{UInt16,2}:
[...]
```

The second argument of this `load` method is the number of the extension to
read.  Read the third extension of the file with:

```julia
julia> load("file.fits", 3)
1300×1200 Array{UInt16,2}:
[...]
```

## AstroImage type

The package provides a new type, `AstroImage` to integrate FITS images with
Julia packages for plotting and image processing.  The `AstroImage` function has
the same syntax as `load`.  This command:

```julia
julia> img = AstroImage("file.fits")
AstroImages.AstroImage{UInt16,ColorTypes.Gray,1,Float64}[...]
```

will read the first valid extension from the `file.fits` file and wrap its content in
a `NTuple{N, Matrix{Gray}}`, that can be easily used with `Images.jl` and related packages.

If you are working in a Jupyter notebook, an `AstroImage` object is
automatically rendered as a PNG image.

`AstroImage` automatically extracts and store `wcs` information of images in a `NTuple{N, WCSTransform}`.

## Forming RGB image
`AstroImage` can automatically construct a RGB image if 3 different colour band data is given.

```julia
julia> img = AstroImage(RGB, ("file1.fits","file2.fits", "file3.fits"))
```
Where 1st index of `file1.fits`, `file2.fits`, `file3.fits` contains band data of red, blue and  green channels respectively.

Optionally, `ccd2rgb` method can be used to form a coloured image from 3 bands without creating an `AstroImage`.

The formed image can be accessed using `img.property.rgb_image`. 
`set_brightness!` and `set_contrast!` methods can be used to change brightness and contrast of formed `rgb_image`.
`add_label!` method can be used to add/store Astronomical labels in an `AstroImage`.
`reset!` method resets `brightness`, `contrast` and `label` fields to defaults and construct a fresh `rgb_image` without any brightness, contrast operations.


## Plotting an AstroImage

An `AstroImage` object can be plotted with `Plots.jl` package.  Just use

```julia
julia> using Plots

julia> plot(img)
```

and the image will be displayed as a heatmap using your favorite backend.

License
-------

The `AstroImages.jl` package is licensed under the MIT "Expat" License.  The
original author is Mosè Giordano.

[travis-img]: https://travis-ci.org/JuliaAstro/AstroImages.jl.svg?branch=master
[travis-url]: https://travis-ci.org/JuliaAstro/AstroImages.jl

[appvey-img]: https://ci.appveyor.com/api/projects/status/7gaxwe0c8hjx3d1s?svg=true
[appvey-url]: https://ci.appveyor.com/project/giordano/astroimages-jl

[coveral-img]: https://coveralls.io/repos/JuliaAstro/AstroImages.jl/badge.svg?branch=master&service=github
[coveral-url]: https://coveralls.io/github/JuliaAstro/AstroImages.jl?branch=master

[codecov-img]: http://codecov.io/github/JuliaAstro/AstroImages.jl/coverage.svg?branch=master
[codecov-url]: http://codecov.io/github/JuliaAstro/AstroImages.jl?branch=master
