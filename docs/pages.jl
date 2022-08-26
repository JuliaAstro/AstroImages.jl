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

requiredmods = Symbol[
#     # :Photometry, :ImageTransformations, :ImageFiltering, :WCS, :Reproject, :Images, :FileIO,
    :Images, :FileIO, :DimensionalData, :ImageTransformations, :ImageFiltering, :WCS, :Plots
]