module Coverings

#--- Dependencies

import ..Lenny: close!
using ..Lenny: add!, AbstractContinuationProblem, ZeroFunction, StateVar
using ..EmbeddedFunctions: ClosedEmbeddedFunctions, dim_u, dim_mu, dim_phi,
    dim_psi, active, active!
import ..EmbeddedFunctions: mu_idx

#--- Exports

# Exported types
export AbstractCovering, Covering

# Exported functions
export DefaultCovering

#--- Base covering type

abstract type AbstractCovering{T <: Number} end

close!(prob, covering::AbstractCovering) = covering

#--- Charts

struct Chart{T}
    u::Vector{T}  # all states
    t::Vector{T}
end

function Chart(T::DataType)
    u = T[]
    t = T[]
    Chart(u, t)
end

#--- Curves

mutable struct Curve{T}
    charts::Vector{Chart{T}}
    currentchart::Chart{T}
    status  # TODO: make concrete
end

function Curve(T::DataType)
    charts = Chart{T}[]
    currentchart = Chart(T)
    status = 0
    Curve(charts, currentchart, status)
end

#--- Atlases

struct Atlas{T}
    charts::Vector{Chart{T}}
end

function Atlas(T::DataType)
    charts = Chart{T}[]
    Atlas(charts)
end

#--- Covering options

struct CoveringOptions{T <: Number}
    dim::Int
    # other parameters
end

function CoveringOptions(T::DataType)
    dim = 1
    CoveringOptions{T}(dim)
end

#--- Covering type

struct Covering{T <: Number, E} <: AbstractCovering{T}
    opts::CoveringOptions{T}
    efuncs::E
    currentcurve::Curve{T}
    atlas::Atlas{T}
end

function Covering(T::DataType)
    opts = CoveringOptions(T)
    efuncs = nothing
    currentcurve = Curve(T)
    atlas = Atlas(T)
    Covering(opts, efuncs, currentcurve, atlas)
end

function Covering(covering::Covering{T}, efuncs::ClosedEmbeddedFunctions{T}) where T
    Covering(covering.opts, efuncs, covering.currentcurve, covering.atlas)
end

DefaultCovering(T::DataType) = Covering(T)

# Some forwards
mu_idx(covering::Covering, μ) = mu_idx(covering.efuncs, μ)
mu_name(covering::Covering, μ) = mu_name(covering.efuncs, μ)

#--- Close the covering

function close!(prob, covering::Covering{T}) where T
    # TODO: this is hard coded to a 1D covering... need to work out the separation between covering and atlas construction
    # Add the projection condition as a closure
    add!(prob, ZeroFunction((res, prob, u) -> projectioncondition!(res, prob, u, covering), StateVar{T}[], 1))
    # Close the efuncs functions
    efuncs = ClosedEmbeddedFunctions(prob.Φ, prob.Ψ)
    # Make the initial continuation variables active
    for (μ, range) in prob.μ_range
        active!(efuncs, μ, true)
    end
    totalvars = dim_u(efuncs) + active(efuncs)
    totalfuncs = dim_phi(efuncs) + dim_psi(efuncs)
    # Check the dimensionality of the problem
    if totalvars != totalfuncs
        throw(DimensionMismatch("Dimensionality mismatch between the number of equations ($totalfuncs) and the number of unknowns ($totalvars)"))
    end
    # Return the covering with efuncs
    prob.covering = Covering(covering, efuncs)
end

function projectioncondition!(
        res::AbstractVector{T},
        prob::AbstractContinuationProblem{T},
        u::AbstractVector{T},
        covering::Covering{T}
        ) where T
    pr = zero(T)
    chart = covering.currentcurve.currentchart
    for i = 1:length(u)
        pr += chart.t[i]*(u[i] - chart.u[i])
    end
    res[1] = pr
end

#--- Finite State Machine to do the covering

function state_init! end
function state_error! end
function state_predict! end
function state_correct! end
function state_flush! end

const fsm_states = (state_init!, state_error!, state_predict!, state_correct!, state_flush!)

# This enables easy indexing into the list of all FSM states; i.e. fsm.allstates[state_init] works
for i = 1:length(fsm_states)
    # This must match the FSM constructor
    state = fsm_states[i]
    let i = i
        Base.to_index(::typeof(state)) = i
    end
end

end # module
