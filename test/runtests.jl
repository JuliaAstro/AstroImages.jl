using AstroImages, FITSIO, Images, Random, Widgets, WCS, JLD

using Test, WCS
using SHA: sha256

import AstroImages: _float, render, _brightness_contrast, brightness_contrast

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
        @test load(fname, 1)[1] == data
        @test load(fname, (1, 1))[1] == (data, data)
        img = AstroImage(fname)
        rendered_img = colorview(img)
        @test iszero(minimum(rendered_img))
    end
    rm(fname, force = true)
end

@testset "Control contrast" begin
    @test @inferred(_brightness_contrast(Gray, ones(Float32, 2, 2), 100, 100)) isa
          Array{Gray{Float32},2}
    Random.seed!(1)
    M = rand(2, 2)
    @test @inferred(_brightness_contrast(Gray, M, 100, 100)) ≈
        Gray.([0.48471895908315565  0.514787046406301;
               0.5280458879184159   0.39525854250610226]) rtol = 1e-12
    @test @inferred(_brightness_contrast(Gray, M, 0,   255)) == Gray.(M)
    @test @inferred(_brightness_contrast(Gray, M, 255,   0)) == Gray.(ones(size(M)))
    @test @inferred(_brightness_contrast(Gray, M,   0,   0)) == Gray.(zeros(size(M)))
    @test brightness_contrast(AstroImage(M)) isa Widgets.Widget{:manipulate,Any}
end

@testset "default handler" begin
    fname = tempname() * ".fits"
    @testset "less dimensions than 2" begin
        data = rand(2)
        FITS(fname, "w") do f
            write(f, data)
        end
        @test_throws ErrorException AstroImage(fname)
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
            @test_throws MethodError AstroImage(f)
        end
    end

    @testset "Opening AstroImage in different ways" begin
        data = rand(2,2)
        wcs = WCSTransform(2;)
        FITS(fname, "w") do f
            write(f, data)
        end
        f = FITS(fname)
        @test AstroImage(fname, 1) isa AstroImage
        @test AstroImage(Gray ,fname, 1) isa AstroImage
        @test AstroImage(Gray, f, 1) isa AstroImage
        @test AstroImage(data, wcs) isa AstroImage
        @test AstroImage((data,data), (wcs,wcs)) isa AstroImage
        @test AstroImage(Gray, data, wcs) isa AstroImage
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
   @test size(AstroImage((rand(10,10), rand(10,10)))) == ((10,10), (10,10))
   @test length(AstroImage((rand(10,10), rand(10,10)))) == 2
end

@testset "multi image AstroImage" begin
    data1 = rand(10,10)
    data2 = rand(10,10)
    fname = tempname() * ".fits"
    FITS(fname, "w") do f
        write(f, data1)
        write(f, data2)
    end

    img = AstroImage(fname, (1,2))
    @test length(img.data) == 2
    @test img.data[1] == data1
    @test img.data[2] == data2

    f = FITS(fname)
    img = AstroImage(Gray, f, (1,2))
    @test length(img.data) == 2
    @test img.data[1] == data1
    @test img.data[2] == data2
    close(f)
end

@testset "multi wcs AstroImage" begin
    fname = tempname() * ".fits"
    f = FITS(fname, "w")
    inhdr = FITSHeader(["CTYPE1", "CTYPE2", "RADESYS", "FLTKEY", "INTKEY", "BOOLKEY", "STRKEY", "COMMENT",
                        "HISTORY"],
                       ["RA---TAN", "DEC--TAN", "UNK", 1.0, 1, true, "string value", nothing, nothing],
                       ["",
                        "",
                        "",
                        "floating point keyword",
                        "",
                        "boolean keyword",
                        "string value",
                        "this is a comment",
                        "this is a history"])

    indata = reshape(Float32[1:100;], 5, 20)
    write(f, indata; header=inhdr)
    write(f, indata; header=inhdr)
    close(f)

    img = AstroImage(fname, (1,2))
    f = FITS(fname)
    @test length(img.wcs) == 2
    @test WCS.to_header(img.wcs[1]) === WCS.to_header(WCS.from_header(read_header(f[1], String))[1])
    @test WCS.to_header(img.wcs[2]) === WCS.to_header(WCS.from_header(read_header(f[2], String))[1])

    img = AstroImage(Gray, f, (1,2))
    @test length(img.wcs) == 2
    @test WCS.to_header(img.wcs[1]) === WCS.to_header(WCS.from_header(read_header(f[1], String))[1])
    @test WCS.to_header(img.wcs[2]) === WCS.to_header(WCS.from_header(read_header(f[2], String))[1])
    close(f)
end

@testset "multi file AstroImage" begin
    fname1 = tempname() * ".fits"
    f = FITS(fname1, "w")
    inhdr = FITSHeader(["CTYPE1", "CTYPE2", "RADESYS", "FLTKEY", "INTKEY", "BOOLKEY", "STRKEY", "COMMENT",
                        "HISTORY"],
                    ["RA---TAN", "DEC--TAN", "UNK", 1.0, 1, true, "string value", nothing, nothing],
                    ["",
                        "",
                        "",
                        "floating point keyword",
                        "",
                        "boolean keyword",
                        "string value",
                        "this is a comment",
                        "this is a history"])

    indata1 = reshape(Int[1:100;], 5, 20)
    write(f, indata1; header=inhdr)
    close(f)

    fname2 = tempname() * ".fits"
    f = FITS(fname2, "w")
    indata2 = reshape(Int[1:100;], 5, 20)
    write(f, indata2; header=inhdr)
    close(f)

    fname3 = tempname() * ".fits"
    f = FITS(fname3, "w")
    indata3 = reshape(Int[1:100;], 5, 20)
    write(f, indata3; header=inhdr)
    close(f)

    img = AstroImage((fname1, fname2, fname3))
    f1 = FITS(fname1)
    f2 = FITS(fname2)
    f3 = FITS(fname3)

    @test length(img.data) == length(img.wcs) == 3
    @test img.data[1] == indata1
    @test img.data[2] == indata2
    @test img.data[3] == indata3
    @test WCS.to_header(img.wcs[1]) == WCS.to_header(img.wcs[2]) == 
        WCS.to_header(img.wcs[3]) == WCS.to_header(WCS.from_header(read_header(f1[1], String))[1])
    @test eltype(eltype(img.data)) == Int

    img = AstroImage(Gray, (f1, f2, f3), (1,1,1))
    @test length(img.data) == length(img.wcs) == 3
    @test img.data[1] == indata1
    @test img.data[2] == indata2
    @test img.data[3] == indata3
    @test WCS.to_header(img.wcs[1]) == WCS.to_header(img.wcs[2]) == 
        WCS.to_header(img.wcs[3]) == WCS.to_header(WCS.from_header(read_header(f1[1], String))[1])
    @test eltype(eltype(img.data)) == Int
    close(f1)
    close(f2)
    close(f3)
    rm(fname1, force = true)
    rm(fname2, force = true)
    rm(fname3, force = true)
end

include("plots.jl")
include("ccd2rgb.jl")
