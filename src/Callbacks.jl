module Callbacks

export CallbackSignals, addsignal!, emitsignal, addcallback!

const CallbackSignal = String
const CallbackList = Vector{Any}

struct CallbackSignals
    allowable::Vector{CallbackSignal}
    callbacks::Dict{CallbackSignal, CallbackList}
end
CallbackSignals() = CallbackSignals(Vector{CallbackSignal}(), Dict{CallbackSignal, CallbackList}())

"""
    isvalid(callbacks::CallbackSignals)

Check to see whether all the callbacks that have been added to the list are
associated with valid identifiers. (Validity is not checked with push! to allow
flexibility in definitions.)
"""
function Base.isvalid(callbacks::CallbackSignals)
    for key in keys(callbacks.callbacks)
        if !(key in callbacks.allowable)
            throw(ErrorException("Callback does not correspond to a registered signal ($key)"))
        end
    end
    true
end

"""
    addcallback!(callbacks::CallbackSignals, signal::CallbackSignal, callback)

Add the callback to `signal`. Existence of the corresponding signal is not
checked (see `isvalid`).
"""
function addcallback!(callbacks::CallbackSignals, signal::CallbackSignal, callback)
    if !(signal in keys(callbacks.callbacks))
        callbacks.callbacks[signal] = Vector{Any}()
    end
    if callback in callbacks.callbacks[signal]
        throw(ArgumentError("Callback has already been added to that signal ($signal)"))
    end
    push!(callbacks.callbacks[signal], callback)
    callbacks
end

"""
    addsignal!(callbacks::CallbackSignals, signal::CallbackSignal)

Add `signal` to the list of allowable signals.
"""
function addsignal!(callbacks::CallbackSignals, signal::CallbackSignal)
    if signal in callbacks.allowable
        throw(ArgumentError("Signal has already been added - $signal"))
    end
    push!(callbacks.allowable, signal)
end

function Base.getindex(callbacks::CallbackSignals, signal::CallbackSignal)
    if signal in callbacks.allowable
        if signal in keys(callbacks.callbacks)
            return (callbacks.callbacks[signal]...,)
        else
            return ()
        end
    else
        throw(ArgumentError("Invalid signal ($signal)"))
    end
end

"""
    emitsignal(callbacks::CallbackSignals, signal::CallbackSignal, args...)

Execute all the added callbacks associated with a particular signal. Pass `args`
through to the callbacks. This method should not be used in fast code paths;
instead call `emitsignal` with the tuple of callback functions directly.
"""
function emitsignal(callbacks::CallbackSignals, signal::CallbackSignal, args...)
    emitsignal(callbacks[signal], args...)
end

"""
    emitsignal(callbacks::Tuple{T₁, T₂, ...}, args...)

Execute all the supplied callbacks, passing through `args`. This function is
implemented to provide a type-stable means of executing callbacks (i.e., a fast
code path).
"""
@generated function emitsignal(callbacks::Tuple, args...)
    f = quote end
    for i in 1:length(callbacks.parameters)
        push!(f.args, :(callbacks[$i](args...)))
    end
    push!(f.args, :nothing)
    f
end

end  # module
