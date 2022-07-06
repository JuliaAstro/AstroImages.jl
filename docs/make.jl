using Documenter, AstroImages

# Deps for examples
ENV["GKSwstype"] = "nul"
using Plots, Photometry, ImageTransformations, ImageFiltering, WCS, Reproject, Images, FileIO, DimensionalData

setup = quote
    using AstroImages
    using Random
    Random.seed!(123456)
    
    AstroImages.set_clims!(Percent(99.5))
    AstroImages.set_cmap!(:magma)
    AstroImages.set_stretch!(identity)
end
DocMeta.setdocmeta!(AstroImages, :DocTestSetup, setup; recursive = true)


makedocs(
    sitename="AstroImages.jl",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "manual/getting-started.md",
            "Loading & Saving Images" => "manual/loading-images.md",
            "Displaying Images" => "manual/displaying-images.md",
            "Array Operations" => "manual/array.md",
            "Headers" => "manual/headers.md",
            "Dimensions and World Coordinates" => "manual/dimensions-and-world-coordinates.md",
            "Polarization" => "manual/polarization.md",
            "Spectral Axes" => "manual/spec.md",
            "Preserving Wrapper" => "manual/preserving-wrapper.md",
            "Conventions" => "manual/conventions.md",
            "Converting to RGB" => "manual/converting-to-rgb.md",
            "Converting from RGB" => "manual/converting-from-rgb.md",
        ],
        "Guides" => [
            "Blurring & Filtering Images" => "guide/image-filtering.md",
            "Transforming Images" => "guide/image-transformations.md",
            "Reprojecting Images" => "guide/reproject.md",
            "Extracting Photometry" => "guide/photometry.md",
            "Plotting Contours" => "guide/contours.md",
        ],
        "API" => "api.md",
    ],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        assets = ["assets/theme.css"],
    ),
    workdir="..",
    # Specify several modules since we want to include docstrings from functions we've extended
    modules=[AstroImages, Images, FileIO, DimensionalData, WCS],
    # However we have to turnoff doctests since otherwise a failing test in those other packages (e.g. caused by us not setting up their test environement correctly) leads to *our* docs failing to build.
    doctest=false,
    # We still want strict on though since we want to catch typos.
    # strict=true  # will change to false once DimensionalData registers 0.20.8
)


deploydocs(
    repo = "github.com/JuliaAstro/AstroImages.jl.git",
    devbranch = "master",
    push_preview = true
)
