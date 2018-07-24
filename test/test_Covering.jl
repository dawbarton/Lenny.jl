struct MyConstructedProblem{T <: Number} <: L.AbstractConstructedProblem{T}
    callbacks::L.CallbackSignals
    fsm::L.FSM
    output::Vector{T}
end

function state1 end
function state2 end
function state3 end

# This enables easy indexing into the list of all FSM states; i.e. fsm.allstates[state_init] works
const fsm_states = (state1, state2, state3)
for i = 1:length(fsm_states)
    # This must match the FSM constructor immediately below
    state = fsm_states[i]
    let i = i
        Base.to_index(::typeof(state)) = i
    end
end

function state1(problem::MyConstructedProblem, fsm::L.FSM)
    push!(problem.output, 1)
    fsm.state = fsm.allstates[state2]
    fsm.next_state = fsm.allstates[state3]
end

function state2(problem::MyConstructedProblem, fsm::L.FSM)
    push!(problem.output, 2)
    fsm.state = fsm.next_state
end

function state3(problem::MyConstructedProblem, fsm::L.FSM)
    push!(problem.output, 3)
    fsm.run = false
end

function state2_before1(problem)
    push!(problem.output, -1)
end

function state2_before2(problem)
    push!(problem.output, -2)
end

function state2_after(problem)
    push!(problem.output, -3)
end

@testset "Covering" begin

cb = L.CallbackSignals()
L.addcallback!(cb, "state2_before", state2_before1)
L.addcallback!(cb, "state2_before", state2_before2)
L.addcallback!(cb, "state2_after", state2_after)

fsm = L.fsm_init!(cb, fsm_states)

problem = MyConstructedProblem(cb, fsm, Int[])

L.fsm_run!(problem)

@test problem.output == [1, -1, -2, 2, -3, 3]

end
