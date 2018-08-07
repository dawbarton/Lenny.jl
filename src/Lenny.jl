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
    covering::AbstractCovering{T}
    solver::AbstractSolver{T}
    toolboxes::Vector{AbstractToolbox{T}}
end

function ContinuationProblem(T::DataType=Float64)
    if !(T <: Number)
        throw(ArgumentError("Argument must be a numerical data type (e.g., Float64 or BigFloat)"))
    end
    Φ = Vector{ZeroFunction{T}}()
    Ψ = Vector{MonitorFunction{T}}()
    callbacks = CallbackSignals()
    covering = DefaultCovering(T)
    solver = DefaultSolver(T)
    toolboxes = Vector{AbstractToolbox{T}}()
    # Callbacks
    for signal in ["close_continuationproblem", "close_solver", "close_covering", "close_embedding"]
        addsignal!(callbacks, "before_"*signal)
        addsignal!(callbacks, "after_"*signal)
    end
    # Construct
    ContinuationProblem{T}(Φ, Ψ, callbacks, covering, solver, toolboxes)
end

#--- Specialised/closed continuation problem

struct ClosedContinuationProblem{T <: Number,
        F <: ClosedEmbeddedFunctions{T},
        C <: AbstractCovering{T},
        S <: AbstractSolver{T}} <: AbstractContinuationProblem{T}
    u::Vector{StateVar{T}}
    Φ::Vector{ZeroFunction{T}}
    Ψ::Vector{MonitorFunction{T}}
    callbacks::CallbackSignals
    closed::F
    covering::C
    solver::S
    toolboxes::Vector{AbstractToolbox{T}}
end

#--- Close a continuation problem

function close!(prob::ContinuationProblem{T}) where T
    emitsignal(prob.callbacks, "before_close_continuationproblem", prob)
    for i = 1:length(prob.toolboxes)
       prob.toolboxes[i] = close!(prob, prob.toolboxes[i])
    end
    emitsignal(prob.callbacks, "before_close_solver", prob)
    prob.solver = close!(prob, prob.solver)
    emitsignal(prob.callbacks, "after_close_solver", prob)
    emitsignal(prob.callbacks, "before_close_covering", prob)
    prob.covering = close!(prob, prob.covering)
    emitsignal(prob.callbacks, "after_close_covering", prob)
    emitsignal(prob.callbacks, "before_close_embedding", prob)
    closed = ClosedEmbeddedFunctions(prob.Φ, prob.Ψ)
    emitsignal(prob.callbacks, "after_close_embedding", prob)
    newprob = ClosedContinuationProblem(closed.u, prob.Φ, prob.Ψ, prob.callbacks, closed, prob.covering, prob.solver, prob.toolboxes)
    emitsignal(prob.callbacks, "after_close_continuationproblem", newprob)
    newprob
end


end # module
