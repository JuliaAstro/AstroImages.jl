# Getting Started

To get started, you will first need to install AstroImages.jl. After starting Julia, enter package-mode by typing `]` and then:

```julia-repl
pkg> add AstroImages
```

To display images and save them in traditional graphics formats like PNG, JPG, GIF, etc., you will also need to add the `ImageIO` package. Once installed, this package doesn't need to be loaded explicitly.


For some of the more advanced visualizations you may also want a
[Makie](https://docs.makie.org/) backend, e.g. `CairoMakie`:

```julia-repl
pkg> add CairoMakie
```

To load the package, run:

```julia
using AstroImages

# And if desired:
using CairoMakie
```
