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

`AstroImage.jl` is available for Julia 0.7 and later versions, and can be
installed with [Julia built-in package
manager](https://docs.julialang.org/en/v1/stdlib/Pkg/).  This packages is not
yet registered, after entering into the package manager by pressing `]` run the
command

```julia
pkg> add https://github.com/JuliaAstro/AstroImages.jl
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
AstroImages.AstroImage{UInt16,ColorTypes.Gray}[...]
```

will read the first extension from the `file.fits` file and wrap its content in
a `Matrix{Gray}`, that can be easily used with `Images.jl` and related packages.

If you are working in a Jupyter notebook, an `AstroImage` object is
automatically rendered as a PNG image.

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
