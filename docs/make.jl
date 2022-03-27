using Documenter, AstroImages
makedocs(
    sitename="AstroImages.jl",
    pages = [
        "Home" => "index.md",
        "Tour" => "tour.md",
        "Tutorials" => [
            "Getting Started" => "getting-started.md"
        ],
        "API" => "api.md",
    ],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    workdir=".."
)


# deploydocs(
#     repo = "github.com/sefffal/AstroImages.jl.git",
#     devbranch = "main"
# )
