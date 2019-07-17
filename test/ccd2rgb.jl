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
    asinh_res = RGB.(ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = asinh))
    
    linear_ans = load(joinpath("data","ccd2rgb.jld"), "linear")
    asinh_ans = load(joinpath("data","ccd2rgb.jld"), "asinh")
    
    function check_diff(arr1, arr2)
        diff = 1e-4
        count = 0
        for i in 1 : size(arr1)[1]
            for j in 1 : size(arr1)[2]
                if abs(arr1[i,j] - arr2[i,j]) > diff
                    count+=1
                end
            end
        end
        return iszero(count)
    end

    @test check_diff(red.(linear_res), red.(linear_ans))
    @test check_diff(blue.(linear_res), blue.(linear_ans))
    @test check_diff(green.(linear_res), green.(linear_ans))

    @test check_diff(red.(asinh_res), red.(asinh_ans))
    @test check_diff(blue.(asinh_res), blue.(asinh_ans))
    @test check_diff(green.(asinh_res), green.(asinh_ans))
end
