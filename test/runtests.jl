using ParallelTestRunner: runtests, find_tests, parse_args
import AstroImages

const init_code = quote
    using AstroImages
end

args = parse_args(Base.ARGS)
testsuite = find_tests(@__DIR__)

runtests(AstroImages, args; testsuite, init_code)
