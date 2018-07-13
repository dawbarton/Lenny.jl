module Lenny

using Compat
using NLsolve: nlsolve, converged, OnceDifferentiable

include("EmbeddedProblems.jl")
using .EmbeddedProblems


function solve!(prob::ConstructedProblem, u::AbstractVector)
    res = similar(u)
    df = OnceDifferentiable((res, u) -> evaluate!(res, prob, u), u, res)
    nlsolve(df, u)
end

end # module
