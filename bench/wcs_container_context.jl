# wcs_container_context.jl
#
# Companion to wcs_container_bench.jl. That microbenchmark shows a CONCRETE WCS
# container can be ~40x faster than an ABSTRACT one for *inline field access*.
# Taken alone it makes the parametric AstroImage look strictly better. This script
# puts the question back in context and shows why AstroImages.jl keeps the abstract
# `Dict{Char,WCSTransform}` container. Run it on BOTH branches and compare:
#
#   git checkout fitswcs            && julia --project=<env> bench/wcs_container_context.jl
#   git checkout fitswcs-parametric && julia --project=<env> bench/wcs_container_context.jl
#
# Requires: AstroImages (dev'd), BenchmarkTools.

using AstroImages, BenchmarkTools
const FITSWCS = AstroImages.FITSWCS
const FITSIO = AstroImages.FITSIO
using AstroImages: wcs, pixel_to_world

data = reshape(Float32[1:10_000;], 100, 100)

# A header carrying a real (TAN) WCS: this is the LAZY path that load()/AstroImage(file)
# takes — the overwhelmingly common way images are created.
hdr = FITSIO.FITSHeader(
    ["WCSAXES", "CTYPE1", "CTYPE2", "CRVAL1", "CRVAL2", "CRPIX1", "CRPIX2", "CDELT1", "CDELT2"],
    Any[2, "RA---TAN", "DEC--TAN", 10.0, 20.0, 50.0, 50.0, 0.01, 0.01],
    fill("", 9),
)
img_lazy = AstroImage(data, hdr)   # WCS resolved lazily from the header
w = FITSWCS.WCS(2; ctype = ["RA---TAN", "DEC--TAN"], crpix = [50.0, 50.0], crval = [10.0, 20.0], cdelt = [0.01, 0.01])
img_expl = AstroImage(data, w)     # WCS supplied explicitly

println("── (1) Reachability: which container type does each construction path store? ──")
println("lazy / from-header image : ", typeof(getfield(img_lazy, :wcs)))
println("explicit-WCS image       : ", typeof(getfield(img_expl, :wcs)))
println(
    """    fitswcs:            both are the invariant Dict{Char,WCSTransform} (abstract).
    fitswcs-parametric: only the EXPLICIT image is concrete. The lazy path — what
                        load() uses — MUST stay abstract (its WCS is parsed and
                        mutated in place on first access), so the concrete-container
                        win is unreachable for the images users actually load."""
)

println("\n── (2) End-to-end API: pixel_to_world(img, batch) (how WCS is actually used) ──")
batch = rand(2, 10_000) .* 90 .+ 5
med(b) = round(median(b).time / 1.0e3; digits = 1)  # µs
b_lazy = @benchmark pixel_to_world($img_lazy, $batch) samples = 100
b_expl = @benchmark pixel_to_world($img_expl, $batch) samples = 100
println("lazy image     : ", med(b_lazy), " µs")
println("explicit image : ", med(b_expl), " µs")
println(
    """    Identical. Every WCS use in AstroImages goes through a FITSWCS function call,
    which is a function barrier: the callee specialises on the concrete type regardless
    of the container's element type. So even the explicit/concrete image gets no
    API-level win — the 40x only exists for inline field access, which this package
    does not do in any hot loop."""
)

println("\n── (3) Cost the microbenchmark ignores: AstroImage type proliferation ──")
projs = (
    FITSWCS.WCS(2; ctype = ["RA---TAN", "DEC--TAN"]),
    FITSWCS.WCS(2; ctype = ["RA---SIN", "DEC--SIN"]),
    FITSWCS.WCS(2; ctype = ["RA---AIT", "DEC--AIT"]),
    FITSWCS.WCS(2; ctype = ["GLON-CAR", "GLAT-CAR"]),
)
imgs = map(p -> AstroImage(data, p), projs)
ndistinct = length(unique(typeof.(imgs)))
println("distinct AstroImage types across 4 WCS projections: ", ndistinct)
println(
    """    fitswcs:            1  (all share Dict{Char,WCSTransform}).
    fitswcs-parametric: one per projection. Because the WCS container is a type
    parameter, every projection yields a distinct AstroImage type, so the ENTIRE
    downstream stack (rebuild, show, arithmetic, DimensionalData interface, plot
    recipes, ...) is specialised and compiled separately per type — more latency,
    more method-table entries, more invalidation surface — to buy a runtime win
    that (parts 1 & 2) never reaches real usage."""
)
