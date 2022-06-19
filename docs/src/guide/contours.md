# Contours

This guide shows a few different ways to measure and visualize contours of images.

## Using Plots
The most basic way to create a contour plot is simply to use Plots.jl `contour` and `contourf` functions on your image.

Let's see how that works:
```@example 1
using AstroImages, Plots


# First load a FITS file of interest
fname = download(
    "http://www.astro.uvic.ca/~wthompson/astroimages/fits/herca/herca_radio.fits",
    "herca-radio.fits"
)

herca = load("herca-radio.fits")
```


Create a contour plot
```@example 1
contour(herca)
```