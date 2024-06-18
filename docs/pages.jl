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
]


# requiredmods is needed in pages.jl and not make.jl because the builder in
# JuliaAstro.github.io looks for this variable in pages.jl, and moving it
# breaks the documentation build process
requiredmods = Symbol[
    :AstroImages,
    #:Photometry, :Reproject, :Images,
    :Images, :FileIO, :DimensionalData, :ImageTransformations, :ImageFiltering,
    :WCS, :Plots
]
