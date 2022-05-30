# ---
# title: Loading Images
# description: Loading FITS images from files.
# author: "[William Thompson](https://github.com/sefffal)"
# cover: assets/loading-images.png
# ---

# We'll start by downloading a sample image. If you have an image stored locally,
# you would skip this step.
using AstroImages
fname = download(
    "http://www.astro.uvic.ca/~wthompson/astroimages/fits/656nmos.fits",
    "eagle-656nmos.fits"
);

# Load the image by filename.
# If unspecified, the image is loaded from the first image-HDU in the fits file.
img = AstroImage("eagle-656nmos.fits")


# --- save covers --- #src
mkpath("assets")  #src
save("assets/loading-images.png", imview(img)) #src