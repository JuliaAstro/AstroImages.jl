# Home

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliaastro.org/AstroImages/stable/)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaastro.org/AstroImages.jl/dev/)

[![CI](https://github.com/JuliaAstro/AstroImages.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaAstro/AstroImages.jl/actions/workflows/CI.yml)
[![codecov](http://codecov.io/github/JuliaAstro/AstroImages.jl/coverage.svg)](http://codecov.io/github/JuliaAstro/AstroImages.jl)

AstroImage.jl is a Julia package for loading, manipulating, and visualizing astronomical images.

It supports FITS files ([FITSIO.jl](https://github.com/JuliaAstro/FITSIO.jl)), world coordinates ([WCS.jl](https://github.com/JuliaAstro/WCS.jl)), rendering images ([Images.jl](https://github.com/JuliaImages/Images.jl)), and plot recipes ([Plots.jl](https://github.com/JuliaPlots/Plots.jl)).

## Quickstart

```@example
using AstroImages
using Downloads: download

img = load(download("https://archive.stsci.edu/hlsps/jwst-ero/hlsp_jwst-ero_jwst_miri_carina_f770w_v1_i2d.fits"))
```

*Carina (NGC 3324), [Early Release Observations](https://archive.stsci.edu/hlsp/jwst-ero) from the James Webb Space Telescope ([Pontoppidan et al. 2022](https://ui.adsabs.harvard.edu/abs/2022ApJ...936L..14P/abstract)).*

## Videos

AstroImages.jl was presented at JuliaCon in 2022. You can view the talk [here](https://www.youtube.com/watch?v=tpFNIV2jyb8).
