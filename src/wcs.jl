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
    "WATi_m"
]

# Expand the headers containing lower case specifers into N copies
Is = [""; string.(1:4); string.('a':'d')]
# Find all lower case templates
const WCS_HEADERS = Set(mapreduce(vcat, WCS_HEADERS_TEMPLATES) do template
    if any(islowercase, template)
        template_chars = Vector{Char}(template)
        chars = template_chars[islowercase.(template_chars)]
        out = String[template]
        for replace_target in chars
            newout = String[]
            for template in out
                for i in Is
                    push!(newout, replace(template, replace_target=>i))
                end
            end
            append!(out, newout)
        end
        out
    else
        template
    end
end)



"""
    emptywcs()

Given an AbstractArray, return a blank WCSTransform of the appropriate
dimensionality.
"""
emptywcs(data::AbstractArray) = WCSTransform(ndims(data))
emptywcs(img::AstroImage) = WCSTransform(length(dims(img))+length(refdims(img)))



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
    wcsfromheader(img::AstroImage; relax=WCS.HDR_ALL, ignore_rejected=true)

Helper function to create a WCSTransform from an array and
FITSHeaders.
"""
function wcsfromheader(img::AstroImage; relax=WCS.HDR_ALL)
    # We only need to stringify WCS header. This might just be 4-10 header keywords
    # out of thousands.
    local wcsout

    io = IOBuffer()
    serializeheader(io, header(img))
    hdrstr = String(take!(io))


    # Load the headers without ignoring rejected to get error messages
    try
        wcsout = WCS.from_header(
            hdrstr;
            ignore_rejected=false,
            relax
        )
    catch err
        # Load them again ignoring error messages
        wcsout = WCS.from_header(
            hdrstr;
            ignore_rejected=true,
            relax
        )
        # If that still fails, the use gets the stack trace here
        # If not, print a warning about rejected header
        @warn "WCSTransform was generated by ignoring rejected header. It may not be valid." exception=err
    end

    if length(wcsout) == 1
        return only(wcsout)
    elseif length(wcsout) == 0
        return emptywcs(img)
    else
        @warn "Mutiple WCSTransform returned from header, using first and ignoring the rest."
        return first(wcsout)
    end
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




# Smart versions of pix_to_world and world_to_pix
"""
    pix_to_world(img::AstroImage, pixcoords; all=false)

Given an astro image, look up the world coordinates of the pixels given 
by `pixcoords`. World coordinates are resolved using WCS.jl and a
WCSTransform calculated from any FITS header present in `img`. If
no WCS information is in the header, or the axes are all linear, this will
just return pixel coordinates.

`pixcoords` should be the coordinates in your current selection
of the image. For example, if you select a slice like this:
```julia
julia> cube = load("some-3d-cube.fits")
julia> slice = cube[10:20, 30:40, 5]
```

Then to look up the coordinates of the pixel in the bottom left corner of
`slice`, run:
```julia
julia> world_coords = pix_to_world(img, [1, 1])
[10, 30]
```

If WCS information was present in the header of `cube`, then those coordinates
would be resolved using axis 1, 2, and 3 respectively.

To include world coordinates in all axes, pass `all=true`
```julia
julia> world_coords = pix_to_world(img, [1, 1], all=true)
[10, 30, 5]
```

!! Coordinates must be provided in the order of `dims(img)`. If you transpose 
an image, the order you pass the coordinates should not change.
"""
function WCS.pix_to_world(img::AstroImage, pixcoords; all=false, parent=false)
    if pixcoords isa Array{Float64}
        pixcoords_prepared = pixcoords
    else
        pixcoords_prepared = [Float64(c) for c in pixcoords]
    end
    D_out = length(dims(img))+length(refdims(img))
    if ndims(pixcoords_prepared) > 1
        worldcoords_out = similar(pixcoords_prepared, Float64, D_out, size(pixcoords_prepared,2)) 
    else
        worldcoords_out = similar(pixcoords_prepared, Float64, D_out) 
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
    # WCS.jl is very restrictive. We need to supply a Vector{Float64}
    # as input, not any other kind of collection.
    # TODO: avoid allocation in case where refdims=() and pixcoords isa Array{Float64}
    if ndims(pixcoords_prepared) > 1
        parentcoords_prepared = zeros(length(dims(img))+length(refdims(img)), size(pixcoords_prepared,2))
    else
        parentcoords_prepared = zeros(length(dims(img))+length(refdims(img)))
    end
    # out = zeros(Float64, length(dims(img))+length(refdims(img)), size(pixcoords,2))
    for (i, dim) in enumerate(dims(img))
        j = wcsax(dim)
        parentcoords_prepared[j,:] .= parentcoords[i,:] .- 1
    end
    for dim in refdims(img)
        j = wcsax(dim)
        parentcoords_prepared[j,:] .= dim[1] .- 1
    end

    # Get world coordinates along all slices
    WCS.pix_to_world!(wcs(img), parentcoords_prepared, worldcoords_out)

    # If user requested world coordinates in all dims, not just selected
    # dims of img
    if all
        return worldcoords_out
    end

    # Otherwise filter to only return coordinates along selected dims.
    if ndims(pixcoords_prepared) > 1
        world_coords_of_these_axes = zeros(length(dims(img)), size(pixcoords_prepared,2))
    else
        world_coords_of_these_axes = zeros(length(dims(img)))
    end
    for (i, dim) in enumerate(dims(img))
        j = wcsax(dim)
        world_coords_of_these_axes[i,:] .= worldcoords_out[j,:]
    end

    return world_coords_of_these_axes
end


##
function WCS.world_to_pix(img::AstroImage, worldcoords; parent=false)
    if worldcoords isa Array{Float64}
        worldcoords_prepared = worldcoords
    else
        worldcoords_prepared = [Float64(c) for c in worldcoords]
    end
    D_out = length(dims(img))+length(refdims(img))
    if ndims(worldcoords_prepared) > 1
        out = similar(worldcoords_prepared, Float64, D_out, size(worldcoords_prepared,2)) 
    else
        out = similar(worldcoords_prepared, Float64, D_out) 
    end
    return WCS.world_to_pix!(out, img, worldcoords_prepared; parent)
end
function WCS.world_to_pix!(pixcoords_out, img::AstroImage, worldcoords; parent=false)
    # # Find the coordinates in the parent array.
    # # Dimensional data
    # worldcoords_floored = floor.(Int, worldcoords)
    # worldcoords_frac = (worldcoords .- worldcoords_floored) .* step.(dims(img))
    # parentcoords = getindex.(dims(img), worldcoords_floored) .+ worldcoords_frac
    # WCS.jl is very restrictive. We need to supply a Vector{Float64}
    # as input, not any other kind of collection.
    # TODO: avoid allocation in case where refdims=() and worldcoords isa Array{Float64}
    if ndims(worldcoords) > 1
        worldcoords_prepared = zeros(length(dims(img))+length(refdims(img)),size(worldcoords,2))
    else
        worldcoords_prepared = zeros(length(dims(img))+length(refdims(img)))
    end
    # TODO: we need to pass in ref dims locations as well, and then filter the
    # output to only include the dims of the current slice?
    # out = zeros(Float64, length(dims(img))+length(refdims(img)), size(worldcoords,2))
    for (i, dim) in enumerate(dims(img))
        j = wcsax(dim)
        worldcoords_prepared[j,:] = worldcoords[i,:]
    end
    for dim in refdims(img)
        j = wcsax(dim)
        worldcoords_prepared[j,:] .= dim[1]
    end

    # This returns the parent pixel coordinates.
    # TODO: switch to non-allocating version.
    pixcoords_out .= WCS.world_to_pix(wcs(img), worldcoords_prepared)

    if !parent
        coordoffsets = zeros(length(dims(img))+length(refdims(img)))
        coordsteps = zeros(length(dims(img))+length(refdims(img)))
        for (i, dim) in enumerate(dims(img))
            j = wcsax(dim)
            coordoffsets[j] = first(dims(img)[i])
            coordsteps[j] = step(dims(img)[i])
        end
        for dim in refdims(img)
            j = wcsax(dim)
            coordoffsets[j] = first(dim)
            coordsteps[j] = step(dim)
        end

        pixcoords_out .-= coordoffsets
        pixcoords_out .= (pixcoords_out .+ 1) ./ coordsteps
    end
    return pixcoords_out
end






## For now, we use a copied version of FITSIO's show method for FITSHeader.
# We have to be careful to format things in a way WCSLib will like.
# In particular, we can't put newlines after each 80 characters.
# FITSIO has to do this so users can see the header.

# functions for displaying header values in show(io, header)
hdrval_repr(v::Bool) = v ? "T" : "F"
hdrval_repr(v::String) = @sprintf "'%-8s'" v
hdrval_repr(v::Union{AbstractFloat, Integer}) = string(v)

function serializeheader(io, hdr::FITSHeader)
    n = length(hdr)
    for i=1:n
        if hdr.keys[i] == "COMMENT" || hdr.keys[i] == "HISTORY"
                lastc = min(72, lastindex(hdr.comments[i]))
                @printf io "%s %s" hdr.keys[i] hdr.comments[i][1:lastc]
                print(io, " "^(72-lastc))
        else
            @printf io "%-8s" hdr.keys[i]
            if hdr.values[i] === nothing
                print(io, "                      ")
                rc = 50  # remaining characters on line
            elseif hdr.values[i] isa String
                val = hdrval_repr(hdr.values[i])
                @printf io "= %-20s" val
                rc = length(val) <= 20 ? 50 : 70 - length(val)
            else
                val = hdrval_repr(hdr.values[i])
                @printf io "= %20s" val
                rc = length(val) <= 20 ? 50 : 70 - length(val)
            end
            if length(hdr.comments[i]) > 0
                lastc = min(rc-3, lastindex(hdr.comments[i]))
                @printf io " / %s" hdr.comments[i][1:lastc]
                rc -= lastc + 3
            end
            print(io, " "^rc)
        end
        if i == n
            print(io, "\nEND"*(" "^77))
        else  
            print(io)
        end
    end
end
