module Lenny

#--- Dependencies

# maybe look at FastGaussQuadrature.jl

# DiffEqOperators.jl for ideas on how to implement collocation as a lazy object

#--- Exports

export StateVar, ZeroFunction, MonitorFunction, ContinuationProblem

#--- Types

abstract type AbstractContinuationProblem{T <: Number} end

#--- Forward definitions

function close! end

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
    # Callbacks
    for signal in ["close_continuationproblem", "close_nlsolver", "close_linsolver", "close_covering", "close_embedding"]
        addsignal!(callbacks, "before_"*signal)
        addsignal!(callbacks, "after_"*signal)
    end
    # Construct
    ContinuationProblem{T}(Φ, Ψ, callbacks, opts, covering, nlsolver, linsolver, toolboxes)
end

#--- Specialised/closed continuation problem

struct ClosedContinuationProblem{T <: Number,
        F <: ClosedEmbeddedFunctions{T},
        C <: AbstractCovering{T},
        NLS <: AbstractNLSolver{T},
        LS <: AbstractLinSolver{T}} <: AbstractContinuationProblem{T}
    u::Vector{StateVar{T}}
    Φ::Vector{ZeroFunction{T}}
    Ψ::Vector{MonitorFunction{T}}
    callbacks::CallbackSignals
    embedded::F
    covering::C
    nlsolver::NLS
    linsolver::LS
    toolboxes::Vector{AbstractToolbox{T}}
end

#--- Close a continuation problem

function close!(prob::ContinuationProblem{T}) where T
    emitsignal(prob.callbacks, "before_close_continuationproblem", prob)
    for i = 1:length(prob.toolboxes)
       prob.toolboxes[i] = close!(prob, prob.toolboxes[i])
    end
    emitsignal(prob.callbacks, "before_close_linsolver", prob)
    prob.linsolver = close!(prob, ismissing(prob.linsolver) ? DefaultLinSolver(T) : prob.linsolver)
    emitsignal(prob.callbacks, "after_close_linsolver", prob)
    emitsignal(prob.callbacks, "before_close_nlsolver", prob)
    prob.nlsolver = close!(prob, ismissing(prob.nlsolver) ? DefaultNLSolver(T) : prob.nlsolver)
    emitsignal(prob.callbacks, "after_close_nlsolver", prob)
    emitsignal(prob.callbacks, "before_close_covering", prob)
    prob.covering = close!(prob, ismissing(prob.covering) ? DefaultCovering(T) : prob.covering)
    emitsignal(prob.callbacks, "after_close_covering", prob)
    emitsignal(prob.callbacks, "before_close_embedding", prob)
    embedded = ClosedEmbeddedFunctions(prob.Φ, prob.Ψ)
    emitsignal(prob.callbacks, "after_close_embedding", prob)
    newprob = ClosedContinuationProblem(embedded.u, prob.Φ, prob.Ψ, prob.callbacks, embedded, prob.covering, prob.nlsolver, prob.linsolver, prob.toolboxes)
    emitsignal(prob.callbacks, "after_close_continuationproblem", newprob)
    newprob
end


end # module
