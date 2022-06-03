
# This is used in VSCode and others

# If the user displays a AstroImageMat of colors (e.g. one created with imview)
# fal through and display the data as an image
Base.show(io::IO, mime::MIME"image/png", img::AstroImageMat{T}; kwargs...) where {T<:Colorant} =
    show(io, mime, parent(img), kwargs...)

# Otherwise, call imview with the default settings.
Base.show(io::IO, mime::MIME"image/png", img::AstroImageMat{T}; kwargs...) where {T<:Union{Number,Missing}} =
    show(io, mime, imview(img), kwargs...)


# Deprecated
# Lazily reinterpret the AstroImageMat as a Matrix{Color}, upon request.
# By itself, Images.colorview works fine on AstroImages. But 
# AstroImages are not normalized to be between [0,1]. So we override 
# colorview to first normalize the data using scaleminmax
@deprecate render(img::AstroImageMat) imview(img, clims=extrema, cmap=nothing)
