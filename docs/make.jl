using AstroImages
using Photometry, Reproject, Images
using Documenter, DocumenterInterLinks
using Documenter.Remotes: GitHub

# Deps for examples
ENV["GKSwstype"] = "nul"

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
    modules = [AstroImages],
    authors = ["Mosè Giordano", "Rohit Kumar", "William Thompson"],
    sitename = "AstroImages.jl",
    format = Documenter.HTML(;
        assets = [
            "assets/theme.css",
            "assets/favicon.ico",
        ],
        example_size_threshold = 0,
    ),
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
    doctest = false,
    plugins = [links],
)

# CI only: deploy docs
in_CI_env = get(ENV, "CI", "false") == "true"
if in_CI_env
    deploydocs(;
        repo = "github.com/JuliaAstro/AstroImages.jl",
        push_preview = true,
        versions = ["stable" => "v^", "v#.#"], # Restrict to minor releases
    )
end
