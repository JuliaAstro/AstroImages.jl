# This is used in Jupyter notebooks
Base.show(io::IO, mime::MIME"image/png", img::AstroImage; kwargs...) =
    show(io, mime, img.data, kwargs...)
