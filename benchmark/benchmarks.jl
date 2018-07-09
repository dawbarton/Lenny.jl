if VERSION < v"0.7.0-alpha"
    push!(LOAD_PATH, "C:\\Users\\db9052\\OneDrive - University of Bristol\\Research")
end

using BenchmarkTools
using Lenny

const L = Lenny

const SUITE = BenchmarkGroup()

include("benchmark_ConstructedProblem.jl")
