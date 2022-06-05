### A Pluto.jl notebook ###
# v0.19.6

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 685479e8-1ad5-48d8-b9fe-f2cf8a672700
using AstroImages, PlutoUI

# ╔═╡ 59e1675f-9426-4bc4-88cc-e686ed90b6b5
md"""
Download a FITS image and open it.
Apply `restrict` to downscale 2x for faster rendering.
"""

# ╔═╡ d1e5947b-2c1a-46fc-ab8f-feeba03453e7
img = AstroImages.restrict(
	AstroImage(download("http://www.astro.uvic.ca/~wthompson/astroimages/fits/656nmos.fits"))
);

# ╔═╡ c9ebe984-4630-47c1-a941-795293f5b3c1
md"""
Display options
"""

# ╔═╡ a3e81f3f-203b-47b7-ac60-b4267eddfad4
md"""

| parameter | value |
|-----------|-------|
|`cmap` | $( @bind cmap  Select([:magma, :turbo, :ice, :viridis, :seaborn_icefire_gradient, "red"]) ) |
|`clims`| $( @bind clims Select([Percent(99.5), Percent(95), Percent(80), Zscale(), (0, 400)]) ) |
| `stretch` | $( @bind stretch  Select([identity, asinhstretch, logstretch, sqrtstretch, powstretch, powerdiststretch, squarestretch])) |
| `contrast` | $(@bind contrast Slider(0:0.1:2.0, default=1.0)) |
| `bias` | $(@bind bias Slider(0:0.1:1.0, default=0.5)) | 
"""

# ╔═╡ 2315ffec-dc49-413a-b0d6-1bcce2addd76
imview(img; cmap, clims, stretch, contrast, bias)

# ╔═╡ d2bd2f13-ed23-42c5-9317-5b48ec3a8bb7
md"""
## `implot`
Uncomment the following cells to use `Plots` instead.
"""

# ╔═╡ fe6b5b76-8b77-4bfc-a2e8-bcc0b78ad764
# using Plots

# ╔═╡ f557784e-828c-415e-abb0-964b3a9fe8ef
# implot(img; cmap, clims, stretch, contrast, bias)

# ╔═╡ Cell order:
# ╠═685479e8-1ad5-48d8-b9fe-f2cf8a672700
# ╟─59e1675f-9426-4bc4-88cc-e686ed90b6b5
# ╠═d1e5947b-2c1a-46fc-ab8f-feeba03453e7
# ╟─c9ebe984-4630-47c1-a941-795293f5b3c1
# ╟─a3e81f3f-203b-47b7-ac60-b4267eddfad4
# ╠═2315ffec-dc49-413a-b0d6-1bcce2addd76
# ╟─d2bd2f13-ed23-42c5-9317-5b48ec3a8bb7
# ╠═fe6b5b76-8b77-4bfc-a2e8-bcc0b78ad764
# ╠═f557784e-828c-415e-abb0-964b3a9fe8ef
