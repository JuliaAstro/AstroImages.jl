# ---
# title: Displaying Images
# author: "[William Thompson](https://github.com/sefffal)"
# cover: assets/displaying-images.png
# ---

# We'll start by downloading a sample image. If you have an image stored locally,
# you would skip this step.
using AstroImages

AstroImages.set_clims!(Percent(99.5)) #src
AstroImages.set_cmap!(:magma) #src
AstroImages.set_stretch!(identity) #src


# Any AbstractArray can be visualized with the `imview` function.
arr = randn(10,10)
imview(arr)

# Let's load an astronomical image to see how we can tweak its display
fname = download(
    "http://www.astro.uvic.ca/~wthompson/astroimages/fits/656nmos.fits",
    "eagle-656nmos.fits"
);
img = AstroImage("eagle-656nmos.fits");
imview(img)

# We can adjust the color limits manually
imview(img, clims=(0,100))

# Or provide a function to calculate them for us
imview(img, clims=extrema)

# AstroImages includes some handy callables, like Percent and Zscale.flags
# `Percent` sets the limits to include some central percentage of the data range
# For example, 95% sets the color limits to clip the top and bottom 2.5% of pixels.
# Percent(99.5) is the default value of clims.
imview(img, clims=Percent(95))


# Arrays wrapped by `AstroImage` are displayed automatically using `imview`
AstroImage(randn(10,10))

# The settings for automatic imview are controlled using package defaults that
# can be adjusted to suit your tastes
AstroImages.set_clims!(Zscale()) # Display the full range automatically
AstroImages.set_cmap!(:viridis)
AstroImages.set_stretch!(asinhstretch)
AstroImage(randn(10,10))

# --- restore defaults --- #src
AstroImages.set_clims!(Percent(99.5)) #src
AstroImages.set_cmap!(:magma) #src
AstroImages.set_stretch!(identity) #src

# --- save covers --- #src
mkpath("assets")  #src
save("assets/loading-images.png", imview(img)) #src
