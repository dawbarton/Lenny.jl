module Lenny

# maybe look at FastGaussQuadrature.jl

abstract type AbstractClosedProblem{T <: Number} end
abstract type AbstractContinuationProblem{T <: Number} end

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

struct ContinuationProblem{T <: Number, C <: AbstractCovering, S <: AbstractSolver} <: AbstractContinuationProblem{T}
    u::Vector{StateVar{T}}
    Φ::Vector{ZeroFunction{T}}
    Ψ::Vector{MonitorFunction{T}}
    callbacks::CallbackSignals
    covering::C
    solver::S
    toolboxes::Vector{AbstractToolbox}
end


end # module
