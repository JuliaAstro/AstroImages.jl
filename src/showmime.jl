# _brightness_contrast(color, matrix::AbstractMatrix{T}, brightness, contrast) where {T} =
#     @. color(matrix / 255 * T(contrast) + T(brightness) / 255)

# """
#     brightness_contrast(image::AstroImageMat; brightness_range = 0:255, contrast_range = 1:1000, header_number = 1)

# Visualize the fits image by changing the brightness and contrast of image.


# This is used in VSCode and others

# If the user displays a AstroImageMat of colors (e.g. one created with imview)
# fal through and display the data as an image
Base.show(io::IO, mime::MIME"image/png", img::AstroImageMat{T}; kwargs...) where {T<:Colorant} =
    show(io, mime, arraydata(img), kwargs...)

# Otherwise, call imview with the default settings.
Base.show(io::IO, mime::MIME"image/png", img::AstroImageMat{T}; kwargs...) where {T<:Union{Real,Missing}} =
    show(io, mime, imview(img), kwargs...)

# Special handling for complex images
function Base.show(io::IO, mime::MIME"image/png", img::AstroImageMat{T}; kwargs...) where {T<:Complex}
    # Not sure we really want to support this functionality, but we will allow it for
    # now with a warning.
    @warn "Displaying complex image as magnitude and phase (maxlog=1)" maxlog=1
    mag_view = imview(abs.(img))
    angle_view = imview(angle.(img), clims=(-pi, pi), cmap=:cyclic_mygbm_30_95_c78_n256_s25)
    show(io, mime, vcat(mag_view,angle_view), kwargs...)
end

# const _autoshow = Base.RefValue{Bool}(true)
# """
#     set_autoshow!(autoshow::Bool)

# By default, `display`ing a 2D AstroImage e.g. at the REPL or in a notebook
# shows it as a PNG image using the `imview` function and user's default
# colormap, stretch, etc.
# If set to false, displaying an image will just show a textual representation.
# You can still visualize images using `imview`.
# """
# function set_autoshow!(autoshow::Bool)
#     _autoshow[] = autoshow
# end
# TODO: for this to work, we need to actually add and remove a show method. TBD how.

# TODO: ensure this still works and is backwards compatible
# Lazily reinterpret the AstroImageMat as a Matrix{Color}, upon request.
# By itself, Images.colorview works fine on AstroImages. But 
# AstroImages are not normalized to be between [0,1]. So we override 
# colorview to first normalize the data using scaleminmax
function render(img::AstroImageMat{T,N}) where {T,N}
    # imgmin, imgmax = img.minmax
    imgmin, imgmax = extrema(img)
    # Add one to maximum to work around this issue:
    # https://github.com/JuliaMath/FixedPointNumbers.jl/issues/102
    f = scaleminmax(_float(imgmin), _float(max(imgmax, imgmax + one(T))))
    return colorview(Gray, f.(_float.(img.data)))
end
Images.colorview(img::AstroImageMat) = render(img)


using Base64


"""
    interact_cube(cube::AbstractArray, initial_slices=)
If running in an interactive environment like IJulia, allow scrolling through
the slices of a cube interactively using `imview`. 
Accepts the same keyword arguments as `imview`, with one exception. Here,
if `clims` is a function, it is applied once to all the finite pixels in the cube
to determine the color limits rather than just the currently displayed slice.
"""
function interact_cube(
    cube::Union{AbstractArray{T,3},AbstractArray{T,4},AbstractArray{T,5}},
    initial_slices=first.(axes.(Ref(cube),3:ndims(cube)));
    clims=_default_clims[],
    imview_kwargs...
) where T
    # Create a single view that updates
    buf = cube[:,:,initial_slices...]

    # If not provided, calculate clims by applying to the whole cube
    # rather than just one slice
    # Users can pass clims as an array or tuple containing the minimum and maximum values
    if typeof(clims) <: AbstractArray || typeof(clims) <: Tuple
        if length(clims) != 2
            error("clims must have exactly two values if provided.")
        end
        clims = (first(clims), last(clims))
    # Or as a callable that computes them given an iterator
    else
        clims = clims(skipmissingnan(cube))
    end

    v = imview(buf; clims, imview_kwargs...)

    cubesliders = map(3:ndims(cube)) do ax_i
        ax = axes(cube, ax_i)
        return Interact.slider(ax, initial_slices[ax_i-2], label=string(dimnames[ax_i]));
    end

    function viz(sliderindexes)
        buf .= view(cube,:,:,sliderindexes...)
        b64 = Base64.base64encode() do io
            show(io, MIME("image/png"), v)
        end
        HTML("<div style='width:100vw; height: calc(100vh - 80px); image-rendering: pixelated; background-position: center; background-repeat: no-repeat; background-size: contain; background-image: url(\"data:image/png;base64,$(b64)\");' width=400/>")
    end

    return vbox(cubesliders..., map(viz, cubesliders...))
end

# This is used in Jupyter notebooks
Base.show(io::IO, mime::MIME"text/html", cube::Union{AstroImage{T,3},AstroImage{T,4},AstroImage{T,5}}; kwargs...) where T =
    show(io, mime, interact_cube(cube), kwargs...)