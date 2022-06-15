using AstroImages

arr = randn(10,10)
imview(arr)

fname = download(
    "http://www.astro.uvic.ca/~wthompson/astroimages/fits/656nmos.fits",
    "eagle-656nmos.fits"
);
img = AstroImage("eagle-656nmos.fits");
imview(img)

imview(img, clims=(0,100))

imview(img, clims=extrema)

imview(img, clims=Percent(95))

AstroImage(randn(10,10))

AstroImages.set_clims!(Zscale()) # Display the full range automatically
AstroImages.set_cmap!(:viridis)
AstroImages.set_stretch!(asinhstretch)
AstroImage(randn(10,10))

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl

