module Coverings

#--- Dependencies

import ..Lenny: close!

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

struct Curve{T}
    charts::Vector{Chart{T}}
    status  # TODO: make concrete
end

function Curve(T::DataType)
    charts = Chart{T}[]
    status = 0
    Curve(charts, status)
end

#--- Atlases

struct Atlas{T}
    charts::Vector{Chart{T}}
end

function Atlas(T::DataType)
    charts = Chart{T}[]
    Atlas(charts)
end

#--- Default covering types

struct CoveringOptions{T <: Number}
    dim::Int
    # other parameters
end

function CoveringOptions(T::DataType)
    dim = 1
    CoveringOptions{T}(dim)
end

struct Covering{T <: Number} <: AbstractCovering{T}
    opts::CoveringOptions{T}
    currentcurve::Curve{T}
    atlas::Atlas{T}
end

function Covering(T::DataType)
    opts = CoveringOptions(T)
    currentcurve = Curve(T)
    atlas = Atlas(T)
    Covering(opts, currentcurve, atlas)
end

DefaultCovering(T::DataType) = Covering(T)

close!(prob, covering::Covering) = covering

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
