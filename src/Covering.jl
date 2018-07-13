module Covering

using ..Callbacks

const FSMState = Any

mutable struct FSM
    run::Bool
    state::FSMState
    next_state::FSMState
    error_state::FSMState
end

function fsm_init()
    FSM(true, state_add_prcond)
end

function fsm_run!(fsm::FSM, prob)
    while fsm.run
        # This will be dynamic dispatch but it's unavoidable as far as I can
        # tell since the route through the state machine is unknown a priori
        fsm_step!(fsm, fsm.state, prob)
    end
end

function fsm_step!(fsm::FSM, state::FSMState, prob)
    # At this point the compiler will specialise on state and so everything
    # below should be static dispatch
    emit!(prob, Before(state))
    state(fsm, prob)
    emit!(prob, After(state))
end



end # module
