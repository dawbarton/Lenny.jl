module FiniteStateMachines

@inline signalstate(state, prob, signal) = map(tbx -> state(tbx, signal, prob), toolboxes(prob))

"""
    runstate(state, prob)

Run code associated with the state provided. The default fallback is to call
state as a function with prob as an argument. Add specialised methods as desired
to change the defaults.
"""
@noinline function runstate(state, prob)
	signalstate(state, prob, :before)
	result = state(prob)
	signalstate(state, prob, :after)
	return result
end

"""
    runfsm(initialstate, prob)

Run the finite state machine starting with the initialstate.
"""
function runfsm(initialstate, prob)
    state = initialstate
    run = true
    while run
        (run, state) = runstate(state, prob)
    end
end

end # end module
