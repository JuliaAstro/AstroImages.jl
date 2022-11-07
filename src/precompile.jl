
using SnoopPrecompile

@precompile_setup begin
    types = [Float32, Float64, Int, Int8, UInt8, N0f8]
    arrays = [rand(T, 5, 5) for T in types]
    stretches = [
        logstretch,
        powstretch,
        sqrtstretch,
        squarestretch,
        asinhstretch,
        sinhstretch,
        powerdiststretch
    ]
    @precompile_all_calls begin
            for a in arrays
                i = AstroImage(a)
                for stretch in stretches
                    imview(a; stretch)
                    imview(i; stretch)
                end
                parent(i)
                header(i)
                wcs(i,1)
                wcs(i)
                i["h"] = 1
                i["h"] = 1.0
                i["h"] = ""
                i["h"]
                i[:h]
                i[1]
                i[1,1]
                i[[1,1]]
                i[trues(length(i))]
                i[trues(size(i))]
                similar(i)
        end
    end
end
