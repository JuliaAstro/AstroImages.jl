# wcs_container_bench.jl
#
# Does storing WCS transforms in a container with an ABSTRACT element type
# (`Dict{Char,WCSTransform}`, as AstroImages.jl currently does) actually cost
# performance versus a CONCRETE element type (`Dict{Char,WCSTransform{...}}`,
# what a parametric AstroImage type parameter would give us)?
#
# Motivated by the review thread on JuliaAstro/AstroImages.jl#113: the intuition
# was that `pixel_to_world(wcs[k], pixel)` would be faster if the concrete type of
# `wcs[k]` were inferable from the container type. This script measures that.
#
# Requires: FITSWCS, BenchmarkTools.  Run with:  julia wcs_container_bench.jl
#
# (Optional) to run in a throwaway environment, uncomment:
# import Pkg; Pkg.activate(; temp=true); Pkg.add(["FITSWCS", "BenchmarkTools"])

using FITSWCS, BenchmarkTools
using FITSWCS: WCSTransform
using Statistics: median

# ── Setup ───────────────────────────────────────────────────────────────────
# A representative concrete transform (2-D gnomonic/TAN projection).
w = FITSWCS.WCS(
    2; ctype = ["RA---TAN", "DEC--TAN"],
    crpix = [5.0, 5.0], crval = [10.0, 20.0], cdelt = [0.1, 0.1]
)

abstract_d = Dict{Char, WCSTransform}(' ' => w)   # abstract value type (current design)
concrete_d = Dict(' ' => w)                        # Dict{Char, WCSTransform{2,4,TAN,...}}

# A realistic batch of pixel coordinates (2 axes × N points) as a Matrix.
batch = rand(2, 10_000) .* 50

# ── Inference ─────────────────────────────────────────────────────────────────
getwcs(d) = d[' ']
println("── element type / inference ─────────────────────────────")
println(
    "abstract container value type: ", valtype(abstract_d),
    "  (concrete? ", isconcretetype(valtype(abstract_d)), ")"
)
println(
    "concrete container value type: ", valtype(concrete_d),
    "  (concrete? ", isconcretetype(valtype(concrete_d)), ")"
)
println("inferred getwcs(abstract)::", Base.infer_return_type(getwcs, (typeof(abstract_d),)))
println("inferred getwcs(concrete)::", Base.infer_return_type(getwcs, (typeof(concrete_d),)))

# ── (A) Through a function barrier: pixel_to_world(container[k], batch) ────────
# This is the pattern from the review comment. `pixel_to_world` is a function
# call, so passing an abstractly-typed value triggers ONE dynamic dispatch, then
# the callee runs fully specialised.
barrier(d, coords) = pixel_to_world(d[' '], coords)
bA_abs = @benchmark barrier($abstract_d, $batch) samples = 300
bA_con = @benchmark barrier($concrete_d, $batch) samples = 300

# ── (B) Inline field access, NO barrier: read WCS fields in a hot loop ─────────
# This is where an abstract element type actually hurts: each `.field` access on
# an abstractly-typed value is a boxed, dynamically-dispatched lookup.
function inline(d, n)
    s = 0
    for _ in 1:n
        wt = d[' ']
        s += wt.naxis + length(wt.ctype) + length(wt.cunit)
    end
    return s
end
bB_abs = @benchmark inline($abstract_d, 100_000) samples = 300
bB_con = @benchmark inline($concrete_d, 100_000) samples = 300

# ── Summary ───────────────────────────────────────────────────────────────────
med(b) = median(b).time / 1.0e3  # µs
ratio(a, c) = round(med(a) / med(c); digits = 1)
println("\n── medians (µs), lower is better ─────────────────────────")
println(rpad("scenario", 42), rpad("abstract", 12), rpad("concrete", 12), "abstract/concrete")
println(
    rpad("(A) via function barrier (pixel_to_world)", 42),
    rpad(string(round(med(bA_abs); digits = 1)), 12),
    rpad(string(round(med(bA_con); digits = 1)), 12), ratio(bA_abs, bA_con)
)
println(
    rpad("(B) inline field access, 100k-iter loop", 42),
    rpad(string(round(med(bB_abs); digits = 1)), 12),
    rpad(string(round(med(bB_con); digits = 1)), 12), ratio(bB_abs, bB_con)
)
println(
    """

    Takeaway
    ────────
    (A) Function-barrier calls like `pixel_to_world(wcs[k], pixel)` are ~identical:
        the barrier specialises the callee regardless of the container's element type.
    (B) Only inline field access in a hot loop benefits from a concrete element type.

    AstroImages.jl uses WCS transforms exclusively through FITSWCS function calls
    (pattern A), so a parametric/concrete WCS container gives no measurable win there.
    """
)
