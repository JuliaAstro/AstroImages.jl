# Converting to RGB

```@setup 1
using AstroImages
using DimensionalData
using AstroImages: restrict

AstroImages.set_clims!(Percent(99.5))
AstroImages.set_cmap!(:magma)
AstroImages.set_stretch!(identity)
```

If you have two or more images of the same scene taken at different wavelengths, you may wish to combine them to create a color composite.

For ultimate control, you can do this manually using `imview`. Simply map your channels to `RGB` values using `imview` and then sum the results.

For convenience, AstroImages.jl provides the function [`composecolors`](@ref composecolors).

## Using `composecolors`

We'll demonstrate `composecolors` using Hubble images of the [Antenae colliding galaxies](https://esahubble.org/projects/fits_liberator/antennaedata/).

One can be very scientific about this process, but often the goal of producing color composites is aesthetic or about highlighting certain features for public consumption.

Let's set the default color map to grayscale to avoid confusion.

```@example 1
using AstroImages

AstroImages.set_cmap!(nothing)
```

Let's start by downloading the separate color channel FITS files:

```@example 1
using Downloads: download

# We crop some of the images a bit to help align them with the other color channels
antred = load(download("https://esahubble.org/static/projects/fits_liberator/datasets/antennae/red.fits"))[:, begin+14:end]
```

```@example 1
antgreen = load(download("https://esahubble.org/static/projects/fits_liberator/datasets/antennae/green.fits"))
```

```@example 1
antblue = load(download("https://esahubble.org/static/projects/fits_liberator/datasets/antennae/blue.fits"))[:, begin+14:end]
```

```@example 1
anthalph = load(download("https://esahubble.org/static/projects/fits_liberator/datasets/antennae/hydrogen.fits"))[:, begin+14:end]; # Hydrogen-Alpha; we'll revisit later
```

In order to compose these images, we'll have to match the relative intensity scales and clip outlying values. Thankfully, `composecolors` handles most of these details automatically:

```@example 1
rgb1 = composecolors([antred, antgreen, antblue])
```

It's a start!

!!! note
    For best results, the images should be properly aligned and cropped to the same size before making a color composite. The simple cropping we did here is just for demonstration purposes.

By default, if you provide three images these are mapped to the color channels red, green, and blue.
The intensities are limited to `Percent(99.5)`.

We can now tweak these defaults to our tastes. We could try clamping the intensities more agressively to bring out more of the galaxy structure:

```@example 1
rgb2 = composecolors([antred, antgreen, antblue];
    clims = Percent(97),
)
```

This looks okay but saturates the galaxy cores.

Let's take care of that gash through the image by just blanking it out:

```@example 1
mask = antgreen .== antgreen[end,begin]
# remove holes in the mask
using ImageFiltering, Statistics
mask = BitMatrix(mapwindow(median, mask, (3,3)))
imview(mask)
```

```@example 1
antred[mask] .= NaN
antgreen[mask] .= NaN
antblue[mask] .= NaN
anthalph[mask] .= NaN
nothing # hide
```

Typically we need to perform a "gamma correction" aka non-lienar stretch to map the wide dynamic range of astronomical images into a narrower human visible range. We can do this using the `stretch` keyword. An `asinhstretch` is typically recommended when preparing RGB images:

```@example 1
rgb3 = composecolors([antred, antgreen, antblue];
    stretch = asinhstretch,
)
```

Keywords like `stretch`, `clims`, etc can be either a single value for all channels or a list of separate values/functions per channel.

The green channel appears to be quite faint compared to the red and blue channels. We can modify that by adjusting the relative intensities of the channels.

We could also do this using a combination of the `contrast` and `bias` keywords:

```@example 1
rgb4 = composecolors([antred, antgreen, antblue];
    stretch = asinhstretch,
    multiplier = [1,1.7,1],
)
```

That's better! Let's go one step further, and incorporate a fourth chanel: Hydrogen Alpha. Hydrogen Alpha is a narrow filter centered around one of the emission lines of Hydrogen atoms. It traces locations with hot gas; mostly star-formation regions in this case:

```@example 1
imview(anthalph; cmap = :magma, clims = Zscale())
```

We'll now need to specify the color channels we want to use for each wavelength since we can't use just the default three RGB. We can use any named color or julia ColorScheme:

```@example 1
rgb5 = composecolors([antred, antgreen, antblue, anthalph], ["red", "green", "blue", "maroon1"];
    stretch = asinhstretch,
    multiplier = [1,1.7,1,0.8],
)
```

Additionally, we'd like to just show the brightest areas of Hydrogen alpha emission rather than adding a diffuse pink glow. We can turn off the stretch for this one channel:

```@example 1
rgb6 = composecolors([antred, antgreen, antblue, anthalph], ["red", "green", "blue", "maroon1"];
    stretch = [
        asinhstretch,
        asinhstretch,
        asinhstretch,
        identity,
    ],
    multiplier = [1, 1.7, 1, 0.8]
)
```

Finally, we can crop the image and save it as a PNG:

```@example 1
crop = rgb6[200:end-100, 50:end-50]
```

```julia
save("antenae-composite.png", crop)
```

If you want to save it in a format like JPG that doesn't support transparent pixels, you could replace the masked area with zeros instead of `NaN`.


```@setup 1
# restore package defaults
using AstroImages
AstroImages.set_clims!(Percent(99.5))
AstroImages.set_cmap!(:magma)
AstroImages.set_stretch!(identity)
```
