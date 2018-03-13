using AstroImages, FITSIO, Images
using Base.Test

import AstroImages: _float

@testset "Conversion to float and fixed-point" begin
    @testset "Float" begin
        for T in (Float16, Float32, Float64)
            @test _float(T(-9.8)) === T(-9.8)
            @test _float(T(12.3)) === T(12.3)
        end
    end
    @testset "Unsigned integers" begin
        for (T, NT) in ((UInt8,  N0f8),
                        (UInt16, N0f16),
                        (UInt32, N0f32),
                        (UInt64, N0f64))
            @test _float(typemin(T)) === NT(0)
            @test _float(T(85)) === reinterpret(NT, T(85))
            @test _float(typemax(T)) === NT(1)
        end
    end
    @testset "Signed integers" begin
        for T in (Int8, Int16, Int32, Int64)
            N = sizeof(T) * 8
            FT = Fixed{T, N-1}
            @test _float(typemin(T)) === FT(-1)
            @test _float(T(-85))     === reinterpret(FT, T(-85))
            @test _float(T(0))       === reinterpret(FT, T(0))
            @test _float(T(115))     === reinterpret(FT, T(115))
            @test _float(typemax(T)) === FT(1 - big(2.0) ^ (1 - N))
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
        @test load(fname) == data
        @test load(fname, (1, 1)) == (data, data)
        img = AstroImage(fname)
        @test img.data == Gray.(_float.(data))
        @test convert(typeof(img.data), img) == img.data
        @test convert(Matrix{Gray}, img)     == img.data
    end
    rm(fname, force=true)

    data = reshape(UInt[1:4;], 2, 2)
    img = AstroImage(Gray.(_float.(data)))
    @test reprmime("image/png", img) == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a,
                                              0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48,
                                              0x44, 0x52, 0x00, 0x00, 0x00, 0x64, 0x00,
                                              0x00, 0x00, 0x64, 0x01, 0x00, 0x00, 0x00,
                                              0x00, 0x58, 0x99, 0xa8, 0xf9, 0x00, 0x00,
                                              0x00, 0x04, 0x67, 0x41, 0x4d, 0x41, 0x00,
                                              0x00, 0xb1, 0x8f, 0x0b, 0xfc, 0x61, 0x05,
                                              0x00, 0x00, 0x00, 0x02, 0x62, 0x4b, 0x47,
                                              0x44, 0x00, 0x01, 0xdd, 0x8a, 0x13, 0xa4,
                                              0x00, 0x00, 0x00, 0x14, 0x49, 0x44, 0x41,
                                              0x54, 0x38, 0xcb, 0x63, 0x60, 0x18, 0x05,
                                              0xa3, 0x60, 0x14, 0x8c, 0x82, 0x51, 0x40,
                                              0x4f, 0x00, 0x00, 0x05, 0x78, 0x00, 0x01,
                                              0x29, 0x71, 0xb9, 0xfc, 0x00, 0x00, 0x00,
                                              0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42,
                                              0x60, 0x82]
end

include("plots.jl")
