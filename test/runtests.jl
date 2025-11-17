using Aqua
using BeForData
using Test

Aqua.test_all(BeForData; ambiguities = false, stale_deps = false)

@testset "BeForData.jl" begin
    # Write your tests here.
end
