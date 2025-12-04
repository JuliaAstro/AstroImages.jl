# Photometry

The following examples are adapted from [Photometry.jl](https://github.com/JuliaAstro/Photometry.jl/) to show the same examples
combined with AstroImages.jl. To learn how to measure background levels, perform aperture photometry, etc., see the [Photometry.jl documentation](https://juliaastro.org/Photometry/stable/).


## Background Estimation

From Photometry.jl:

> Estimating backgrounds is an important step in performing photometry. Ideally, we could perfectly describe the background with a scalar value or with some distribution. Unfortunately, it's impossible for us to precisely separate the background and foreground signals. Here, we use mixture of robust statistical estimators and meshing to let us get the spatially varying background from an astronomical photo.
>
> Let's show an example [...]. Now let's try and estimate the background using `estimate_background`. First, we'll sigma-clip to try and remove the signals from the stars. Then, the background is broken down into boxes, in this case of size (50, 50). Within each box, the given statistical estimators get the background value and RMS. By default, we use `SourceExtractorBackground` and `StdRMS`. This creates a low-resolution image, which we then need to resize. We can accomplish this using an interpolator, by default a cubic-spline interpolator via `ZoomInterpolator`. The end result is a smooth estimate of the spatially varying background and background RMS.

```@setup phot
using AstroImages
AstroImages.set_clims!(Percent(99.5))
AstroImages.set_cmap!(:magma)
AstroImages.set_stretch!(identity)
```

```@example phot
using Photometry
using AstroImages
using Plots # optional, for implot functionality
using Downloads: download

# Download our image, courtesy of astropy
image = load(download("https://rawcdn.githack.com/astropy/photutils-datasets/8c97b4fa3a6c9e6ea072faeed2d49a20585658ba/data/M6707HH.fits"))

# sigma-clip
clipped = sigma_clip(image, 1; fill = NaN)

# get background and background rms with box-size (50, 50)
bkg, bkg_rms = estimate_background(clipped, 50)

nothing # hide
```

We can take a look at each of our processed images with `imview`:

```@example phot
imview([image; clipped])
```

```@example phot
imview([bkg; bkg_rms])
```

Or all together with Plots.jl:

```@example phot
using Plots

AstroImages.set_clims!(Percent(99.5))
AstroImages.set_cmap!(:magma)
AstroImages.set_stretch!(identity)

plot(
    implot(image; title = "Original"),
    implot(clipped; title = "Sigma-Clipped"),
    implot(bkg; title = "Background"),
    implot(bkg_rms; title = "Background RMS");
    layout = (2, 2),
    ticks = false,
)
```

We could apply a median filter, too, by specifying `filter_size`:

```@example phot
# get background and background rms with box-size (50, 50) and filter_size (5, 5)
bkg_f, bkg_rms_f = estimate_background(clipped, 50; filter_size = 5)

# plot
plot(
    implot(bkg; title = "Unfiltered", ylabel = "Background"),
    implot(bkg_f; title = "Filtered"),
    implot(bkg_rms; ylabel = "RMS"),
    implot(bkg_rms_f);
    layout = (2, 2),
    ticks = false,
)
```

Now we can see our image after subtracting the filtered background and ready for Aperture Photometry!

```@example phot
subt = image .- bkg_f[axes(image)...]
clims = extrema(vcat(vec(image), vec(subt)))
plot(
    implot(image; title = "Original", clims),
    implot(subt; title = "Subtracted", clims);
    size = (1600, 1000),
)
```

## Source Extraction
From the background-subtracted image, we can detect all sources in the image:

```@example phot
# We specify the uncertainty in the pixel data. We'll set it equal to zero.
errs = zeros(axes(subt))
sources = extract_sources(PeakMesh(), subt, errs, true) # sort from brightest to darkest
```

There's over 60,000 sources!

We'll define a circular apperture for each source:

```@example phot
aps = CircularAperture.(sources.x, sources.y, 6)[1:1000] # just brightest thousand point sources
```

We can overplot them on our original image. The coordinate sytem used by the Photometry.jl plot recipes (but not the actual return values) doesn't match AstroImages, so we must transpose our image:

```@example phot
implot(subt'; colorbar = false)
plot!(aps)
```

## Measuring Photometry

Finally we can extract the source photometry:

```@example phot
table = photometry(aps, subt)
```

And plot them:

```@example phot
scatter(table.xcenter, table.ycenter;
    aspectratio = 1,
    marker_z = table.aperture_sum,
    markerstrokewidth = 0,
    label = "",
    framestyle = :box,
    background_inside = :black,
    color = :white,
)
```
