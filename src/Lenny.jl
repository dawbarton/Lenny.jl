module Lenny

# maybe look at FastGaussQuadrature.jl

using NLsolve: nlsolve, converged, OnceDifferentiable

include("EmbeddedProblems.jl")
using .EmbeddedProblems

include("Callbacks.jl")
using .Callbacks

include("Covering.jl")
using .Covering

struct ContinuationProblem
    p::Vector{Symbol}
    Φ::Vector{Union{ZeroProblem{T}, MonitorFunction{T}}} where {T <: Number}
end

function Base.push!(prob::ContinuationProblem, ϕ::Union{ZeroProblem, MonitorFunction})
    if ϕ in prob.Φ
        throw(ArgumentError("ϕ has already been added to the continuation problem"))
    end
    for k in ϕ.k
        if !(k[1] in prob.Φ)
            push!(prob, k[1])
        end
    end
    if ϕ isa MonitorFunction
        for p in ϕ.p
            if p in prob.p
                throw(ArgumentError("Duplicate continuation parameter - $p"))
            else
                push!(prob.p, p)
            end
        end
    end
    push!(prob.Φ, ϕ)
    prob
end

struct ConstructedProblem{T <: Number, F, G}
    efuncs::ClosedProblem{F, G}
    solutions::Vector{Vector{T}}
end

function solve!(prob::ConstructedProblem, u::AbstractVector)
    res = similar(u)
    df = OnceDifferentiable((res, u) -> evaluate!(res, prob, u), u, res)
    nlsolve(df, u)
end

end # module
