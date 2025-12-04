# Conventions

In the Julia Astro ecosystem, images follow the following conventions.

## Axes

For simple 2D images, the first axis is the horizontal axis and the second axis is the vertical axis. So images are indexed by `img[xi, yi]`.

The origin is at the bottom left of the image, so `img[1, 1]` refers to the bottom left corner, as does `img[begin, begin]`. `img[end, end]` is the top right corner, `img[begin, end]` is the top left, etc.

Note that this is transposed and flipped from how Julia prints arrays at the REPL.

## Pixels

This library considers the exact location of `img[1, 1]` to be the center of the pixel in the bottom left corner. This means that plot limits should have the `1` tick slightly away from the left/bottom spines of the image. The default plot limits for `implot` are `-0.5` to `end + 0.5` along both axes.

There is a [known bug](https://github.com/JuliaPlots/Plots.jl/issues/4158) with the Plots.jl GR backend that leads ticks to be slightly offset. PyPlot and Plotly backends show the correct tick locations.
