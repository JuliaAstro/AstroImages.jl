using Documenter, DocumenterInterLinks
using AstroImages

# Deps for examples
ENV["GKSwstype"] = "nul"

using Photometry, Reproject, Images

setup = quote
    using AstroImages
    using Random
    Random.seed!(123456)

    AstroImages.set_clims!(Percent(99.5))
    AstroImages.set_cmap!(:magma)
    AstroImages.set_stretch!(identity)
end
DocMeta.setdocmeta!(AstroImages, :DocTestSetup, setup; recursive = true)

links = InterLinks(
    "DimensionalData" => (
        "https://rafaqz.github.io/DimensionalData.jl/stable/",
        "https://rafaqz.github.io/DimensionalData.jl/stable/objects.inv",
     ),
    "FileIO" => (
        "https://juliaio.github.io/FileIO.jl/stable/",
        "https://juliaio.github.io/FileIO.jl/stable/objects.inv",
    ),
    "WCS" => (
        "https://juliaastro.org/WCS/stable/",
        "https://juliaastro.org/WCS/stable/objects.inv",
     ),
)

makedocs(;
    sitename = "AstroImages.jl",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "manual/getting-started.md",
            "Loading & Saving Images" => "manual/loading-and-saving-images.md",
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
    format = Documenter.HTML(;
        assets = [
            "assets/theme.css",
            "assets/favicon.ico",
        ],
        canonical = "https://JuliaAstro.org/AstroImages/stable/",
        example_size_threshold = 0,
    ),
    plugins = [links],
)

# CI only: deploy docs
in_CI_env = get(ENV, "CI", "false") == "true"
if in_CI_env
    deploydocs(;
        repo = "github.com/JuliaAstro/AstroImages.jl.git",
        push_preview = true,
        versions = ["stable" => "v^", "v#.#"], # Restrict to minor releases
    )
end
