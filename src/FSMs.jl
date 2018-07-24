module FSMs

#--- Exports

# Exported types
export FSM

# Exported functions
export fsm_init!, fsm_run!

#--- Dependencies

using ..Callbacks

#--- States of the finite state machine

struct FSMState{F0 <: Tuple, F, F1 <: Tuple}
    before_func::F0
    func::F
    after_func::F1
end

#--- The finite state machine itself

mutable struct FSM
    run::Bool
    allstates::Vector{FSMState}
    state::FSMState
    next_state::FSMState
    error_state::FSMState
end

"""
    fsm_init!(callbacks::CallbackSignals, states::Tuple)

Initialise a finite state machine using the callbacks and states passed.
"before" and "after" signals will be added to the callbacks object for each
state. The initial state is set to the first element of the tuple.
"""
function fsm_init!(callbacks::CallbackSignals, states::Tuple)
    allstates = Vector{FSMState}()
    for state in states
        func = string(state)
        func_before = func*"_before"
        func_after = func*"_after"
        addsignal!(callbacks, func_before)
        addsignal!(callbacks, func_after)
        before = callbacks[func_before]
        after = callbacks[func_after]
        push!(allstates, FSMState(before, state, after))
    end
    FSM(true, allstates, allstates[1], allstates[2], allstates[2])
end

"""
    fsm_run!(problem)

Execute the finite state machine contained within `problem`.
"""
fsm_run!(problem) = fsm_run!(problem, problem.fsm)

"""
    fsm_run!(problem, fsm::FSM)

Execute the finite state machine `fsm` alongside the specified problem
structure.
"""
function fsm_run!(problem, fsm::FSM)
    while fsm.run
        # This will be dynamic dispatch but it's unavoidable as far as I can
        # tell since the route through the state machine is unknown a priori
        fsm_step!(problem, fsm, fsm.state)
    end
end

"""
    fsm_step!(problem, fsm::FSM, state::FSMState)

Execute the current FSM state, including the callbacks as required. The state
functions are expected to modify `fsm.state` (and optionally
`problem.next_state` and/or `fsm.error_state`) to direct the future evolution of
the state machine.
"""
function fsm_step!(problem, fsm::FSM, state::FSMState)
    # At this point the compiler will specialise on state and so everything
    # below should be static dispatch
    emitsignal(state.before_func, problem)
    state.func(problem, fsm)
    emitsignal(state.after_func, problem)
end

end # module
