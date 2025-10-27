using AstroImages:
    AstroImage, Percent, Zscale, clampednormedview, composecolors, imview, load, render, wcs, _float,
    # Stretches
    sqrtstretch, asinhstretch, powerdiststretch, logstretch, powstretch, squarestretch, sinhstretch

using FITSIO: FITS, FITSHeader, read_header

using ImageBase: Gray, RGBA, Normed, N0f8

using WCS: to_header, from_header

@testset "Conversion to float and fixed-point" begin
    @testset "Float" begin
        for T in (Float16, Float32, Float64)
            @test _float(T(-9.8)) === T(-9.8)
            @test _float(T(12.3)) === T(12.3)
        end
    end
    @testset "Integers" begin
        for (UIT, SIT) in ((UInt8,  Int8),
                           (UInt16, Int16),
                           (UInt32, Int32),
                           (UInt64, Int64))
            N = sizeof(UIT) * 8
            NT = Normed{UIT, N}
            maxint = UIT(big(2) ^ (N - 1))
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
    for T in [UInt8, Int8, UInt16, Int16, UInt32, Int32, Int64,
              Float32, Float64]
        data = reshape(T[1:100;], 5, 20)
        FITS(fname, "w") do f
            write(f, data)
        end
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
        FITS(fname, "w") do f
            write(f, data)
        end
        @test ndims(AstroImage(fname)) == 1
    end

    @testset "no ImageHDU" begin
        ## Binary table
        indata = Dict{String, Array}()
        i = length(indata) + 1
        indata["col$i"] = [randstring(10) for j=1:20]  # ASCIIString column
        i += 1
        indata["col$i"] = ones(Bool, 20)  # Bool column
        i += 1
        indata["col$i"] = reshape([1:40;], (2, 20))  # vector Int64 column
        i += 1
        indata["col$i"] = [randstring(5) for j=1:2, k=1:20]  # vector ASCIIString col
        indata["vcol"] = [randstring(j) for j=1:20]  # variable length column
        indata["VCOL"] = [collect(1.:j) for j=1.:20.] # variable length

        FITS(fname, "w") do f
            write(f, indata; varcols=["vcol", "VCOL"])
            @test_throws Exception AstroImage(f)
        end
    end

    @testset "Opening AstroImage in different ways" begin
        data = rand(2,2)
        FITS(fname, "w") do f
            write(f, data)
        end
        f = FITS(fname)
        header = read_header(f[1])
        @test AstroImage(fname, 1) isa AstroImage
        @test AstroImage(f, 1) isa AstroImage
        @test AstroImage(data, header) isa AstroImage
        close(f)
    end

    @testset "Image HDU is not at 1st position" begin
        ## Binary table
        indata = Dict{String, Array}()
        i = length(indata) + 1
        indata["col$i"] = [randstring(10) for j=1:20]  # ASCIIString column
        i += 1
        indata["col$i"] = ones(Bool, 20)  # Bool column
        i += 1
        indata["col$i"] = reshape([1:40;], (2, 20))  # vector Int64 column
        i += 1
        indata["col$i"] = [randstring(5) for j=1:2, k=1:20]  # vector ASCIIString col
        indata["vcol"] = [randstring(j) for j=1:20]  # variable length column
        indata["VCOL"] = [collect(1.:j) for j=1.:20.] # variable length

        FITS(fname, "w") do f
            write(f, indata; varcols=["vcol", "VCOL"])
            write(f, rand(2, 2))
        end

        @test @test_logs (:info, "Image was loaded from HDU 3") AstroImage(fname) isa AstroImage
    end
    rm(fname, force = true)
end

@testset "Utility functions" begin
   @test size(AstroImage(rand(10,10))) == (10,10)
   @test length(AstroImage(rand(10,10))) == 100
end

@testset "multi wcs AstroImage" begin
    fname = tempname() * ".fits"
    f = FITS(fname, "w")
    inhdr = FITSHeader([
            "FLTKEY", "INTKEY", "BOOLKEY", "STRKEY", "COMMENT", "HISTORY",
            "CRVAL1a",
            "CRVAL2a",
            "CRPIX1a",
            "CRPIX2a",
            "CDELT1a",
            "CDELT2a",
            "CTYPE1a",
            "CTYPE2a",
            "CUNIT1a",
            "CUNIT2a",

            "CRVAL1b",
            "CRVAL2b",
            "CRPIX1b",
            "CRPIX2b",
            "CDELT1b",
            "CDELT2b",
            "CTYPE1b",
            "CTYPE2b",
            "CUNIT1b",
            "CUNIT2b",
        ],
        [
            1.0, 1, true, "string value", nothing, nothing,
            0.5,
            89.5,
            1,
            1,
            1,
            -1,
            "RA---TAN",
            "DEC--TAN",
            "deg     ",
            "deg     ",

            0.5,
            89.5,
            1,
            1,
            1,
            -1,
            "RA---TAN",
            "DEC--TAN",
            "deg     ",
            "deg     ",
        ],
        [
            "floating point keyword", "", "boolean keyword", "string value", "this is a comment", "this is a history",
            "",
            "",
            "",
            "",
            "",
            "",
            "Terrestrial East Longitude",
            "Terrestrial North Latitude",
            "",
            "",

            "",
            "",
            "",
            "",
            "",
            "",
            "Terrestrial East Longitude",
            "Terrestrial North Latitude",
            "",
            "",
        ])

    indata = reshape(Float32[1:100;], 5, 20)
    write(f, indata; header=inhdr)
    close(f)

    img = AstroImage(fname)
    f = FITS(fname)
    @test length(wcs(img)) == 2
    @test to_header(wcs(img,1)) === to_header(from_header(read_header(f[1], String))[1])
    @test to_header(wcs(img,2)) === to_header(from_header(read_header(f[1], String))[2])

    img = AstroImage(f)
    @test length(wcs(img)) == 2
    @test to_header(wcs(img,1)) === to_header(from_header(read_header(f[1], String))[1])
    @test to_header(wcs(img,2)) === to_header(from_header(read_header(f[1], String))[2])
    close(f)
end

##
@testset "imview" begin

    arr1 = collect(permutedims(reshape(1:9,3,3)))
    img = AstroImage(arr1)

    @test imview(arr1) == imview(img)

    ## Test view functionality
    ivimg = imview(img, clims=(0,9))
    img[1] = 0
    @test imview(img, clims=(0,9)) == ivimg # Should have updated
    img[1] = 1

    img_rendered_1 = imview(img, clims=(1,9), stretch=identity, contrast=1, bias=0.5, cmap=nothing)

    # Image Orientation
    @test CartesianIndex(3,1) == argmin(Gray.(img_rendered_1))
    @test CartesianIndex(1,3) == argmax(Gray.(img_rendered_1))

    # Rendering Basics
    @test allunique(img_rendered_1)
    # It is intended that the rendered image is flipped vs it's data
    @test img_rendered_1[3,1] == RGBA(0,0,0,1)
    @test img_rendered_1[1,3] == RGBA(1,1,1,1)
    @test all(p -> p.r==p.g==p.b && p.alpha==1, img_rendered_1)

    # Limits
    img_rendered_2 = imview(img, clims=(3,7), stretch=identity, contrast=1, bias=0.5, cmap=nothing)
    @test length(unique(img_rendered_2)) == 5
    @test count(==(RGBA(0,0,0,1)), img_rendered_2) == 3
    @test count(==(RGBA(1,1,1,1)), img_rendered_2) == 3

    # Calculated limits
    @test img_rendered_1 == imview(img, clims=extrema, stretch=identity, contrast=1, bias=0.5, cmap=nothing)
    img_rendered_3 = imview(img, clims=Zscale(), stretch=identity, contrast=1, bias=0.5, cmap=nothing)
    img_rendered_4 = imview(img, clims=Percent(100), stretch=identity, contrast=1, bias=0.5, cmap=nothing)
    @test img_rendered_1 == img_rendered_3
    @test img_rendered_1 == img_rendered_4

    # Stretching
    for stretchfunc in (sqrtstretch, asinhstretch, powerdiststretch, logstretch, powstretch, squarestretch, sinhstretch)
        img_rendered_5 = imview(arr1, clims=(1,9), stretch=stretchfunc, contrast=1, bias=0.5, cmap=nothing)
        @test extrema(Gray.(img_rendered_5)) == (0,1)
        manual_stretch = stretchfunc.(clampednormedview(arr1,(1,9)))
        @test Gray.(img_rendered_5) ≈
            N0f8.((manual_stretch.-minimum(manual_stretch)) ./
                (maximum(manual_stretch)-minimum(manual_stretch)))'[end:-1:begin,:]
    end

    # Contrast/Bias
    @test Gray.(imview(img, clims=extrema, stretch=identity, contrast=1, bias=0.6, cmap=nothing)) ==
            N0f8.(clamp.(N0f8.(Gray.(img_rendered_1)) .- 0.1,false,true))

    img_rendered_5 = imview(arr1, clims=(1,9), stretch=sqrtstretch, contrast=0.5, bias=0.5, cmap=nothing)

    # Missing/NaN
    for m in (NaN, missing)
        arr2 = [
            1 2 3
            4 m 6
            7 8 9
        ]
        @test imview(arr2) == imview(AstroImage(arr2))
        @test imview(arr2)[2,2].alpha == 0
        @test 8 == count(img_rendered_1 .== imview(arr2, clims=(1,9), stretch=identity, contrast=1, bias=0.5, cmap=nothing))
    end

    img_rendered_6 = imview([1, 2, NaN, missing, -Inf, Inf], clims=extrema)
    img_rendered_6b = imview([1, 2], clims=extrema)

    @test img_rendered_6[1] == img_rendered_6b[1]
    @test img_rendered_6[2] == img_rendered_6b[2]
    @test img_rendered_6[1].alpha == 1
    @test img_rendered_6[2].alpha == 1
    @test img_rendered_6[3].alpha == 0
    @test img_rendered_6[4].alpha == 0
    @test img_rendered_6[5] == RGBA(0,0,0,1)
    @test img_rendered_6[6] == RGBA(1,1,1,1)
end



###


##
@testset "bugs" begin

    arr1 = permutedims(reshape(1:9,3,3))
    img = AstroImage(arr1)

    # https://github.com/JuliaAstro/AstroImages.jl/issues/32
    @test reverse(img, dims=1) == reverse(arr1,dims=1)
    @test reverse(img) == reverse(arr1)


    # https://github.com/JuliaAstro/AstroImages.jl/issues/33
    dark = AstroImage(zeros(1, 10, 10));
    raw = AstroImage(ones(5, 10, 10));
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

# TODO: Put this into ccd2rgb.jl later?
@testset "ccd2rgb" begin
    img1, img2, img3 = eachslice(rand(3, 4, 3); dims=3)
    img4 = rand(3, 5)
    @test_throws ErrorException("At least one image is required.") composecolors([], ["red", "blue", "green"])
    @test_throws ErrorException("Images must have the same dimensions to compose them.") composecolors([img1, img2, img4], ["red", "blue", "green"])
    @test_throws ErrorException("Please provide a color channel for each image") composecolors([img1, img2, img3], ["red", "blue"])
    @test_throws ErrorException("Please provide a color channel for each image") composecolors([img1, img2], ["red"])
    @test_throws ErrorException("Please provide a color channel for each image") composecolors([img1, img2])
    @test_throws ErrorException("Please provide an image for each color channel") composecolors([img1, img2, img3], ["red", "blue", "green", "maroon"])
    @test_throws ErrorException("Please provide an image for each color channel") composecolors([img1, img2], ["red", "blue", "green"])
    @test_throws ErrorException("Please provide an image for each color channel") composecolors([img1], ["red", "blue"])
end
