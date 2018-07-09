using PkgBenchmark
using JLD2

results = benchmarkpkg(joinpath(@__DIR__, "..", "."))

const resultsfile = joinpath(@__DIR__, "results.jld2")

if !isdefined(current_module(), :saveresults)
    saveresults = true
end

if saveresults
    if isfile(resultsfile)
        @load "$resultsfile" savedresults
        push!(savedresults, results)
        @save "$resultsfile" savedresults
    else
        savedresults = [results]
        @save "$resultsfile" savedresults
    end
    println("Results saved to disk")
end
