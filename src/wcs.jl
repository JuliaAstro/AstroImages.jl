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
Is = [""; string.(1:4)]
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
    # Load the header without ignoring rejected to get error messages
    try
        wcsout = WCS.from_header(
            string(header(img));
            ignore_rejected=false,
            relax
        )
    catch err
        # Load them again ignoring error messages
        wcsout = WCS.from_header(
            string(header(img));
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
# TODO: wcsfromheader(::FITSHeader,)


# Smart versions of pix_to_world and world_to_pix
"""
    pix_to_world(img::AstroImage, pixcoords)

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
julia> world_coords = pix_to_world(img, (1, 1))
[10, 30, 5]
```
If WCS information was present in the header of `cube`, then those coordinates
would be resolved using axis 1, 2, and 3 respectively.

!! Coordinates must be provided in the order of `dims(img)`. If you transpose 
an image, the order you pass the coordinates should not change.
"""
function WCS.pix_to_world(img::AstroImage, pixcoords)
    if pixcoords isa Array{Float64}
        pixcoords_prepared = pixcoords
    else
        pixcoords_prepared = [Float64(c) for c in pixcoords]
    end
    D_out = length(dims(img))+length(refdims(img))
    if ndims(pixcoords_prepared) > 1
        out = similar(pixcoords_prepared, Float64, D_out, size(pixcoords_prepared,2)) 
    else
        out = similar(pixcoords_prepared, Float64, D_out) 
    end
    return WCS.pix_to_world!(out, img, pixcoords_prepared)
end
function WCS.pix_to_world(img::AstroImage, pixcoords::NTuple{N,DimensionalData.Dimension}) where N
    pixcoords_prepared = zeros(Float64, length(pixcoords))
    for dim in pixcoords
        j = findfirst(dimnames) do dim_candidate
            name(dim_candidate) == name(dim)
        end
        pixcoords_prepared[j] = dim[]
    end
    D_out = length(dims(img))+length(refdims(img))
    out = zeros(Float64, D_out)
    return WCS.pix_to_world!(out, img, pixcoords_prepared)
end
WCS.pix_to_world(img::AstroImage, pixcoords::DimensionalData.Dimension...) = WCS.pix_to_world(img, pixcoords)
function WCS.pix_to_world!(worldcoords_out, img::AstroImage, pixcoords)
    # Find the coordinates in the parent array.
    # Dimensional data
    pixcoords_floored = floor.(Int, pixcoords)
    pixcoords_frac = (pixcoords .- pixcoords_floored) .* step.(dims(img))
    parentcoords = getindex.(dims(img), pixcoords_floored) .+ pixcoords_frac
    # WCS.jl is very restrictive. We need to supply a Vector{Float64}
    # as input, not any other kind of collection.
    # TODO: avoid allocation in case where refdims=() and pixcoords isa Array{Float64}
    parentcoords_prepared = zeros(length(dims(img))+length(refdims(img)))

    # TODO: we need to pass in ref dims locations as well, and then filter the
    # output to only include the dims of the current slice?
    # out = zeros(Float64, length(dims(img))+length(refdims(img)), size(pixcoords,2))
    for (i, dim) in enumerate(dims(img))
        j = findfirst(dimnames) do dim_candidate
            name(dim_candidate) == name(dim)
        end
        parentcoords_prepared[j] = parentcoords[i]
    end
    for dim in refdims(img)
        j = findfirst(dimnames) do dim_candidate
            name(dim_candidate) == name(dim)
        end
        parentcoords_prepared[j] = dim[1]
    end

    return WCS.pix_to_world!(wcs(img), parentcoords_prepared, worldcoords_out)
end


##
function WCS.world_to_pix(img::AstroImage, worldcoords)
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
    return WCS.world_to_pix!(out, img, worldcoords_prepared)
end
function WCS.world_to_pix!(pixcoords_out, img::AstroImage, worldcoords)
    # # Find the coordinates in the parent array.
    # # Dimensional data
    # worldcoords_floored = floor.(Int, worldcoords)
    # worldcoords_frac = (worldcoords .- worldcoords_floored) .* step.(dims(img))
    # parentcoords = getindex.(dims(img), worldcoords_floored) .+ worldcoords_frac
    # WCS.jl is very restrictive. We need to supply a Vector{Float64}
    # as input, not any other kind of collection.
    # TODO: avoid allocation in case where refdims=() and worldcoords isa Array{Float64}
    worldcoords_prepared = zeros(length(dims(img))+length(refdims(img)))

    # TODO: we need to pass in ref dims locations as well, and then filter the
    # output to only include the dims of the current slice?
    # out = zeros(Float64, length(dims(img))+length(refdims(img)), size(worldcoords,2))
    for (i, dim) in enumerate(dims(img))
        j = findfirst(dimnames) do dim_candidate
            name(dim_candidate) == name(dim)
        end
        worldcoords_prepared[j] = worldcoords[i]
    end
    for dim in refdims(img)
        j = findfirst(dimnames) do dim_candidate
            name(dim_candidate) == name(dim)
        end
        worldcoords_prepared[j] = dim[1]
    end

    # This returns the parent pixel coordinates.
    WCS.world_to_pix!(wcs(img), worldcoords_prepared, pixcoords_out)

    pixcoords_out .-= first.(dims(img))
    pixcoords_out .= pixcoords_out ./ step.(dims(img)) .+ 1
end