module Lenny

#--- Dependencies

# maybe look at FastGaussQuadrature.jl

# DiffEqOperators.jl for ideas on how to implement collocation as a lazy object

#--- Exports

# Exported types
export StateVar, ZeroFunction, MonitorFunction, ContinuationProblem

# Exported functions
export add!

#--- Types

abstract type AbstractContinuationProblem{T <: Number} end

#--- Forward definitions

function close! end
function add! end

#--- Includes

include("EmbeddedFunctions.jl")
using .EmbeddedFunctions

include("Callbacks.jl")
using .Callbacks

include("FSMs.jl")
using .FSMs

include("Coverings.jl")
using .Coverings

include("Toolboxes.jl")
using .Toolboxes

include("Solvers.jl")
using .Solvers

#--- User continuation problem

mutable struct ContinuationProblem{T <: Number} <: AbstractContinuationProblem{T}
    Φ::Vector{ZeroFunction{T}}
    Ψ::Vector{MonitorFunction{T}}
    callbacks::CallbackSignals
    opts::Dict{String, Any}
    covering::Union{Missing, AbstractCovering{T}}
    nlsolver::Union{Missing, AbstractNLSolver{T}}
    linsolver::Union{Missing, AbstractLinSolver{T}}
    toolboxes::Vector{AbstractToolbox{T}}
    μ_range::Vector{Pair{String, Tuple{T, T}}}
    dim::Int
end

function ContinuationProblem(T::DataType=Float64)
    if !(T <: Number)
        throw(ArgumentError("Argument must be a numerical data type (e.g., Float64 or BigFloat)"))
    end
    Φ = Vector{ZeroFunction{T}}()
    Ψ = Vector{MonitorFunction{T}}()
    callbacks = CallbackSignals()
    opts = Dict{String, Any}()
    covering = missing
    nlsolver = missing
    linsolver = missing
    toolboxes = Vector{AbstractToolbox{T}}()
    μ_range = Vector{Pair{String, Tuple{T, T}}}()
    # Callbacks
    for signal in ["close_continuationproblem", "close_nlsolver", "close_linsolver", "close_covering"]
        addsignal!(callbacks, "before_"*signal)
        addsignal!(callbacks, "after_"*signal)
    end
    # Construct
    ContinuationProblem{T}(Φ, Ψ, callbacks, opts, covering, nlsolver, linsolver, toolboxes, μ_range, 1)
end

#--- Helper functions

function add!(prob::ContinuationProblem{T}, ϕ::ZeroFunction{T}) where T
    push!(prob.Φ, ϕ)
    nothing
end

function add!(prob::ContinuationProblem{T}, ψ::MonitorFunction{T}) where T
    push!(prob.Ψ, ψ)
    nothing
end

#--- Specialised/closed continuation problem

struct ClosedContinuationProblem{T <: Number,
        C <: AbstractCovering{T},
        NLS <: AbstractNLSolver{T},
        LS <: AbstractLinSolver{T}} <: AbstractContinuationProblem{T}
    Φ::Vector{ZeroFunction{T}}
    Ψ::Vector{MonitorFunction{T}}
    callbacks::CallbackSignals
    covering::C
    nlsolver::NLS
    linsolver::LS
    toolboxes::Vector{AbstractToolbox{T}}
    μ_range::Vector{Pair{Int, Tuple{T, T}}}
    dim::Int
end

#--- Close a continuation problem

function close!(prob::ContinuationProblem{T}) where T
    emitsignal(prob.callbacks, "before_close_continuationproblem", prob)
    for i = eachindex(prob.toolboxes)
       prob.toolboxes[i] = close!(prob, prob.toolboxes[i])
    end
    emitsignal(prob.callbacks, "before_close_linsolver", prob)
    if ismissing(prob.linsolver)
        prob.linsolver = DefaultLinSolver(T)
    end
    close!(prob, prob.linsolver)
    emitsignal(prob.callbacks, "after_close_linsolver", prob)
    emitsignal(prob.callbacks, "before_close_nlsolver", prob)
    if ismissing(prob.nlsolver)
        prob.nlsolver = DefaultNLSolver(T)
    end
    close!(prob, prob.nlsolver)
    emitsignal(prob.callbacks, "after_close_nlsolver", prob)
    emitsignal(prob.callbacks, "before_close_covering", prob)
    if ismissing(prob.covering)
        prob.covering = DefaultCovering(T, prob.dim)
    end
    close!(prob, prob.covering)
    emitsignal(prob.callbacks, "after_close_covering", prob)
    μ_range = Vector{Pair{Int, Tuple{T, T}}}()
    for (μ, range) in prob.μ_range
        push!(μ_range, mu_idx(prob.covering, μ) => range)
    end
    newprob = ClosedContinuationProblem(prob.Φ, prob.Ψ, prob.callbacks,
        prob.covering, prob.nlsolver, prob.linsolver, prob.toolboxes, μ_range,
        prob.dim)
    emitsignal(prob.callbacks, "after_close_continuationproblem", newprob)
    newprob
end

function continuation!(prob0::ContinuationProblem{T}, μ::Vector{Pair{String, Tuple{T, T}}}) where T
    append!(prob0.μ_range, μ)
    continuation!(prob0)
end

function continuation!(prob0::ContinuationProblem)
    prob = close!(prob0)
end

end # module
