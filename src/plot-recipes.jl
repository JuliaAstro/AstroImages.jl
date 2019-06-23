using RecipesBase

@recipe function f(img::AstroImage)
    seriestype   := :heatmap
    aspect_ratio := :equal
    # Right now we only support single frame images,
    # gray scale is a good choice.
    color        := :grays
    img.data
end

@recipe function f(img::AstroImage, wcs::WCSTransform)
    seriestype   := :heatmap
    aspect_ratio := :equal
    color        := :grays
    formatter    := x -> pix2world_formatter(x, wcs)
    xlabel       := labler_x(wcs)
    ylabel       := labler_y(wcs)
    img.data
end

function pix2world_formatter(x, wcs)
    res = round(pix_to_world(wcs, [float(x), float(x)])[1], digits = 2)
    if wcs.cunit[1] == "deg"       # TODO: add symbols for more units
        return string(res)*"°"
    else
        return res[1]
    end
end

function labler_x(wcs)
    if wcs.ctype[1][1:2] == "RA"
        return "Right Ascension"
    elseif wcs.ctype[1][1:4] == "GLON"
        return "Galactic Coordinate"
    elseif wcs.ctype[1][1:4] == "TLON"
        return "ITRS"
    else
        return wcs.radesys
    end
end

function labler_y(wcs)
    if wcs.ctype[2][1:3] == "DEC"
        return "Declination"
    elseif wcs.ctype[2][1:4] == "GLAT"
        return "Galactic Coordinate"
    elseif wcs.ctype[2][1:4] == "TLAT"
        return "ITRS"
    else
        return wcs.radesys
    end
end
