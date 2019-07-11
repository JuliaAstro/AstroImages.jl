using RecipesBase

@recipe function f(img::AstroImage, header_number::Int)
    seriestype   := :heatmap
    aspect_ratio := :equal
    # Right now we only support single frame images,
    # gray scale is a good choice.
    color        := :grays
    img.data[header_number]
end

@recipe function f(img::AstroImage)
    seriestype   := :heatmap
    aspect_ratio := :equal
    # Right now we only support single frame images,
    # gray scale is a good choice.
    color        := :grays
    img.data[1]
end

@recipe function f(img::AstroImage, wcs::WCSTransform)
    seriestype   := :heatmap
    aspect_ratio := :equal
    color        := :grays
    xformatter   := x -> pix2world_xformatter(x, wcs)
    yformatter   := y -> pix2world_yformatter(y, wcs)
    xlabel       := labler_x(wcs)
    ylabel       := labler_y(wcs)
    img.data
end

function pix2world_xformatter(x, wcs::WCSTransform)
    res = round(pix_to_world(wcs, [float(x), float(x)])[1], digits = 2)
    if wcs.cunit[1] == "deg"       # TODO: add symbols for more units
        return string(res)*"°"
    else
        return res[1]
    end
end

function pix2world_yformatter(x, wcs::WCSTransform)
    res = round(pix_to_world(wcs, [float(x), float(x)])[2], digits = 2)
    if wcs.cunit[2] == "deg"       # TODO: add symbols for more units
        return string(res)*"°"
    else
        return res[1]
    end
end

function labler_x(wcs::WCSTransform)
    if length(wcs.ctype[1]) == 0
        return wcs.radesys
    elseif wcs.ctype[1][1:2] == "RA"
        return "Right Ascension (ICRS)"
    elseif wcs.ctype[1][1:4] == "GLON"
        return "Galactic Coordinate"
    elseif wcs.ctype[1][1:4] == "TLON"
        return "ITRS"
    else
        return wcs.ctype[1]
    end
end

function labler_y(wcs::WCSTransform)
    if length(wcs.ctype[2]) == 0
        return wcs.radesys
    elseif wcs.ctype[2][1:3] == "DEC"
        return "Declination (ICRS)"
    elseif wcs.ctype[2][1:4] == "GLAT"
        return "Galactic Coordinate"
    elseif wcs.ctype[2][1:4] == "TLAT"
        return "ITRS"
    else
        return wcs.ctype[2]
    end
end
