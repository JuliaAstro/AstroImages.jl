# Photometry

The following examples are adapted from [Photometry.jl](https://github.com/JuliaAstro/Photometry.jl/) to show the same examples
combined with AstroImages.jl.
To learn how to measure background levels, perform aperture photometry, etc see the [Photometry.jl documentation](https://juliaastro.github.io/Photometry.jl/dev/).


## Background Estimation

From Photometry.jl:
> Estimating backgrounds is an important step in performing photometry. Ideally, we could perfectly describe the background with a scalar value or with some distribution. Unfortunately, it's impossible for us to precisely separate the background and foreground signals. Here, we use mixture of robust statistical estimators and meshing to let us get the spatially varying background from an astronomical photo.
> Let's show an example
> Now let's try and estimate the background using estimate_background. First, we'll si gma-clip to try and remove the signals from the stars. Then, the background is broken down into boxes, in this case of size (50, 50). Within each box, the given statistical estimators get the background value and RMS. By default, we use SourceExtractorBackground and StdRMS. This creates a low-resolution image, which we then need to resize. We can accomplish this using an interpolator, by default a cubic-spline interpolator via ZoomInterpolator. The end result is a smooth estimate of the spatially varying background and background RMS.

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

# Download our image, courtesy of astropy
image = AstroImage(download("https://rawcdn.githack.com/astropy/photutils-datasets/8c97b4fa3a6c9e6ea072faeed2d49a20585658ba/data/M6707HH.fits"))

# sigma-clip
clipped = sigma_clip(image, 1, fill=NaN)

# get background and background rms with box-size (50, 50)
bkg, bkg_rms = estimate_background(clipped, 50)

imview(image)
imview(clipped)
imview(bkg)
imview(bkg_rms)
```

Or, if you have Plots loaded:
```@example phot
using Plots

    AstroImages.set_clims!(Percent(99.5))
    AstroImages.set_cmap!(:magma)
    AstroImages.set_stretch!(identity)
plot(
    implot(image, title="Original"),
    implot(clipped, title="Sigma-Clipped"),
    implot(bkg, title="Background"),
    implot(bkg_rms, title="Background RMS"),
    layout=(2, 2),
    ticks=false
)
```
![](/assets/manual-photometry-2.png)


> We could apply a median filter, too, by specifying filter_size
```@example phot
# get background and background rms with box-size (50, 50) and filter_size (5, 5)
bkg_f, bkg_rms_f = estimate_background(clipped, 50, filter_size=5)

# plot
plot(
    implot(bkg, title="Unfiltered", ylabel="Background"),
    implot(bkg_f, title="Filtered"),
    implot(bkg_rms, ylabel="RMS"),
    implot(bkg_rms_f);
    layout=(2, 2),)
```

> Now we can see our image after subtracting the filtered background and ready for Aperture Photometry!

```@example phot
subt = image .- bkg_f[axes(image)...]
clims = extrema(vcat(vec(image), vec(subt)))
plot(
    implot(image; title="Original", clims),
    implot(subt; title="Subtracted", clims),
    size=(900,500)
)
```