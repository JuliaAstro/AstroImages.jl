# Contours

This guide shows a few different ways to measure and visualize contours of images.

## Using Makie

The most basic way to create a contour plot is simply to use Makie's `contour` and `contourf` functions on your image.

Let's see how that works:

```@example contours
using AstroImages, CairoMakie
using Downloads: download

# First load a FITS file of interest
herca = load(download("https://www.chandra.harvard.edu/photo/2014/archives/fits/herca/herca_radio.fits"))
```

Create a contour plot

```@example contours
contour(herca)
```

Create a filled contour plot

```@example contours
contourf(herca)
```

Specify the number of levels

```@example contours
contour(herca; levels = 5)
```

Specify specific levels

```@example contours
contour(herca; levels = [1, 1000, 5000])
```

Overplot contours on image:

```@example contours
fig, ax, plt = implot(herca)
contour!(ax, herca; levels = 4, color = :cyan)
fig
```

## Using Contour.jl

For more control over how contours are calculated and plotted, you can use the [Contour.jl](https://juliageometry.github.io/Contour.jl/stable/) package. Several of its names (`Contour`, `lines`, `coordinates`) clash with Makie exports, so we `import` it and qualify its functions:

```@example contours
import Contour

fig, ax, plt = implot(herca; cmap = nothing)

# Note: Contour.jl only supports float inputs.
# See https://github.com/JuliaGeometry/Contour.jl/issues/73
cls = Contour.levels(Contour.contours(dims(herca)..., float.(herca)))
crange = extrema(Contour.level.(cls))
for cl in cls
    lvl = Contour.level(cl) # the z-value of this contour level
    for line in Contour.lines(cl)
        xs, ys = Contour.coordinates(line) # coordinates of this line segment
        lines!(ax, xs, ys; color = lvl, colormap = :viridis, colorrange = crange)
    end
end

fig
```

Here we plot just the contours, now in world coordinates:

```@example contours
fig = Figure()
ax = Axis(fig[1, 1]; xlabel = "RA", ylabel = "DEC")

for cl in cls
    lvl = Contour.level(cl) # the z-value of this contour level
    for line in Contour.lines(cl)
        xs, ys = Contour.coordinates(line) # coordinates of this line segment
        worldcoords = map(zip(xs, ys)) do pixcoord
            pixel_to_world(herca, [pixcoord...])
        end
        lines!(
            ax, getindex.(worldcoords, 1), getindex.(worldcoords, 2);
            color = lvl, colormap = :viridis, colorrange = crange,
        )
    end
end

fig
```
