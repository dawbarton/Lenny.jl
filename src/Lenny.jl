module Lenny

#--- Dependencies

# maybe look at FastGaussQuadrature.jl

#--- Exports

export StateVar, ZeroFunction, MonitorFunction

#--- Types

abstract type AbstractContinuationProblem{T <: Number} end

#--- Includes

include("EmbeddedFunctions.jl")
using .EmbeddedFunctions

include("Callbacks.jl")
using .Callbacks

include("FSMs.jl")
using .FSMs

include("Covering.jl")
using .Covering

include("Toolboxes.jl")
using .Toolboxes

include("Solvers.jl")
using .Solvers

#--- Types

mutable struct ContinuationProblem{T <: Number} <: AbstractContinuationProblem{T}
    u::Vector{StateVar{T}}
    Φ::Vector{ZeroFunction{T}}
    Ψ::Vector{MonitorFunction{T}}
    callbacks::CallbackSignals
    covering::AbstractCovering{T}
    solver::AbstractSolver{T}
    toolboxes::Vector{AbstractToolbox{T}}
end

function ContinuationProblem(T::DataType=Float64)
    u = Vector{StateVar{T}}()
    Φ = Vector{ZeroFunction{T}}()
    Ψ = Vector{MonitorFunction{T}}()
    callbacks = CallbackSignals()
    covering = DefaultCovering(T)
    solver = DefaultSolver(T)
    toolboxes = Vector{AbstractToolbox{T}}()
    ContinuationProblem{T}(u, Φ, Ψ, callbacks, covering, solver, toolboxes)
end

end # module
