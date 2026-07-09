using Documenter

DocMeta.setdocmeta!(AstroImages, :DocTestSetup, :(using AstroImages); recursive = true)

doctest(AstroImages)
