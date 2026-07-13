const WCS_HEADERS_TEMPLATES = [
    "DATE",
    "MJD",

    "WCSAXESa",
    "WCAXna",
    "WCSTna",
    "WCSXna",
    "CRPIXja",
    "jCRPna",
    "jCRPXn",
    "TCRPna",
    "TCRPXn",
    "PCi_ja",
    "ijPCna",
    "TPn_ka",
    "TPCn_ka",
    "CDi_ja",
    "ijCDna",
    "TCn_ka",
    "TCDn_ka",
    "CDELTia",
    "iCDEna",
    "iCDLTn",
    "TCDEna",
    "TCDLTn",
    "CROTAi",
    "iCROTn",
    "TCROTn",
    "CUNITia",
    "iCUNna",
    "iCUNIn",
    "TCUNna",
    "TCUNIn",
    "CTYPEia",
    "iCTYna",
    "iCTYPn",
    "TCTYna",
    "TCTYPn",
    "CRVALia",
    "iCRVna",
    "iCRVLn",
    "TCRVna",
    "TCRVLn",
    "LONPOLEa",
    "LONPna",
    "LATPOLEa",
    "LATPna",
    "RESTFREQ",
    "RESTFRQa",
    "RFRQna",
    "RESTWAVa",
    "RWAVna",
    "PVi_ma",
    "iVn_ma",
    "iPVn_ma",
    "TVn_ma",
    "TPVn_ma",
    "PROJPm",
    "PSi_ma",
    "iSn_ma",
    "iPSn_ma",
    "TSn_ma",
    "TPSn_ma",
    "VELREF",
    "CNAMEia",
    "iCNAna",
    "iCNAMn",
    "TCNAna",
    "TCNAMn",
    "CRDERia",
    "iCRDna",
    "iCRDEn",
    "TCRDna",
    "TCRDEn",
    "CSYERia",
    "iCSYna",
    "iCSYEn",
    "TCSYna",
    "TCSYEn",
    "CZPHSia",
    "iCZPna",
    "iCZPHn",
    "TCZPna",
    "TCZPHn",
    "CPERIia",
    "iCPRna",
    "iCPERn",
    "TCPRna",
    "TCPERn",
    "WCSNAMEa",
    "WCSNna",
    "TWCSna",
    "TIMESYS",
    "TREFPOS",
    "TRPOSn",
    "TREFDIR",
    "TRDIRn",
    "PLEPHEM",
    "TIMEUNIT",
    "DATEREF",
    "MJDREF",
    "MJDREFI",
    "MJDREFF",
    "JDREF",
    "JDREFI",
    "JDREFF",
    "TIMEOFFS",
    "DATE-OBS",
    "DOBSn",
    "DATE-BEG",
    "DATE-AVG",
    "DAVGn",
    "DATE-END",
    "MJD-OBS",
    "MJDOBn",
    "MJD-BEG",
    "MJD-AVG",
    "MJDAn",
    "MJD-END",
    "JEPOCH",
    "BEPOCH",
    "TSTART",
    "TSTOP",
    "XPOSURE",
    "TELAPSE",
    "TIMSYER",
    "TIMRDER",
    "TIMEDEL",
    "TIMEPIXR",
    "OBSGEO-X",
    "OBSGXn",
    "OBSGEO-Y",
    "OBSGYn",
    "OBSGEO-Z",
    "OBSGZn",
    "OBSGEO-L",
    "OBSGLn",
    "OBSGEO-B",
    "OBSGBn",
    "OBSGEO-H",
    "OBSGHn",
    "OBSORBIT",
    "RADESYSa",
    "RADEna",
    "RADECSYS",
    "EPOCH",
    "EQUINOXa",
    "EQUIna",
    "SPECSYSa",
    "SPECna",
    "SSYSOBSa",
    "SOBSna",
    "VELOSYSa",
    "VSYSna",
    "VSOURCEa",
    "VSOUna",
    "ZSOURCEa",
    "ZSOUna",
    "SSYSSRCa",
    "SSRCna",
    "VELANGLa",
    "VANGna",
    "RSUN_REF",
    "DSUN_OBS",
    "CRLN_OBS",
    "HGLN_OBS",
    "HGLT_OBS",
    "NAXISn",
    "CROTAn",
    "PROJPn",
    "CPDISja",
    "CQDISia",
    "DPja",
    "DQia",
    "CPERRja",
    "CQERRia",
    "DVERRa",
    "A_ORDER",
    "B_ORDER",
    "AP_ORDER",
    "BP_ORDER",
    "A_DMAX",
    "B_DMAX",
    "A_p_q",
    "B_p_q",
    "AP_p_q",
    "BP_p_q",
    "CNPIX1",
    "PPO3",
    "PPO6",
    "XPIXELSZ",
    "YPIXELSZ",
    "PLTRAH",
    "PLTRAM",
    "PLTRAS",
    "PLTDECSN",
    "PLTDECD",
    "PLTDECM",
    "PLTDECS",
    "PLATEID",
    "AMDXm",
    "AMDYm",
    "WATi_m",
]

# Expand the headers containing lower case specifers into N copies
# Find all lower case templates
const WCS_HEADERS = Set(
    mapreduce(vcat, WCS_HEADERS_TEMPLATES) do template
        if any(islowercase, template)
            template_chars = Vector{Char}(template)
            chars = template_chars[islowercase.(template_chars)]
            out = String[template]
            for replace_target in chars
                newout = String[]
                for template in out
                    for i in [""; string.(1:4); string.('a':'d')]
                        push!(newout, replace(template, replace_target => i))
                    end
                end
                append!(out, newout)
            end
            out
        else
            template
        end
    end
)


"""
    emptywcs()

Given an AbstractArray, return a blank WCSTransform of the appropriate
dimensionality.
"""
# A WCSTransform must have at least one axis, so floor the count at 1. This
# matters for dataless HDUs (e.g. an empty primary), whose placeholder data is
# 0-dimensional; without the floor `WCS(0)` throws `naxis must be >= 1`.
emptywcs(data::AbstractArray) = WCS(max(ndims(data), 1))
emptywcs(img::AstroImage) = WCS(max(length(dims(img)) + length(refdims(img)), 1))


# """
#     filterwcsheader(hdrs::FITSHeader)

# Return a new FITSHeader containing WCS header from `hdrs`.
# This is useful for creating a new image with the same coordinates
# as another.
# """
# function filterwcsheader(hdrs::FITSHeader)
#     include_keys = intersect(keys(hdrs), WCS_HEADERS)
#     return FITSHeader(
#         include_keys,
#         map(key -> hdrs[key], include_keys),
#         map(key -> get_comment(hdrs, key), include_keys),
#     )
# end

"""
    wcsfromheader(img::AstroImage)

Helper function to create a `Dict{Char,WCSTransform}` from the FITS header attached
to `img`, keyed by WCS version character. One transform is included per WCS coordinate
system present in the header (the primary system `' '` plus any alternate systems
`A`–`Z`). If the header carries no WCS information, a single blank transform of the
appropriate dimensionality is returned under the primary key `' '`.
"""
function wcsfromheader(img::AstroImage)
    # `WCS_all` parses every WCS alternate present in the header (via FITSWCS's
    # FITSFiles extension), warning on and skipping any that fail to parse. It
    # returns a `Dict{Char,WCSTransform}` keyed by version character.
    wcsdict = WCS_all(header(img))

    if isempty(wcsdict)
        return Dict(' ' => emptywcs(img))
    end
    return wcsdict
end

# Map FITS stokes numbers to a symbol
function _stokes_symbol(i)
    return if i == 1
        :I
    elseif i == 2
        :Q
    elseif i == 3
        :U
    elseif i == 4
        :V
    elseif i == -1
        :RR
    elseif i == -2
        :LL
    elseif i == -3
        :RL
    elseif i == -4
        :LR
    elseif i == -5
        :XX
    elseif i == -6
        :YY
    elseif i == -7
        :XY
    elseif i == -8
        :YX
    else
        @warn "unknown FITS stokes number $i. See \"Representations of world coordinates in FITS\", Table 7."
        nothing
    end
end
function _stokes_name(symb)
    return if symb == :I
        "Stokes Unpolarized"
    elseif symb == :Q
        "Stokes Linear Q"
    elseif symb == :U
        "Stokes Linear U"
    elseif symb == :V
        "Stokes Circular"
    elseif symb == :RR
        "Right-right cicular"
    elseif symb == :LL
        "Left-left cicular"
    elseif symb == :RL
        "Right-left cross-cicular"
    elseif symb == :LR
        "Left-right cross-cicular"
    elseif symb == :XX
        "X parallel linear"
    elseif symb == :YY
        "Y parallel linear"
    elseif symb == :XY
        "XY cross linear"
    elseif symb == :YX
        "YX cross linear"
    else
        @warn "unknown FITS stokes key $symb. See \"Representations of world coordinates in FITS\", Table 7."
        ""
    end
end

# Coerce a coordinate vector/matrix to `Float64` without copying when possible
_f64(x::AbstractArray{Float64}) = x
_f64(x::Tuple) = collect(Float64, x)
_f64(x) = Float64.(x)

# Reorder the coordinate axes (rows) of a coordinate vector/matrix by `perm`
_permrows(x::AbstractVector, perm) = x[perm]
_permrows(x::AbstractMatrix, perm) = x[perm, :]

# WCS axis number of each selected dim, in `dims(img)` order
_wcsaxes(img::AstroImage) = Int[wcsax(img, d) for d in dims(img)]

# Frozen parent-frame pixel position of a dropped reference dimension.
# Numeric refdims carry the position directly in their lookup value (fractional values are allowed).
# Categorical ones (e.g. a Stokes axis of symbols I/Q/U) are located within the full parent dimension retained in `wcsdims`.
function _refindex(img::AstroImage, refdim)
    if eltype(refdim) <: Number
        return first(refdim)
    end
    wcsdimtuple = getfield(img, :wcsdims)
    parentdim = wcsdimtuple[findfirst(d -> name(d) == name(refdim), wcsdimtuple)]
    return findfirst(==(first(refdim)), collect(parentdim))
end

# Build the `SlicedWCSTransform` describing `img`'s current view of `wcsn`.
# Each kept dim contributes its parent-pixel range (`first:step:last`), each dropped refdim its frozen parent-pixel position.
# WCS axes beyond the image's dim bookkeeping (e.g. degenerate header axes) are frozen at the reference pixel.
function _slicedwcs(img::AstroImage, wcsn)
    w = wcs(img, wcsn)
    wcsdimtuple = getfield(img, :wcsdims)
    keptnames = map(name, dims(img))
    slices = ntuple(w.naxis) do j
        j > length(wcsdimtuple) && return w.crpix[j]
        wd = wcsdimtuple[j]
        di = findfirst(==(name(wd)), keptnames)
        if di === nothing
            _refindex(img, refdims(img)[findfirst(rd -> name(rd) == name(wd), refdims(img))])
        else
            d = dims(img)[di]
            first(d):step(d):last(d)
        end
    end
    return slice_wcs(w, slices...)
end

# Permutation from `dims(img)` order to the sliced WCS's axis slots.
# Its kept axes are ordered by ascending parent-WCS-axis index.
function _sliceperm(img::AstroImage)
    kept = sort!([wcsax(img, d) for d in dims(img)])
    return Int[findfirst(==(wcsax(img, d)), kept) for d in dims(img)]
end

# Expand dims-ordered coordinates into a full parent-frame pixel buffer in WCS axis order.
# Kept dims map slice-local --> parent via their lookup (or pass through unchanged when `parent=true`).
# Frozen refdims fill their slots, and any remaining axes stay at the reference pixel.
function _parentpixels(img::AstroImage, pix::AbstractVecOrMat, wcsn, parent::Bool)
    w = wcs(img, wcsn)
    P = ndims(pix) > 1 ? repeat(Vector(w.crpix), 1, size(pix, 2)) : Vector{Float64}(w.crpix)
    for (i, d) in enumerate(dims(img))
        j = wcsax(img, d)
        if parent
            P[j, :] .= pix[i, :]
        else
            P[j, :] .= (pix[i, :] .- 1) .* step(d) .+ first(d)
        end
    end
    for rd in refdims(img)
        P[wcsax(img, rd), :] .= _refindex(img, rd)
    end
    return P
end

"""
    pixel_to_world(img::AstroImage, pixcoords; wcsn = ' ', all = false, parent = false)

Given an `AstroImage`, look up the world coordinates of the pixels given by `pixcoords`
using FITSWCS.jl and a WCSTransform calculated from any FITS header present in `img`.
If no WCS information is in the header, or the axes are all linear, this will just return pixel coordinates.

`pixcoords` may be a vector (one coordinate) or a matrix whose columns are coordinates,
given in the order of `dims(img)`, i.e., 1-based positions within your current selection of the image.
For example, if you select a slice like this:

```julia-repl
julia> cube = load("some-3d-cube.fits")
julia> slice = cube[10:20, 30:40, 5]
```

Then to look up the coordinates of the pixel in the bottom left corner of `slice`, run:

```julia-repl
julia> world_coords = pixel_to_world(slice, [1, 1])
[10, 30]
```

If WCS information was present in the header of `cube`, then those coordinates
would be resolved using axis 1, 2, and 3 respectively.

Keyword arguments:

- `wcsn`: Which WCS version character to use (`' '` for the primary system, `'A'`–`'Z'` for alternates).
- `all=true`: Return world coordinates for **all** WCS axes (in WCS axis order),
  including axes frozen by slicing, instead of only the selected dims.
- `parent=true`: Interpret `pixcoords` as 1-based pixel positions in the parent (original) array,
   rather than in the current slice.

Note: Coordinates must be provided in the order of `dims(img)`. If you transpose an image,
the order you pass the coordinates should not change.
"""
function FITSWCS.pixel_to_world(img::AstroImage, pixcoords; wcsn = ' ', all = false, parent = false)
    pix = _f64(pixcoords)
    size(pix, 1) == length(dims(img)) || throw(
        DimensionMismatch(
            "Got $(size(pix, 1)) pixel coordinates but the image has $(length(dims(img))) dimensions."
        )
    )
    worldcoords = pixel_to_world(wcs(img, wcsn), _parentpixels(img, pix, wcsn, parent))
    # Return every WCS axis, or filter to the axes of the selected dims.
    return all ? worldcoords : _permrows(worldcoords, _wcsaxes(img))
end


"""
    world_to_pixel(img::AstroImage, worldcoords; wcsn = ' ', parent = false)

Given an `AstroImage`, look up the pixel coordinates corresponding to
the world coordinates `worldcoords`. This is the inverse of [`pixel_to_world`](@ref).
World coordinates are resolved using FITSWCS.jl and a WCSTransform calculated from any
FITS header present in `img`. If no WCS information is in the header, or
the axes are all linear, this just returns the input coordinates.

`worldcoords` may be a vector (one coordinate) or a matrix whose columns are coordinates,
given in the order of `dims(img)`. The returned pixel coordinates need not lie within the bounds of the image,
and in general lie at fractional pixel positions.

By default the result contains one 1-based slice-local pixel coordinate per selected dim, in `dims(img)` order.
With `parent = true` the world coordinates are inverted through the full parent-frame transform instead.
Axes frozen by slicing contribute their exact world values, and the result contains parent pixel coordinates
for **all** WCS axes, in WCS axis order.

If the current slice drops a pixel axis that the remaining world axes depend on
(e.g. one axis of a celestial longitude/latitude pair), the remaining world coordinates
alone do not determine pixel coordinates and an `ArgumentError` is thrown.
Invert through the full transform via `world_to_pixel(wcs(img, wcsn), fullworldcoords)` instead.
"""
function FITSWCS.world_to_pixel(img::AstroImage, worldcoords; parent = false, wcsn = ' ')
    world = _f64(worldcoords)
    size(world, 1) == length(dims(img)) || throw(
        DimensionMismatch(
            "Got $(size(world, 1)) world coordinates but the image has $(length(dims(img))) dimensions."
        )
    )
    if !parent
        # Delegate to a `SlicedWCSTransform`, which fills axes frozen by slicing
        # with their exact world values and returns slice-local pixel coordinates
        # for the kept axes. Requires each selected dim to correspond to exactly
        # one surviving world axis (`world_keep == pixel_keep`).
        sw = _slicedwcs(img, wcsn)
        sw.world_keep == sw.pixel_keep || throw(
            ArgumentError(
                "The current slice drops pixel axes that the remaining world axes depend on (e.g. one axis of a celestial lon/lat pair), so " *
                "$(length(dims(img))) world coordinates do not determine pixel coordinates." *
                " Invert through the full transform instead: `world_to_pixel(wcs(img, wcsn), fullworldcoords)`."
            )
        )
        perm = _sliceperm(img)
        return _permrows(world_to_pixel(sw, _permrows(world, invperm(perm))), perm)
    end
    # parent = true: fill a full world-coordinate buffer.
    # User values for the selected dims, exact frozen-axis world values elsewhere
    # (evaluated with one forward transform), and invert through the parent-frame transform.
    w = wcs(img, wcsn)
    W = ndims(world) > 1 ? zeros(w.naxis, size(world, 2)) : zeros(w.naxis)
    if w.naxis > length(dims(img))
        W .= pixel_to_world(img, ones(length(dims(img))); wcsn, all = true)
    end
    for (i, d) in enumerate(dims(img))
        W[wcsax(img, d), :] .= world[i, :]
    end
    return world_to_pixel(w, W)
end


# ── Deprecated names ────────────────────────────────────────────────────────
# `pix_to_world` / `world_to_pix` were renamed to match FITSWCS.jl's
# `pixel_to_world` / `world_to_pixel`. `pix_to_world!` (which never had an
# `AstroImage` method) has been dropped.
Base.@deprecate pix_to_world pixel_to_world false
Base.@deprecate world_to_pix world_to_pixel false

function world_to_pix!(pixcoords_out, img::AstroImage, worldcoords; kwargs...)
    Base.depwarn(
        "`world_to_pix!` is deprecated; use `world_to_pixel(img, worldcoords)`, " *
            "which allocates and returns the pixel coordinates.",
        :world_to_pix!,
    )
    return copyto!(pixcoords_out, world_to_pixel(img, worldcoords; kwargs...))
end
