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
emptywcs(data::AbstractArray) = WCS(ndims(data))
emptywcs(img::AstroImage) = WCS(length(dims(img)) + length(refdims(img)))


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
    # FITSIO extension), warning on and skipping any that fail to parse. It
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


# Dimension-aware wrappers that extend FITSWCS's `pixel_to_world` / `world_to_pixel`
# with methods accepting an `AstroImage`: they handle dims/refdims, slicing, and
# coordinate scaling, then delegate the projection to the underlying `WCSTransform`.
"""
    pixel_to_world(img::AstroImage, pixcoords; all=false)

Given an astro image, look up the world coordinates of the pixels given
by `pixcoords`. World coordinates are resolved using FITSWCS.jl and a
WCSTransform calculated from any FITS header present in `img`. If
no WCS information is in the header, or the axes are all linear, this will
just return pixel coordinates.

`pixcoords` should be the coordinates in your current selection
of the image. For example, if you select a slice like this:
```julia-repl
julia> cube = load("some-3d-cube.fits")
julia> slice = cube[10:20, 30:40, 5]
```

Then to look up the coordinates of the pixel in the bottom left corner of
`slice`, run:
```julia-repl
julia> world_coords = pixel_to_world(img, [1, 1])
[10, 30]
```

If WCS information was present in the header of `cube`, then those coordinates
would be resolved using axis 1, 2, and 3 respectively.

To include world coordinates in all axes, pass `all=true`
```julia-repl
julia> world_coords = pixel_to_world(img, [1, 1], all=true)
[10, 30, 5]
```

!! Coordinates must be provided in the order of `dims(img)`. If you transpose
an image, the order you pass the coordinates should not change.
"""
function FITSWCS.pixel_to_world(img::AstroImage, pixcoords; wcsn = ' ', all = false, parent = false)
    if pixcoords isa Array{Float64}
        pixcoords_prepared = pixcoords
    else
        pixcoords_prepared = [Float64(c) for c in pixcoords]
    end
    # Find the coordinates in the parent array.
    # Dimensional data
    # pixcoords_floored = floor.(Int, pixcoords)
    # pixcoords_frac = (pixcoords .- pixcoords_floored) .* step.(dims(img))
    # parentcoords = getindex.(dims(img), pixcoords_floored) .+ pixcoords_frac
    if parent
        parentcoords = pixcoords
    else
        parentcoords = pixcoords .* step.(dims(img)) .+ first.(dims(img))
    end
    # Build a Float64 buffer sized to the WCS's full axis count; the loops below
    # scatter this image's dims/refdims into their WCS-axis positions.
    # TODO: avoid allocation in case where refdims=() and pixcoords isa Array{Float64}
    if ndims(pixcoords_prepared) > 1
        parentcoords_prepared = zeros(wcs(img, wcsn).naxis, size(pixcoords_prepared, 2))
    else
        parentcoords_prepared = zeros(wcs(img, wcsn).naxis)
    end
    # out = zeros(Float64, wcs(img,wcsn).naxis, size(pixcoords,2))
    for (i, dim) in enumerate(dims(img))
        j = wcsax(img, dim)
        parentcoords_prepared[j, :] .= parentcoords[i, :] .- 1
    end
    for dim in refdims(img)
        j = wcsax(img, dim)
        # Non numeric reference dims can be used, e.g. a polarization axis of symbols I, Q, U, etc.
        if eltype(dim) <: Number
            z = dim[1] - 1
        else
            # Find the index of the symbol into the parent cube
            parentrefdim = img.wcsdims[findfirst(d -> name(d) == name(dim), img.wcsdims)]
            z = findfirst(==(first(dim)), collect(parentrefdim)) - 1
        end
        parentcoords_prepared[j, :] .= z
    end

    # Get world coordinates along all slices.
    worldcoords_out = pixel_to_world(wcs(img, wcsn), parentcoords_prepared)

    # If user requested world coordinates in all dims, not just selected
    # dims of img
    if all
        return worldcoords_out
    end

    # Otherwise filter to only return coordinates along selected dims.
    if ndims(pixcoords_prepared) > 1
        world_coords_of_these_axes = zeros(length(dims(img)), size(pixcoords_prepared, 2))
    else
        world_coords_of_these_axes = zeros(length(dims(img)))
    end
    for (i, dim) in enumerate(dims(img))
        j = wcsax(img, dim)
        world_coords_of_these_axes[i, :] .= worldcoords_out[j, :]
    end

    return world_coords_of_these_axes
end


"""
    world_to_pixel(img::AstroImage, worldcoords)

Given an astro image, look up the pixel coordinates corresponding to the world
coordinates `worldcoords`. This is the inverse of [`pixel_to_world`](@ref): world
coordinates are resolved using FITSWCS.jl and a WCSTransform calculated from any
FITS header present in `img`. If no WCS information is in the header, or the axes
are all linear, this just returns the input coordinates.

The returned pixel coordinates need not lie within the bounds of the image, and
in general lie at fractional pixel positions.

`worldcoords` must be provided in the order of `dims(img)`.
"""
function FITSWCS.world_to_pixel(img::AstroImage, worldcoords; parent = false, wcsn = ' ')
    if worldcoords isa Array{Float64}
        worldcoords_prepared = worldcoords
    else
        worldcoords_prepared = [Float64(c) for c in worldcoords]
    end
    return _world_to_pixel(img, worldcoords_prepared; wcsn, parent)
end

# Internal worker backing `world_to_pixel`. Returns the parent-adjusted pixel coordinates.
function _world_to_pixel(img::AstroImage, worldcoords; wcsn = ' ', parent = false)
    # # Find the coordinates in the parent array.
    # # Dimensional data
    # worldcoords_floored = floor.(Int, worldcoords)
    # worldcoords_frac = (worldcoords .- worldcoords_floored) .* step.(dims(img))
    # parentcoords = getindex.(dims(img), worldcoords_floored) .+ worldcoords_frac
    # Build a Float64 buffer sized to the WCS's full axis count; the loops below
    # scatter this image's world coords into their WCS-axis positions.
    # TODO: avoid allocation in case where refdims=() and worldcoords isa Array{Float64}
    if ndims(worldcoords) > 1
        worldcoords_prepared = zeros(wcs(img, wcsn).naxis, size(worldcoords, 2))
    else
        worldcoords_prepared = zeros(wcs(img, wcsn).naxis)
    end
    # TODO: unlike `pixel_to_world` (which has an `all` kwarg and filters its
    # output to the selected dims), this returns coordinates for every WCS axis.
    # Consider mirroring that: add an `all` kwarg and filter to the current slice.
    # out = zeros(Float64, wcs(img,wcsn).naxis, size(worldcoords,2))
    for (i, dim) in enumerate(dims(img))
        j = wcsax(img, dim)
        worldcoords_prepared[j, :] = worldcoords[i, :]
    end
    for dim in refdims(img)
        j = wcsax(img, dim)
        # Non numeric reference dims can be used, e.g. a polarization axis of symbols I, Q, U, etc.
        if eltype(dim) <: Number
            z = dim[1]
        else
            # Find the index of the symbol into the parent cube
            parentrefdim = img.wcsdims[findfirst(d -> name(d) == name(dim), img.wcsdims)]
            z = findfirst(==(first(dim)), collect(parentrefdim)) - 1
        end
        worldcoords_prepared[j, :] .= z
    end

    pixcoords_out = world_to_pixel(wcs(img, wcsn), worldcoords_prepared)

    if !parent
        coordoffsets = zeros(wcs(img, wcsn).naxis)
        coordsteps = zeros(wcs(img, wcsn).naxis)
        for (i, dim) in enumerate(dims(img))
            j = wcsax(img, dim)
            coordoffsets[j] = first(dims(img)[i])
            coordsteps[j] = step(dims(img)[i])
        end
        for dim in refdims(img)
            j = wcsax(img, dim)
            # Non numeric reference dims can be used, e.g. a polarization axis of symbols I, Q, U, etc.
            if eltype(dim) <: Number
                coordoffsets[j] = first(dim)
                coordsteps[j] = step(dim)
            else
                # Find the index of the symbol into the parent cube
                parentrefdim = img.wcsdims[findfirst(d -> name(d) == name(dim), img.wcsdims)]
                z = findfirst(==(first(dim)), collect(parentrefdim))
                coordoffsets[j] = z - 1
                coordsteps[j] = 1
            end
        end

        # `world_to_pixel` returns an immutable `SVector` for single-coordinate
        # (vector) inputs, so apply the parent-frame correction as a fresh
        # broadcast rather than mutating `pixcoords_out` in place.
        pixcoords_out = (pixcoords_out .- coordoffsets .+ 1) ./ coordsteps
    end
    return pixcoords_out
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
