using AstroImages
fname = download(
    "http://www.astro.uvic.ca/~wthompson/astroimages/fits/656nmos.fits",
    "eagle-656nmos.fits"
);

img = AstroImage("eagle-656nmos.fits")

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl

