using Documenter, DemoCards, AstroImages

# Deps for examples
ENV["GKSwstype"] = "nul"
using Plots, Photometry, ImageTransformations, ImageFiltering, WCS, Reproject

setup = quote
    using AstroImages
    using Random
    Random.seed!(123456)
    
    AstroImages.set_clims!(Percent(99.5))
    AstroImages.set_cmap!(:magma)
    AstroImages.set_stretch!(identity)
end
DocMeta.setdocmeta!(Photometry, :DocTestSetup, setup; recursive = true)

# 1. generate demo files
demopage, postprocess_cb, demo_assets = makedemos("examples") # this is the relative path to docs/

# if there are generated css assets, pass it to Documenter.HTML
assets = []
isnothing(demo_assets) || (push!(assets, demo_assets))

# 2. normal Documenter usage
format = Documenter.HTML(assets = assets)
makedocs(format = format,
         pages = [
            "Home" => "index.md",
            demopage,
         ],
         sitename = "Awesome demos")


makedocs(
    sitename="AstroImages.jl",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "manual/getting-started.md",
            "Loading & Saving Images" => "manual/loading-images.md",
            "Displaying Images" => "manual/displaying-images.md",
            "Headers" => "manual/headers.md",
            "Dimensions and World Coordinates" => "manual/dimensions-and-world-coordinates.md",
            "Polarization" => "manual/polarization.md",
            "Spectral Axes" => "manual/spec.md",
            "Preserving Wrapper" => "manual/preserving-wrapper.md",
            "Conventions" => "manual/conventions.md",
        ],
        "Guides" => [
            "Blurring & Filtering Images" => "guide/image-filtering.md",
            "Transforming Images" => "guide/image-transformations.md",
            "Reprojecting Images" => "guide/reproject.md",
            "Extracting Photometry" => "guide/photometry.md",
        ],
        demopage,
        "API" => "api.md",
    ],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    workdir=".."
)

# 3. postprocess after makedocs
postprocess_cb()

deploydocs(
    repo = "github.com/JuliaAstro/AstroImages.jl.git",
    devbranch = "master",
    push_preview = true
)
