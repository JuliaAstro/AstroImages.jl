# Loading Images

FITS (Flexible Image Transport System) files can be loaded and saved using AstroImages thanks to the FITSIO package.

AstroImages is registered with [FileIO](https://juliaio.github.io/FileIO.jl/stable/), so if you have FileIO and AstroImages
installed you can get started with the `load` function. When you pass a file name with the appropriate file extension (".fits", ".fit", etc.)
FileIO will import AstroImages automatically.

Alternatively, you can use the `AstroImage` contructor instead of load. This will work on fits files with any file extension, including compressed
files (e.g. ".fits.gz").

```julia-repl
julia> img = load("myfitsimg.fits")
1600×1600 AstroImage{Float32,2} with dimensions:
  X Sampled Base.OneTo(1600) ForwardOrdered Regular Points,
  Y Sampled Base.OneTo(1600) ForwardOrdered Regular Points
 0.0  0.0  0.0  0.0  0.0  …  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
 ⋮                        ⋱
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
```

Note: if you are in an interactive environment like VSCode, Jupyter, or Pluto, instead of a REPL, AstroImages are automatically
rendered to images and displayed. You can see this plain text output by explicitly calling:
`show(stdout, MIME("text/plain"), img)`.

Or:
```julia-repl
 julia> img = AstroImage("myfitsimg.fits.gz")
1600×1600 AstroImage{Float32,2} with dimensions:
  X Sampled Base.OneTo(1600) ForwardOrdered Regular Points,
  Y Sampled Base.OneTo(1600) ForwardOrdered Regular Points
 0.0  0.0  0.0  0.0  0.0  …  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
 ⋮                        ⋱
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0     0.0  0.0  0.0  0.0
```

A FITS file can contain multiple N-dimensional images and tables.
When you call load or AstroImage with a file name and no other arguments, the package will search through the file
and return the first image HDU. That is, it will skip any FITS tables or empty HDUs with only headers.

You can also specify an HDU number explicitly:
```julia-repl
julia> img = load("myfitsimg.fits",1)
1600×1600 AstroImage{Float32,2} with dimensions:
  X Sampled Base.OneTo(1600) ForwardOrdered Regular Points,
  Y Sampled Base.OneTo(1600) ForwardOrdered Regular Points
...
```
This way, you can load specific images from multi-extension files.

You can load all HDUs simultaneously by passing `:`:

```julia-repl
julia> hdus = load("multiext.fits", :);
julia> hdus[2] # Second HDU as an AstroImage
10×10 AstroImage{Float64,2} with dimensions:
  X Sampled Base.OneTo(10) ForwardOrdered Regular Points,
  Y Sampled Base.OneTo(10) ForwardOrdered Regular Points
 -0.777315  -1.36683   -0.580179     1.39629      …  -2.14298     0.450059   0.432065
 -1.09619    0.789249   0.938415     0.959903        -0.88995    -1.29406   -0.4291
  0.47427   -1.41855    0.814823    -1.15975          0.0427149  -1.20116   -0.0920709
 -0.179858  -1.60228    1.09648     -0.497927        -1.31824    -0.156529  -0.0223846
  2.64162    0.131437   0.320476     0.331197        -0.914713   -1.55162   -0.18862
  0.209669  -1.17923   -0.656512     0.000775311  …   0.377461   -0.24278    0.967202
  1.01442   -0.762895  -2.13238     -0.456932        -0.415733   -1.21416   -1.6108
  0.385626   0.389335  -0.00726015   0.309936        -0.533175    0.157878   0.100876
 -1.24799    0.461216  -0.868826    -0.255654        -0.37151     0.49479   -1.87129
  1.39356    2.29254    0.0548325    1.50674         -0.0880865   0.580978  -1.81629
julia> # Or:
julia> hdu1, hdu2, hdu3 = load("multiext.fits", :);
```

There is also limited support for table HDUs. In this case, a bare-bones Tables.jl compatible 
object is returned.

## Dimension Names
You may have noticed the entries above the image array:
```
10×10 AstroImage{Float64,2} with dimensions:
  X Sampled Base.OneTo(10) ForwardOrdered Regular Points,
  Y Sampled Base.OneTo(10) ForwardOrdered Regular Points
```

AstroImages are based on [Dimensional Data](https://github.com/rafaqz/DimensionalData.jl). Each axis is assigned a dimension name
and the indices are tracked.
The automatic dimension names are `X`, `Y`, `Z`, `Dim{4}`, `Dim{5}`, and so on; however you can pass in other names or orders to the load function and/or AstroImage contructor:

```julia-repl
julia> img = load("img.fits", 1, (Y=1:1600,Z=1:1600))
1600×1600 AstroImage{Float32,2} with dimensions:
  Y Sampled 1:1600 ForwardOrdered Regular Points,
  Z Sampled 1:1600 ForwardOrdered Regular Points
```
Other useful dimension names are `Spec` for spectral axes, `Pol` for polarization data, and `Ti` for time axes.

These will be further discussed in Dimensions and World Coordinates.


## Saving Images
You can save one or more AstroImages and tables to a FITS file using the `save` function:

```julia-repl
julia> save("abc.fits", astroimage1, astroimage2, table1)
```

You can also save individual images to traditional graphics formats by first rendering them with `imview` (for more on imview, see Displaying Images).
```julia-repl
julia> save("abc.png", imview(astroimage1))
```

You can save animated GIFs by saving a 3D datacube that has been rendered with imview:
```julia-repl
julia> cube =  imview(AstroImage(randn(100,100,10)));
julia> save("abc.gif", cube, fps=10)

julia> # Or a more complex example (changing color schemes each frame)
julia> img = randn(10,10)
julia> cube2 = [imview(img1, cmap=:magma) ;;; imview(img2, cmap=:plasma) ;;; imview(img3, cmap=:viridis)]
julia> # Alternative syntax:
julia> cube2 = cat(imview(img1, cmap=:magma), imview(img2, cmap=:plasma), imview(img3, cmap=:viridis), dims=3)
julia> save("abc.gif", cube, fps=10)
```

