module Lenny

#--- Embedded problems (i.e., smooth problems)

abstract type EmbeddedProblem{T <: Number} end

#--- Zero problems

struct ZeroProblem{T, F, K <: Tuple}  <: EmbeddedProblem{T}
    ϕ::F  # underlying function ϕ:ℝⁿ→ℝᵐ
    𝕂::K  # dependencies
    u₀::Vector{T}  # initial solution (size n; may change size)
    m::Ref{Int}  # dimension of output (use a Ref to allow mutation)
end

function ZeroProblem(ϕ; deps::Tuple=(), u0::AbstractVector=Float64[], dim::Union{Int, Ref{Int}}=0)
    if dim == 0
        error("Not implemented yet")  # should construct u from deps and u0 and pass to getdim(ϕ, u)
    end
    ZeroProblem(ϕ, deps, u0, dim)
end

#--- Monitor functions

struct MonitorFunction{T, F, K <: Tuple} <: EmbeddedProblem{T}
    ψ::F  # underlying function ψ:ℝⁿ→ℝʳ
    𝕂::K  # dependencies
    u₀::Vector{T}  # initial solution (size n; may change size)
    pnames::Vector{Symbol}  # continuation parameter names (size r; cannot change size)
    active::Vector{Bool}  # whether or not the continuation parameters are active
end

function MonitorFunction(ψ; deps::Tuple=(), u0::AbstractVector=Float64[], pnames::AbstractVector{Symbol}=Symbol[], active::Union{AbstractVector{Bool}, Bool}=Bool[])
    if active isa AbstractVector
        if length(active) != length(pnames)
            throw(ArgumentError("active should either be a scalar Bool or a vector of Bools of the same length as pnames"))
        end
        MonitorFunction(ψ, deps, u0, pnames, active)
    else
        MonitorFunction(ψ, deps, u0, pnames, fill(active, length(pnames)))
    end
end

#--- Continuation variables and parameters

# Variables exported by problem definitions that can be reused
vars(x) = Symbol[]  # by default don't export any variables (generic fallback)
vars(problem::ZeroProblem) = vars(problem.ϕ)
vars(problem::MonitorFunction) = vars(problem.ψ)

# Parameters exported by problem definitions that can be reused
pars(x) = Symbol[]
pars(problem::MonitorFunction) = problem.pnames

end # module
