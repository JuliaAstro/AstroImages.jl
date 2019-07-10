@testset "ccd2rgb" begin
    if !isfile(joinpath("data","casa_0.5-1.5keV.fits"))
        mkpath("data")
        download("http://chandra.harvard.edu/photo/2009/casa/fits/casa_0.5-1.5keV.fits", joinpath("data","casa_0.5-1.5keV.fits"))
    end
    if !isfile(joinpath("data","casa_1.5-3.0keV.fits"))
        mkpath("data")
        download("http://chandra.harvard.edu/photo/2009/casa/fits/casa_1.5-3.0keV.fits", joinpath("data","casa_1.5-3.0keV.fits"))
    end
    if !isfile(joinpath("data","casa_4.0-6.0keV.fits"))
        mkpath("data")
        download("http://chandra.harvard.edu/photo/2009/casa/fits/casa_4.0-6.0keV.fits", joinpath("data","casa_4.0-6.0keV.fits"))
    end
    if !isfile(joinpath("data","ccd2rgb.jld"))
        mkpath("data")
        download("https://bintray.com/aquatiko/AstroImages.jl/download_file?file_path=ccd2rgb.jld",joinpath("data","ccd2rgb.jld"))
    end
        
    r = FITS(joinpath("data","casa_0.5-1.5keV.fits"))[1]
    b = FITS(joinpath("data","casa_1.5-3.0keV.fits"))[1]
    g = FITS(joinpath("data","casa_4.0-6.0keV.fits"))[1]
    linear_res = RGB.(ccd2rgb(r, b, g, shape_out = (1000,1000)))
    log_res = RGB.(ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = log))
    
    linear_ans = load(joinpath("data","ccd2rgb.jld"), "linear")
    log_ans = load(joinpath("data","ccd2rgb.jld"), "log")
    
    @test all(isapprox(red.(linear_res), red.(linear_ans), nans = true, atol = 1e-4))
    @test all(isapprox(blue.(linear_res), blue.(linear_ans), nans = true, atol = 1e-4))
    @test all(isapprox(green.(linear_res), green.(linear_ans), nans = true, atol = 1e-4))

    @test all(isapprox(red.(log_res), red.(log_ans), nans = true, atol = 1e-4))
    @test all(isapprox(blue.(log_res), blue.(log_ans), nans = true, atol = 1e-4))
    @test all(isapprox(green.(log_res), green.(log_ans), nans = true, atol = 1e-4))
end
