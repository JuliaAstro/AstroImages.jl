@testset "ccd2rgb" begin
    if !isfile("data/casa_0.5-1.5keV.fits")
        mkpath("data")
        download("http://chandra.harvard.edu/photo/2009/casa/fits/casa_0.5-1.5keV.fits", "data/casa_0.5-1.5keV.fits")
    end
    if !isfile("data/casa_1.5-3.0keV.fits")
        mkpath("data")
        download("http://chandra.harvard.edu/photo/2009/casa/fits/casa_1.5-3.0keV.fits", "data/casa_1.5-3.0keV.fits")
    end
    if !isfile("data/casa_4.0-6.0keV.fits")
        mkpath("data")
        download("http://chandra.harvard.edu/photo/2009/casa/fits/casa_4.0-6.0keV.fits", "data/casa_4.0-6.0keV.fits")
    end
    if !isfile("data/ccd2rgd.jld")
        mkpath("data")
        download("https://bintray.com/aquatiko/AstroImages.jl/download_file?file_path=ccd2_rgb.jld","data/ccd2rgb.jld")
    end
        
    r = FITS("data/casa_0.5-1.5keV.fits")[1]
    b = FITS("data/casa_1.5-3.0keV.fits")[1]
    g = FITS("data/casa_4.0-6.0keV.fits")[1]
    linear_res = ccd2rgb(r, b, g, shape_out = (1000,1000))
    log_res = ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = x -> log(x))
    sqrt_res = ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = x-> sqrt(x))
    asinh_res = ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = x -> asinh(x))

    @test all(linear_res .=== load("data/ccd2rgb.jld", "linear"))
    @test all(log_res .=== load("data/ccd2rgb.jld", "log"))
    @test all(sqrt_res .=== load("data/ccd2rgb.jld", "sqrt"))
    @test all(asinh_res .=== load("data/ccd2rgb.jld", "asinh"))
end
