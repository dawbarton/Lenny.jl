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

#--- Default covering type

mutable struct CoveringOptions{T <: Number} <: AbstractCovering{T}
    dim::Int
    # other parameters
end

DefaultCovering(T::DataType) = CoveringOptions{T}()

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
