# Image Filtering

The package [ImageFiltering.jl](https://juliaimages.org/ImageFiltering.jl/stable/) makes it easy to apply arbitrary filters to images.

```@setup ex1
using AstroImages
AstroImages.set_clims!(Percent(99.5))
AstroImages.set_cmap!(:magma)
AstroImages.set_stretch!(identity)
```

## Gaussian Blurs

Let's start by downloading a radio image of Hercules A:

```@example ex1
using AstroImages
using ImageFiltering
using Downloads: download

herca = load(download("https://www.chandra.harvard.edu/photo/2014/archives/fits/herca/herca_radio.fits"))
```

Let's now apply a Gaussian blur (aka a low pass filter) using the `imfilter` function:

```@example ex1
herca_blur_20 = imfilter(herca, Kernel.gaussian(20.0))
```

The image has been smoothed out by convolving it with a wide Gaussian.

Let's now do the opposite and perform a high-pass filter. This will bring out faint variations in structure. We can do this by subtracting a blurred image from the original:

```@example ex1
herca_blur_4 = imfilter(herca, Kernel.gaussian(4.0))
herca_highpass = herca .- herca_blur_4
```

We now see lots of faint structure inside the jets!

Finally, let's adjust how the image is displayed and apply a non-linear stretch:

```@example ex1
imview(herca_highpass;
    cmap = :seaborn_rocket_gradient,
    clims = (-50, 1500),
    stretch = asinhstretch,
)
```

If you have Plots.jl loaded, we can add a colorbar and coordinate axes by switching to `implot`:

```@example ex1
using Plots

implot(herca_highpass;
    cmap = :seaborn_rocket_gradient,
    clims = (-50, 1500),
    stretch = asinhstretch
)
```

## Median Filtering

In addition to linear filters using `imfilter`, ImageFiltering.jl also includes a great function called `mapwindow`. This functions allows you to map an arbitrary function over a patch of an image.

Let's use `mapwindow` to perform a median filter. This is a great way to suppress salt and pepper noise, or remove stars from some images.

We'll use a Hubble picture of the Eagle nebula:

```@example ex1
using AstroImages
using ImageFiltering

eagle673 = load(download("https://ds9.si.edu/download/data/673nmos.fits"))
```

The data is originally from <https://esahubble.org/projects/fits_liberator/eagledata/>.

We can apply a median filter using `mapwindow`. Make sure the patch size is an odd number in each direction!

```@example ex1
using Statistics

medfilt = copyheader(eagle673, mapwindow(median, eagle673, (11, 11)))
```

We use `copyheader` here since `mapwindow` returns a plain array and drops the image meta data.

We can put this side by side with the original to see how some of the faint stars have been removed from the image:

```@example ex1
imview([eagle673[1:800, 1:800]; medfilt[1:800, 1:800]])
```
