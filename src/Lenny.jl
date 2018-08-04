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

struct ContinuationProblem{T <: Number, C <: AbstractCovering, S <: AbstractSolver} <: AbstractContinuationProblem{T}
    u::Vector{StateVar{T}}
    Φ::Vector{ZeroFunction{T}}
    Ψ::Vector{MonitorFunction{T}}
    callbacks::CallbackSignals
    covering::C
    solver::S
    toolboxes::Vector{AbstractToolbox}
end

function ContinuationProblem(; T=Float64, covering=DefaultCovering(), solver=DefaultSolver())
    u = Vector{StateVar{T}}()
    Φ = Vector{ZeroFunction{T}}()
    Ψ = Vector{MonitorFunction{T}}()
    callbacks = CallbackSignals()
    toolboxes = Vector{AbstractToolbox}()
    ContinuationProblem{T}(u, Φ, Ψ, callbacks, covering, solver, toolboxes)
end

end # module
