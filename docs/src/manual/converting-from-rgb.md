## Converting From RGB Images

If you encouter an image in a standard graphics format (e.g. PNG, JPG) that you want to analyze or store in an AstroImage, it will likely contain RGB (or similar) pixels.

It is possible to store RGB data in an AstroImage. Let's see how that works:

```@example 1
using AstroImages
using Downloads: download

# First we load it from the PNG file
mw_png = (load ∘ download)("https://upload.wikimedia.org/wikipedia/commons/1/15/154-panel_Widefield_Milky_Way_Panorama.jpg","mw-crop2-small.png")
```

Once the RGB image is loaded, we can store it in an AstroImage if we'd like:

```@example 1
mw_ai = AstroImage(mw_png)
```

However, we may want to extract the RGB channels first. We can do this using `Images.channelview`. This returns a view into the RGB data as a 3 × X × Y dimension cube. Unfortunately, we will have to permute the dimensions slightly:

```@example 1
using Images

mw_chan_view = channelview(mw_png)

mw_rgb_cube = AstroImage(
    permutedims(mw_chan_view, (3, 2, 1))[:,end:-1:begin,:],
    # Optional:
    (X=:, Y=:, Spec=[:R, :G, :B])
)
```

Here we chose to mark the third axis as a spectral axis with keys `:R`, `:G`, and `:B`.

We can now visualize each channel:

```@example 1
mw_rgb_cube[Spec = At(:R)] # Or just: mw_rgb_cube[:, :, 1]
```

```@example 1
imview(
    mw_rgb_cube[Spec = At(:R)];
    cmap = nothing # Grayscale mode
)
```

```@example 1
using Plots

implot(mw_rgb_cube[Spec = At(:B)])
```
