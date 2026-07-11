using AstroImages:
    Percent, Zscale, clampednormedview, composecolors, imview, load, render, wcs, refdims, Pol, At, _float, _loadhdu,
    header, shareheader, Centered, dims, name, Comment,
    # Stretches
    sqrtstretch, asinhstretch, powerdiststretch, logstretch, powstretch, squarestretch, sinhstretch

using FITSFiles: fits, HDU, Card
using FITSFiles: Primary, Image, Bintable

using ImageBase: Gray, RGBA, Normed, N0f8, N0f16, N0f32, N0f64

using FITSWCS: pixel_to_world, world_to_pixel

@testset "Conversion to float and fixed-point" begin
    @testset "Float" begin
        for T in (Float16, Float32, Float64)
            @test _float(T(-9.8)) === T(-9.8)
            @test _float(T(12.3)) === T(12.3)
        end
    end
    @testset "Integers" begin
        for (UIT, SIT) in (
                (UInt8, Int8),
                (UInt16, Int16),
                (UInt32, Int32),
                (UInt64, Int64),
            )
            N = sizeof(UIT) * 8
            NT = Normed{UIT, N}
            maxint = UIT(big(2)^(N - 1))
            @test _float(typemin(UIT)) === _float(typemin(SIT)) === NT(0)
            @test _float(UIT(85)) === reinterpret(NT, UIT(85))
            @test _float(SIT(-85)) === _float(UIT(-85 + big(maxint)))
            @test _float(SIT(115)) === _float(UIT(115) + maxint)
            @test _float(typemax(UIT)) === _float(typemax(SIT)) === NT(1)
        end
    end
end

@testset "FITS and images" begin
    fname = tempname() * ".fits"
    # Standard FITS BITPIX element types. FITSFiles does not (yet) write the
    # non-native integer types (Int8, UInt16, UInt32) that FITSIO supported via
    # BSCALE/BZERO scaling.
    for T in [
            UInt8, Int16, Int32, Int64,
            Float32, Float64,
        ]
        data = reshape(T[1:100;], 5, 20)
        write(fname, HDU[HDU(Primary, data)])
        @test load(fname, 1) == data
        @test load(fname, (1, 1)) == (data, data)
        img = AstroImage(fname)
        rendered_img = imview(img)
        @test eltype(rendered_img) <: RGBA
    end
    rm(fname, force = true)
end

@testset "default handler" begin
    fname = tempname() * ".fits"
    @testset "less dimensions than 2" begin
        data = rand(2)
        write(fname, HDU[HDU(Primary, data)])
        @test ndims(AstroImage(fname)) == 1
    end

    @testset "no ImageHDU" begin
        # A file whose only HDUs are an empty primary and a binary table.
        write(
            fname, HDU[
                HDU(Primary, missing),
                HDU(Bintable, (col1 = Int32[1:20;], col2 = ones(Bool, 20))),
            ]
        )
        hdus = fits(fname)
        @test_throws Exception AstroImage(hdus)
    end

    @testset "Opening AstroImage in different ways" begin
        data = rand(2, 2)
        write(fname, HDU[HDU(Primary, data)])
        hdus = fits(fname)
        header = convert(Vector{Card}, hdus[1].cards)
        @test AstroImage(fname, 1) isa AstroImage
        @test AstroImage(hdus, 1) isa AstroImage
        @test AstroImage(data, header) isa AstroImage
    end

    @testset "Image HDU is not at 1st position" begin
        # Empty primary, then a binary table, then the image at HDU 3.
        write(
            fname, HDU[
                HDU(Primary, missing),
                HDU(Bintable, (col1 = Int32[1:20;], col2 = ones(Bool, 20))),
                HDU(Image, rand(2, 2)),
            ]
        )

        @test @test_logs (:info, "Image was loaded from HDU 3") AstroImage(fname) isa AstroImage
    end

    @testset "empty/dataless HDU" begin
        # A dataless HDU (e.g. an empty primary carrying only header cards) should
        # load as an empty AstroImage wrapping those headers, not throw. Its
        # placeholder data is 0-dimensional, so the blank WCS must still be built
        # with a valid (>= 1) axis count.
        write(fname, HDU[HDU(Primary, missing), HDU(Image, rand(2, 2))])
        hdus = fits(fname)
        empty_img = _loadhdu(hdus[1])
        @test empty_img isa AstroImage
        @test ndims(empty_img) == 0
        @test wcs(empty_img, ' ').naxis == 1
    end
    rm(fname, force = true)
end

@testset "Utility functions" begin
    @test size(AstroImage(rand(10, 10))) == (10, 10)
    @test length(AstroImage(rand(10, 10))) == 100
end

@testset "constructor & accessor variants" begin
    data = reshape(Float32[1:20;], 4, 5)

    # `header` on a plain array returns an empty header.
    @test isempty(header(data))

    # `Centered()` dim values are replaced with an automatic range centered on 0.
    imgc = AstroImage(data, (X = Centered(), Y = Centered()))
    @test collect(dims(imgc)[1]) == [-1.5, -0.5, 0.5, 1.5]

    # `dims` given as a plain tuple of lookup values (neither a NamedTuple nor
    # Dimensions) are wrapped with the default X, Y, … names.
    imgt = AstroImage(data, (1:4, 1:5))
    @test map(name, dims(imgt)) == (:X, :Y)

    # `shareheader` between two AstroImages carries the header across.
    img1 = AstroImage(data)
    img1["FOO"] = 42
    shared = shareheader(img1, AstroImage(data .* 2))
    @test shared isa AstroImage
    @test shared["FOO"] == 42

    # Re-setting an existing header key updates it in place (rather than pushing a
    # duplicate card) and preserves any existing comment.
    img1["FOO", Comment] = "the answer"
    img1["FOO"] = 7
    @test img1["FOO"] == 7
    @test count(c -> uppercase(c.key) == "FOO", header(img1)) == 1
    @test img1["FOO", Comment] == "the answer"

    # Setting a WCS header keyword marks the cached WCS as stale so it is rebuilt.
    imgw = AstroImage(data)
    wcs(imgw)  # force the (lazy) WCS to build, clearing the stale flag
    @test !getfield(imgw, :wcs_stale)[]
    imgw["CRVAL1"] = 1.5
    @test getfield(imgw, :wcs_stale)[]
end

@testset "multi wcs AstroImage" begin
    fname = tempname() * ".fits"
    inhdr = Card[
        Card("FLTKEY", 1.0, "floating point keyword"),
        Card("INTKEY", 1, ""),
        Card("BOOLKEY", true, "boolean keyword"),
        Card("STRKEY", "string value", "string value"),
        Card("COMMENT", "this is a comment"),
        Card("HISTORY", "this is a history"),

        Card("CRVAL1A", 0.5), Card("CRVAL2A", 89.5),
        Card("CRPIX1A", 1), Card("CRPIX2A", 1),
        Card("CDELT1A", 1), Card("CDELT2A", -1),
        Card("CTYPE1A", "RA---TAN", "Terrestrial East Longitude"),
        Card("CTYPE2A", "DEC--TAN", "Terrestrial North Latitude"),
        Card("CUNIT1A", "deg"), Card("CUNIT2A", "deg"),

        Card("CRVAL1B", 0.5), Card("CRVAL2B", 89.5),
        Card("CRPIX1B", 1), Card("CRPIX2B", 1),
        Card("CDELT1B", 1), Card("CDELT2B", -1),
        Card("CTYPE1B", "RA---TAN", "Terrestrial East Longitude"),
        Card("CTYPE2B", "DEC--TAN", "Terrestrial North Latitude"),
        Card("CUNIT1B", "deg"), Card("CUNIT2B", "deg"),
    ]

    indata = reshape(Float32[1:100;], 5, 20)
    write(fname, HDU[HDU(Primary, indata, inhdr)])

    # Sample pixels for a pixel -> world -> pixel round-trip check.
    testpix = ([1.0, 1.0], [2.5, 10.0], [5.0, 20.0])

    img = AstroImage(fname)
    hdus = fits(fname)
    @test length(wcs(img)) == 2
    for n in ('A', 'B')
        w = wcs(img, n)
        @test w.ctype == ["RA---TAN", "DEC--TAN"]
        for p in testpix
            @test world_to_pixel(w, pixel_to_world(w, p)) ≈ p rtol = 1.0e-8
        end
    end

    img = AstroImage(hdus)
    @test length(wcs(img)) == 2
    for n in ('A', 'B')
        w = wcs(img, n)
        @test w.ctype == ["RA---TAN", "DEC--TAN"]
        for p in testpix
            @test world_to_pixel(w, pixel_to_world(w, p)) ≈ p rtol = 1.0e-8
        end
    end

    # The round-trips above call the raw-`WCSTransform` methods directly. Here we
    # exercise the dimension-aware `AstroImage` methods in `src/wcs.jl`, which
    # scale slice-local coordinates to/from the parent pixel frame.
    @testset "img-level transforms (wcsn = $n)" for n in ('A', 'B')
        w = wcs(img, n)
        for p in testpix
            # Default (`parent = false`) path: for a non-sliced image the dims are
            # 1-based unit ranges, so it reduces to the raw transform and round-trips.
            worldf = pixel_to_world(img, p; wcsn = n)
            @test worldf ≈ pixel_to_world(w, p) rtol = 1.0e-8
            @test world_to_pixel(img, worldf; wcsn = n) ≈ p rtol = 1.0e-8
            # `parent = true` treats inputs as parent-frame coordinates, applying
            # only the 1→0-based shift before the raw transform (no dim scaling).
            worldp = pixel_to_world(img, p; wcsn = n, parent = true)
            @test worldp ≈ pixel_to_world(w, p .- 1) rtol = 1.0e-8
            @test world_to_pixel(img, worldp; wcsn = n, parent = true) ≈
                world_to_pixel(w, worldp) rtol = 1.0e-8
        end

        # Integer pixel input is accepted (converted to Float64 internally).
        @test pixel_to_world(img, [1, 1]; wcsn = n) ≈
            pixel_to_world(img, [1.0, 1.0]; wcsn = n) rtol = 1.0e-8

        # `all = true` returns coordinates for every WCS axis; here naxis equals
        # the number of dims, so it matches the filtered result.
        @test pixel_to_world(img, [1.0, 1.0]; wcsn = n, all = true) ≈
            pixel_to_world(img, [1.0, 1.0]; wcsn = n) rtol = 1.0e-8

        # Batched (matrix) transform: each column is one coordinate.
        pixmat = reduce(hcat, testpix)
        worldmat = pixel_to_world(img, pixmat; wcsn = n)
        @test size(worldmat) == size(pixmat)
        for (k, p) in enumerate(testpix)
            @test worldmat[:, k] ≈ pixel_to_world(img, p; wcsn = n) rtol = 1.0e-8
        end
        @test world_to_pixel(img, worldmat; wcsn = n) ≈ pixmat rtol = 1.0e-8
    end
end

@testset "sliced cube world coordinates" begin
    fname = tempname() * ".fits"
    hdr = Card[
        Card("CRVAL1", 0.5), Card("CRVAL2", 89.5), Card("CRVAL3", 1.0e9),
        Card("CRPIX1", 1), Card("CRPIX2", 1), Card("CRPIX3", 1),
        Card("CDELT1", 1), Card("CDELT2", -1), Card("CDELT3", 1.0e6),
        Card("CTYPE1", "RA---TAN"), Card("CTYPE2", "DEC--TAN"), Card("CTYPE3", "FREQ"),
        Card("CUNIT1", "deg"), Card("CUNIT2", "deg"), Card("CUNIT3", "Hz"),
    ]
    cube_data = reshape(Float32[1:(5 * 6 * 4);], 5, 6, 4)
    write(fname, HDU[HDU(Primary, cube_data, hdr)])

    cube = AstroImage(fname)
    @test ndims(cube) == 3
    @test isempty(refdims(cube))

    # Dropping the 3rd (spectral) axis moves it into `refdims`; the transform
    # wrappers must then scatter the frozen axis into its WCS slot. This is the
    # only path that exercises the `refdims` loops in `src/wcs.jl`.
    sl = cube[:, :, 2]
    @test ndims(sl) == 2
    @test length(refdims(sl)) == 1

    testpix = ([1.0, 1.0], [2.0, 3.0], [5.0, 6.0])
    for p in testpix
        world = pixel_to_world(sl, p)      # filtered to the two kept dims
        @test length(world) == 2
        back = world_to_pixel(sl, world)   # returns all WCS axes
        @test back[1:2] ≈ p rtol = 1.0e-8  # kept dims round-trip
    end

    # `all = true` additionally returns the frozen spectral world coordinate.
    @test length(pixel_to_world(sl, [1.0, 1.0]; all = true)) == 3
end

@testset "polarization (symbol) axis slicing" begin
    fname = tempname() * ".fits"
    hdr = Card[
        Card("CRVAL1", 0.5), Card("CRVAL2", 89.5), Card("CRVAL3", 1.0),
        Card("CRPIX1", 1), Card("CRPIX2", 1), Card("CRPIX3", 1),
        Card("CDELT1", 1), Card("CDELT2", -1), Card("CDELT3", 1),
        Card("CTYPE1", "RA---TAN"), Card("CTYPE2", "DEC--TAN"), Card("CTYPE3", "STOKES"),
        Card("CUNIT1", "deg"), Card("CUNIT2", "deg"),
    ]
    data = reshape(Float32[1:(5 * 6 * 4);], 5, 6, 4)
    write(fname, HDU[HDU(Primary, data, hdr)])

    # A categorical polarization axis: its lookup values are Symbols, not numbers.
    cube = AstroImage(fname, 1, (X = 1:5, Y = 1:6, Pol = [:I, :Q, :U, :V]))

    # Slicing to a single polarization drops a *non-numeric* refdim, exercising the
    # symbol-lookup branches of the transform wrappers, which map the symbol back
    # to its parent pixel index.
    sl = cube[Pol = At(:Q)]
    @test ndims(sl) == 2
    @test length(refdims(sl)) == 1
    @test eltype(refdims(sl)[1]) == Symbol

    for p in ([1.0, 1.0], [2.0, 3.0], [5.0, 6.0])
        world = pixel_to_world(sl, p)
        back = world_to_pixel(sl, world)
        @test back[1:2] ≈ p rtol = 1.0e-8
    end

    # Integer world input is accepted (converted to Float64 internally).
    @test world_to_pixel(sl, [1, 89]) ≈ world_to_pixel(sl, [1.0, 89.0]) rtol = 1.0e-8
end

##
@testset "imview" begin

    arr1 = collect(permutedims(reshape(1:9, 3, 3)))
    img = AstroImage(arr1)

    @test imview(arr1) == imview(img)

    ## Test view functionality
    ivimg = imview(img, clims = (0, 9))
    img[1] = 0
    @test imview(img, clims = (0, 9)) == ivimg # Should have updated
    img[1] = 1

    img_rendered_1 = imview(img, clims = (1, 9), stretch = identity, contrast = 1, bias = 0.5, cmap = nothing)

    # Image Orientation
    @test CartesianIndex(3, 1) == argmin(Gray.(img_rendered_1))
    @test CartesianIndex(1, 3) == argmax(Gray.(img_rendered_1))

    # Rendering Basics
    @test allunique(img_rendered_1)
    # It is intended that the rendered image is flipped vs it's data
    @test img_rendered_1[3, 1] == RGBA(0, 0, 0, 1)
    @test img_rendered_1[1, 3] == RGBA(1, 1, 1, 1)
    @test all(p -> p.r == p.g == p.b && p.alpha == 1, img_rendered_1)

    # Limits
    img_rendered_2 = imview(img, clims = (3, 7), stretch = identity, contrast = 1, bias = 0.5, cmap = nothing)
    @test length(unique(img_rendered_2)) == 5
    @test count(==(RGBA(0, 0, 0, 1)), img_rendered_2) == 3
    @test count(==(RGBA(1, 1, 1, 1)), img_rendered_2) == 3

    # Calculated limits
    @test img_rendered_1 == imview(img, clims = extrema, stretch = identity, contrast = 1, bias = 0.5, cmap = nothing)
    img_rendered_3 = imview(img, clims = Zscale(), stretch = identity, contrast = 1, bias = 0.5, cmap = nothing)
    img_rendered_4 = imview(img, clims = Percent(100), stretch = identity, contrast = 1, bias = 0.5, cmap = nothing)
    @test img_rendered_1 == img_rendered_3
    @test img_rendered_1 == img_rendered_4

    # Stretching
    for stretchfunc in (sqrtstretch, asinhstretch, powerdiststretch, logstretch, powstretch, squarestretch, sinhstretch)
        img_rendered_5 = imview(arr1, clims = (1, 9), stretch = stretchfunc, contrast = 1, bias = 0.5, cmap = nothing)
        @test extrema(Gray.(img_rendered_5)) == (0, 1)
        manual_stretch = stretchfunc.(clampednormedview(arr1, (1, 9)))
        @test Gray.(img_rendered_5) ≈
            N0f8.(
            (manual_stretch .- minimum(manual_stretch)) ./
                (maximum(manual_stretch) - minimum(manual_stretch))
        )'[end:-1:begin, :]
    end

    # Contrast/Bias
    @test Gray.(imview(img, clims = extrema, stretch = identity, contrast = 1, bias = 0.6, cmap = nothing)) ==
        N0f8.(clamp.(N0f8.(Gray.(img_rendered_1)) .- 0.1, false, true))

    img_rendered_5 = imview(arr1, clims = (1, 9), stretch = sqrtstretch, contrast = 0.5, bias = 0.5, cmap = nothing)

    # Missing/NaN
    for m in (NaN, missing)
        arr2 = [
            1 2 3
            4 m 6
            7 8 9
        ]
        @test imview(arr2) == imview(AstroImage(arr2))
        @test imview(arr2)[2, 2].alpha == 0
        @test 8 == count(img_rendered_1 .== imview(arr2, clims = (1, 9), stretch = identity, contrast = 1, bias = 0.5, cmap = nothing))
    end

    img_rendered_6 = imview([1, 2, NaN, missing, -Inf, Inf], clims = extrema)
    img_rendered_6b = imview([1, 2], clims = extrema)

    @test img_rendered_6[1] == img_rendered_6b[1]
    @test img_rendered_6[2] == img_rendered_6b[2]
    @test img_rendered_6[1].alpha == 1
    @test img_rendered_6[2].alpha == 1
    @test img_rendered_6[3].alpha == 0
    @test img_rendered_6[4].alpha == 0
    @test img_rendered_6[5] == RGBA(0, 0, 0, 1)
    @test img_rendered_6[6] == RGBA(1, 1, 1, 1)
end


###


##
@testset "bugs" begin

    arr1 = permutedims(reshape(1:9, 3, 3))
    img = AstroImage(arr1)

    # https://github.com/JuliaAstro/AstroImages.jl/issues/32
    @test reverse(img, dims = 1) == reverse(arr1, dims = 1)
    @test reverse(img) == reverse(arr1)


    # https://github.com/JuliaAstro/AstroImages.jl/issues/33
    dark = AstroImage(zeros(1, 10, 10))
    raw = AstroImage(ones(5, 10, 10))
    @test size(dark .- raw) == size(raw)

end
##

##

# @testset "multi file AstroImage" begin
#     fname1 = tempname() * ".fits"
#     f = FITS(fname1, "w")
#     inhdr = FITSHeader(["CTYPE1", "CTYPE2", "RADESYS", "FLTKEY", "INTKEY", "BOOLKEY", "STRKEY", "COMMENT",
#                         "HISTORY"],
#                     ["RA---TAN", "DEC--TAN", "UNK", 1.0, 1, true, "string value", nothing, nothing],
#                     ["",
#                         "",
#                         "",
#                         "floating point keyword",
#                         "",
#                         "boolean keyword",
#                         "string value",
#                         "this is a comment",
#                         "this is a history"])

#     indata1 = reshape(Int[1:100;], 5, 20)
#     write(f, indata1; header=inhdr)
#     close(f)

#     fname2 = tempname() * ".fits"
#     f = FITS(fname2, "w")
#     indata2 = reshape(Int[1:100;], 5, 20)
#     write(f, indata2; header=inhdr)
#     close(f)

#     fname3 = tempname() * ".fits"
#     f = FITS(fname3, "w")
#     indata3 = reshape(Int[1:100;], 5, 20)
#     write(f, indata3; header=inhdr)
#     close(f)

#     img = AstroImage((fname1, fname2, fname3))
#     f1 = FITS(fname1)
#     f2 = FITS(fname2)
#     f3 = FITS(fname3)

#     @test length(img.data) == length(img.wcs) == 3
#     @test img.data[1] == indata1
#     @test img.data[2] == indata2
#     @test img.data[3] == indata3
#     @test to_header(img.wcs[1]) == to_header(img.wcs[2]) ==
#         to_header(img.wcs[3]) == to_header(from_header(read_header(f1[1], String))[1])
#     @test eltype(eltype(img.data)) == Int

#     img = AstroImage(Gray, (f1, f2, f3), (1,1,1))
#     @test length(img.data) == length(img.wcs) == 3
#     @test img.data[1] == indata1
#     @test img.data[2] == indata2
#     @test img.data[3] == indata3
#     @test to_header(img.wcs[1]) == to_header(img.wcs[2]) ==
#         to_header(img.wcs[3]) == to_header(from_header(read_header(f1[1], String))[1])
#     @test eltype(eltype(img.data)) == Int
#     close(f1)
#     close(f2)
#     close(f3)
#     rm(fname1, force = true)
#     rm(fname2, force = true)
#     rm(fname3, force = true)
# end

@testset "composecolors" begin
    img1, img2, img3 = eachslice(rand(3, 4, 3); dims = 3)
    img4 = rand(3, 5)
    @test_throws ErrorException("At least one image is required.") composecolors([], ["red", "blue", "green"])
    @test_throws ErrorException("Images must have the same dimensions to compose them.") composecolors([img1, img2, img4], ["red", "blue", "green"])
    @test_throws ErrorException("Please provide a color channel for each image") composecolors([img1, img2, img3], ["red", "blue"])
    @test_throws ErrorException("Please provide a color channel for each image") composecolors([img1, img2], ["red"])
    @test_throws ErrorException("Please provide a color channel for each image") composecolors([img1, img2])
    @test_throws ErrorException("Please provide an image for each color channel") composecolors([img1, img2, img3], ["red", "blue", "green", "maroon"])
    @test_throws ErrorException("Please provide an image for each color channel") composecolors([img1, img2], ["red", "blue", "green"])
    @test_throws ErrorException("Please provide an image for each color channel") composecolors([img1], ["red", "blue"])

    # TODO: Should something like this work?
    # Data description: https://chandra.cfa.harvard.edu/photo/2009/casa/
    # Data source: https://chandra.cfa.harvard.edu/photo/openFITS/casa.html
    # r = load(joinpath("data","casa_0.5-1.5keV.fits"))
    # g = load(joinpath("data","casa_1.5-3.0keV.fits"))
    # b = load(joinpath("data","casa_4.0-6.0keV.fits"))
    # img = composecolors([r, g, b]; contrast = 1.0);
    # img_test = composecolors([r, g, b]; contrast = 2.5);
    # isapprox(red.(img), red.(img2) .* 2.5)
    # <same for other channels>
end
