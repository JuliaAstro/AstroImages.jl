using FITSFiles: Card
using Reproject: reproject

# Galactic WCS header cards shared by the test images
const galcards = Card[
    Card("CTYPE1", "GLON-TAN"), Card("CTYPE2", "GLAT-TAN"),
    Card("CRVAL1", 300.0), Card("CRVAL2", -40.0),
    Card("CRPIX1", 20.5), Card("CRPIX2", 15.5),
    Card("CDELT1", -0.1), Card("CDELT2", 0.1),
    Card("CUNIT1", "deg"), Card("CUNIT2", "deg"),
]

# Values vary linearly with pixel position, which bilinear interpolation reproduces exactly
linear(nx, ny) = [2.0i + 3.0j for i in 1:nx, j in 1:ny]

@testset "reproject" begin
    img = AstroImage(linear(40, 30), [Card("WCSAXES", 2); galcards; Card("BUNIT", "K")])
    cutout = img[10:20, 5:15]

    @testset "onto itself" begin
        out, footprint = reproject(img, img)
        @test out isa AstroImage
        @test all(footprint)
        @test parent(out) ≈ parent(img)
        @test out["BUNIT"] == "K"
    end

    @testset "onto a cutout" begin
        out, footprint = reproject(img, cutout)
        @test dims(out) == dims(cutout)
        @test all(footprint)
        @test parent(out) ≈ parent(cutout)
    end

    @testset "from a cutout" begin
        out, footprint = reproject(cutout, img)
        @test size(out) == size(img)
        # Only the pixels covered by the cutout are filled
        @test count(footprint) == length(cutout)
        @test parent(out)[10:20, 5:15] ≈ parent(cutout)
    end

    @testset "channel of a data cube" begin
        cube = AstroImage(
            cat((k .* linear(40, 30) for k in 1:4)...; dims = 3),
            [
                Card("WCSAXES", 3);
                galcards;
                Card("CTYPE3", "VRAD"); Card("CRVAL3", 0.0); Card("CRPIX3", 1.0);
                Card("CDELT3", 1000.0); Card("CUNIT3", "m/s")
            ],
        )

        out, footprint = reproject(cube[:, :, 3], img)
        @test all(footprint)
        @test parent(out) ≈ 3 .* parent(img)

        out, footprint = reproject(img, cube[10:20, 5:15, 3])
        @test all(footprint)
        @test parent(out) ≈ parent(cutout)

        # A position-velocity slice has no celestial frame to reproject from
        @test_throws ArgumentError reproject(cube[:, 7, :], img)
    end
end
