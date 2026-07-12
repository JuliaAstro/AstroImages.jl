# Plotting API stubs. The actual implementations live in the Makie package
# extension (ext/AstroImagesMakieExt.jl) and are loaded automatically when
# Makie (or a Makie backend) is loaded alongside AstroImages.

"""
    implot(img::AstroImage; kwargs...)
    implot!([ax], img::AstroImage; kwargs...)

Display an `AstroImage` with Makie, with support for astronomical image
rendering and world coordinate system (WCS) axes.

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

Called with just an image, returns `(fig, iv)` like other Makie blocks;
called with a figure or grid position (e.g. `implotview(fig[1, 2], img)`),
places the panel there and returns it.

!!! note
    Requires a Makie backend (e.g. `using CairoMakie` or `using GLMakie`) to
    be loaded.
"""
function implotview end

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
