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
emptywcs(img::AstroImage) = WCSTransform(length(getfield(img, :wcs_axes)))



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
function WCS.pix_to_world!(world_coords_out, img::AstroImage, pixcoords)
    # Find the coordinates in the parent array.
    # Dimensional data
    pixcoords_floored = floor.(Int, pixcoords)
    pixcoords_frac = (pixcoords .- pixcoords_floored) .* step.(dims(img))
    parentcoords = getindex.(dims(img), pixcoords_floored) .+ pixcoords_frac
    # WCS.jl is very restrictive. We need to supply a Vector{Float64}
    # as input, not any other kind of collection.
    if parentcoords isa Array{Float64}
        parentcoords_prepared = parentcoords
    else
        parentcoords_prepared = [Float64(c) for c in parentcoords]
    end

    # TODO: we need to pass in ref dims locations as well, and then filter the
    # output to only include the dims of the current slice?
    # out = zeros(Float64, length(dims(img))+length(refdims(img)), size(pixcoords,2))

    return WCS.pix_to_world!(wcs(img), parentcoords_prepared, world_coords_out)
end
function WCS.pix_to_world(img::AstroImage, pixcoords)
    if pixcoords isa Array{Float64}
        pixcoords_prepared = pixcoords
    else
        pixcoords_prepared = [Float64(c) for c in pixcoords]
    end
    out = similar(pixcoords_prepared, Float64)
    return WCS.pix_to_world!(out, img, pixcoords_prepared)
end