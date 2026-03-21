push!(LOAD_PATH,"../src/")

using Documenter
using BeForData

makedocs(
    sitename = "BeForData.jl",
    format=Documenter.HTML(; size_threshold=500_000, size_threshold_warn=250_000),
    doctest = false,
    authors = "Oliver Lindemann",
    pages = [
        "index.md",
        "examples.md",
        "api.md"
    ],
)

deploydocs(; repo = "github.com/lindemann09/ClusterPermutationTests.jl", push_preview = true)
