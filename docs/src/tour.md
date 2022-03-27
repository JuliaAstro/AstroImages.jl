# Package Tour

To follow along, download the images from the [Fits Liberator](https://esahubble.org/projects/fits_liberator/eagledata/) page and unzip them.

```@meta
DocTestSetup = quote
    using AstroImages
end
```

```@repl
using AstroImages
```

Let's start by loading a FITS file.
```@repl
using AstroImages
eagle_656 = load("fits/656nmos.fits")
save("eagle-1.png") # hide
```
![eagle](eagle-1.png)
