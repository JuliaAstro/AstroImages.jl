# Plotting API stubs. The actual implementations live in the Makie package
# extension (ext/AstroImagesMakieExt.jl) and are loaded automatically when
# Makie (or a Makie backend) is loaded alongside AstroImages.

"""
    implot(img::AstroImage; kwargs...)
    implot!([ax], img::AstroImage; kwargs...)

Display an `AstroImage` with Makie, with support for astronomical image
rendering and world coordinate system (WCS) axes. `implot` plots into a
single axis, which makes it the right tool for composing multi-panel figures
and overplotting other data; for a complete standalone panel including a
colorbar, see [`implotview`](@ref).

!!! note
    Requires a Makie backend (e.g. `using CairoMakie` or `using GLMakie`) to
    be loaded.

### Image Rendering
Unlike `imview`, which returns an array of RGBA pixels, `implot` maps data
values to colors through Makie's colormapping pipeline so that colorbars
(`Makie.Colorbar(fig[1, 2], plt)`) show data values with correctly placed
ticks under non-linear stretches.

* `clims` (default `Percent(99.5)`) color limits: either a tuple `(lo, hi)` or
  a callable like [`Percent`](@ref) or [`Zscale`](@ref) applied to the finite
  data values
* `stretch` (default `identity`) a monotonic stretch function applied to the
  `clims`-normalized data, e.g. [`asinhstretch`](@ref) or [`logstretch`](@ref)
* `cmap` (default `:magma`) any Makie colormap
* `contrast` (default `1.0`) and `bias` (default `0.5`) scale and shift the
  colormap, following the SAO DS9 convention
* `nan_color` (default `:transparent`) color for NaN and missing pixels

### WCS & Image Coordinates
If provided with an AstroImage that has WCS headers set, the tick marks, axis
labels, and plot grid are calculated using FITSWCS.jl. The underlying pixel
coordinates are those returned by `dims(img)` multiplied by `platescale`,
allowing you to overplot lines, regions, etc. using pixel coordinates
(see `world_to_pixel`).

* `wcsn` (default `' '`) select which WCS transform in the headers to use for
  ticks & grid, by version character (`' '` primary, `'A'`–`'Z'` alternates)
* `wcsticks` (default `true` if WCS headers present) display ticks, labels,
  and title using world coordinates
* `wcstitle` (default `true`) when slicing a cube, display the location along
  unseen axes in world coordinates in the axis title
* `wcsgrid` (default `true` when `wcsticks` are shown) overplot the (possibly
  curved) WCS coordinate grid
* `platescale` (default `1`) scales the underlying pixel coordinates to ease
  overplotting

### Panel Sizing
* `width`, `height` (default: fill the layout cell) fix the created axis's
  size in layout units. When only one is given, the other is derived from the
  image extent so the panel matches the data aspect. Fixed panel sizes keep
  the figure layout fully determined, so `resize_to_layout!(fig)` shrink-wraps
  the figure around its panels — sizing the panels instead of the figure is
  the convenient direction when composing multi-panel figures.

### Defaults
The default values of `clims`, `stretch`, and `cmap` may be altered using
`AstroImages.set_clims!`, `AstroImages.set_stretch!`, and
`AstroImages.set_cmap!`.
"""
function implot end
function implot! end

"""
    fig, iv = implotview(img::AstroImage; kwargs...)
    iv = implotview(fig_or_gridposition, img::AstroImage; kwargs...)

Display an `AstroImage` as a complete figure panel: an axis with WCS ticks,
labels, and title, plus a colorbar labeled with the image's `UNIT`/`BUNIT`
header when present. Accepts the rendering and WCS keyword arguments of
[`implot`](@ref), plus:

* `colorbar` (default `true`) display the colorbar
* `colorbar_label` (default from the `UNIT`/`BUNIT` header) colorbar label
* `axis` (default `(;)`) attributes forwarded to the created Axis, overriding
  the WCS defaults, e.g. `axis = (; title = "M42")`

Passing an axis `width` and/or `height` (e.g. `axis = (; height = 300)`) fixes the panel's image-box size, deriving a missing dimension from the image extent. A sized view reports its footprint to the layout, so `resize_to_layout!(fig)` shrink-wraps a figure composed of sized views, and a standalone sized view shrink-wraps its own figure automatically. An unsized view instead fills whatever space it is given, keeping the image aspect-locked with the colorbar flush against it. This is the right behavior for interactive windows.

Called with just an image, returns `(fig, iv)` like other Makie blocks. Called with a figure or grid position (e.g., `implotview(fig[1, 2], img)`), places the panel there and returns it. The created Axis is available as
`iv.ax` for overplotting (e.g., `lines!(iv.ax, ...)`), and the image plot as `iv.plt`.

!!! note
    Requires a Makie backend (e.g., `using CairoMakie` or `using GLMakie`) to be loaded.
"""
function implotview end

"""
    world_transform(img::AstroImage; wcsn = ' ', platescale = 1)
    world_transform(plt_or_view)

Return a `Makie.Transformation` that maps world coordinates of the image's two
plotted dimensions (in the WCS's native world units, typically degrees for
celestial axes) to the pixel coordinate space that [`implot`](@ref) draws in.
Pass it to a Makie plotting function via the `transformation` keyword to plot
world-coordinate data directly over an image.

```julia
fig, iv = implotview(img)
scatter!(iv.ax, ra_deg, dec_deg; transformation = world_transform(iv))
```

Called with the plot returned by [`implot`](@ref) or the view returned by
[`implotview`](@ref), as above, the image, `wcsn`, and `platescale` are taken
from it directly. When called with an image, pass the same `wcsn` and
`platescale` values as the image plot.

The transformed positions feed Makie's autolimits, so overplotted
world-coordinate data co-registers with the image without manual
[`world_to_pixel`](@ref) calls. The transformation is invertible
(`Makie.inverse_transform`), so interactive tools that need the reverse
mapping keep working.

!!! note
    Wrap-around of angular coordinates (e.g., right ascension crossing 0°/360°)
    is not special-cased.

!!! note
    Requires a Makie backend (e.g., `using CairoMakie` or `using GLMakie`) to
    be loaded.
"""
function world_transform end

"""
    polquiver(polcube::AstroImage; kwargs...)
    polquiver!([ax], polcube::AstroImage; kwargs...)

Given a data cube of at least 2 spatial dimensions plus a polarization axis
(`Pol`), plot a vector field of linear polarization data with Makie.
The segment length represents the polarization intensity, `sqrt(Q^2 + U^2)`,
and the color represents the linear polarization fraction,
`sqrt(Q^2 + U^2) / I`.

!!! note
    Requires a Makie backend (e.g. `using CairoMakie` or `using GLMakie`) to
    be loaded.

Keyword arguments:
* `bins` (default `4`) by how much the polarization data is binned down
  (block-averaged) before drawing the segments
* `ticklen` (default `bins`) how long the 98th-percentile segment should be,
  in pixels
* `colormap` (default `:turbo`) colormap for the linear polarization fraction
* `minpol` (default `0.1`) hides segments shorter than `minpol` times the
  98th-percentile intensity. Set to 0 to display all data.

Use `implot` and `polquiver!` to overplot polarization data over an image.
"""
function polquiver end
function polquiver! end
