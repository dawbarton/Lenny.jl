using PkgBenchmark
using JLD2

results = benchmarkpkg(joinpath(@__DIR__, "..", "."))

const resultsfile = joinpath(@__DIR__, "results.jld2")

if isfile(resultsfile)
    @load "$resultsfile" savedresults
    push!(savedresults, results)
    @save "$resultsfile" savedresults
else
    savedresults = [results]
    @save "$resultsfile" savedresults
end
