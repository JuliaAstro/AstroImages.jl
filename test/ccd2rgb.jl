function download_dep(orig, dest, hash)
    dest_file = joinpath("data", dest)
    if isfile(dest_file)
        dest_hash = open(dest_file, "r") do f
            bytes2hex(sha256(f))
        end
        if dest_hash == hash
            return nothing
        end
    end
    mkpath("data")
    download(orig, dest_file)
    return nothing
end

@testset "ccd2rgb" begin
    download_dep("http://chandra.harvard.edu/photo/2009/casa/fits/casa_0.5-1.5keV.fits", "casa_0.5-1.5keV.fits",
                "5794b9ebced6b991a3e53888d129a38fbf4309250112be530cb6442be812dea6")
    download_dep("http://chandra.harvard.edu/photo/2009/casa/fits/casa_1.5-3.0keV.fits", "casa_1.5-3.0keV.fits",
                "a48b2502ceb979dfad0d05fd5ec19bf3e197ff2d1d9c604c9340992d1bf7eec9")
    download_dep("http://chandra.harvard.edu/photo/2009/casa/fits/casa_4.0-6.0keV.fits", "casa_4.0-6.0keV.fits",
                "15e90a14515c121c2817e97b255c604ad019c9c2340fda4fb6c5c3da55e1b0c2")
    download_dep("https://bintray.com/aquatiko/AstroImages.jl/download_file?file_path=ccd2rgb_rounded.jld","ccd2rgb_rounded.jld",
                "5191e59e527c3667486c680e92c8f77fcdbed1e82d3230317a514d928092107d")
        
    f(x) = isnan(x) ? RGB.(0.0,0.0,0.0) : x
    r = FITS(joinpath("data","casa_0.5-1.5keV.fits"))[1]
    b = FITS(joinpath("data","casa_1.5-3.0keV.fits"))[1]
    g = FITS(joinpath("data","casa_4.0-6.0keV.fits"))[1]
    linear_res = ccd2rgb(r, b, g, shape_out = (1000,1000))
    asinh_res = ccd2rgb(r, b, g, shape_out = (1000,1000), stretch = asinh)
    linear_res = f.(RGB.(colorview(RGB, round.(red.(linear_res), digits = 8), round.(green.(linear_res), digits = 8), 
                                                round.(blue.(linear_res), digits = 8))))
    asinh_res = f.(RGB.(colorview(RGB, round.(red.(asinh_res), digits = 8), round.(green.(asinh_res), digits = 8), 
                                                round.(blue.(asinh_res), digits = 8))))
                
    linear_ans = f.(load(joinpath("data","ccd2rgb_rounded.jld"), "linear"))
    asinh_ans = f.(load(joinpath("data","ccd2rgb_rounded.jld"), "asinh"))

    @test isapprox(red.(linear_res), red.(linear_ans), nans = true, rtol = 3e-5)
    @test isapprox(blue.(linear_res), blue.(linear_ans), nans = true, rtol = 3e-5)
    @test isapprox(green.(linear_res), green.(linear_ans), nans = true, rtol = 3e-5)

    @test isapprox(red.(asinh_res), red.(asinh_ans), nans = true, rtol = 3e-5)
    @test isapprox(blue.(asinh_res), blue.(asinh_ans), nans = true, rtol = 3e-5)
    @test isapprox(green.(asinh_res), green.(asinh_ans), nans = true, rtol = 3e-5)

    @testset "AstroImage using ccd2rgb and properties" begin
        img = AstroImage(RGB, (joinpath("data","casa_0.5-1.5keV.fits"), joinpath("data","casa_1.5-3.0keV.fits"),
                                joinpath("data","casa_4.0-6.0keV.fits")))
        
        @test RGB.(img.property.rgb_image) isa Array{RGB{Float64},2}
        @test img.property.brightness == 0.0
        @test img.property.contrast == 1.0
        @test img.property.label == []
        
        test_img = deepcopy(img)
        set_brightness!(img, 1.5)
        @test img.property.brightness == 1.5
        @test isapprox(red.(img.property.rgb_image), red.(test_img.property.rgb_image) .+ 1.5, nans = true)
        @test isapprox(green.(img.property.rgb_image), green.(test_img.property.rgb_image) .+ 1.5, nans = true)
        @test isapprox(blue.(img.property.rgb_image), blue.(test_img.property.rgb_image) .+ 1.5, nans = true)
        set_brightness!(test_img, 1.5)

        set_contrast!(img, 2.5)
        @test img.property.contrast == 2.5
        @test isapprox(red.(img.property.rgb_image), red.(test_img.property.rgb_image) .* 2.5, nans = true)
        @test isapprox(green.(img.property.rgb_image), green.(test_img.property.rgb_image) .* 2.5, nans = true)
        @test isapprox(blue.(img.property.rgb_image), blue.(test_img.property.rgb_image) .* 2.5, nans = true)
        set_contrast!(test_img, 2.5)

        add_label!(img, 12, 13, "This is an important coordinate")
        add_label!(img, 13, 11, "This a random coordinate")
        @test img.property.label[1] == ((12,13), "This is an important coordinate")
        @test img.property.label[2] == ((13,11), "This a random coordinate")

        @info "Running..."
        reset!(img)
        @test img.property.contrast == 1.0
        @test img.property.brightness == 0.0
        @test img.property.label == []
        ans = ccd2rgb(r, b, g)
        @test isapprox(red.(img.property.rgb_image), red.(ans), nans = true)
        @test isapprox(green.(img.property.rgb_image), green.(ans), nans = true)
        @test isapprox(blue.(img.property.rgb_image), blue.(ans), nans = true)
        

        img = AstroImage(joinpath("data","casa_0.5-1.5keV.fits"))
        @test_throws DomainError set_brightness!(img, 1.2)
        @test_throws DomainError set_contrast!(img, 1.2)
    end
end
