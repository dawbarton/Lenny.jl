module Callbacks

export CallbackList, checkallowable, addcallback!, getcallbacks

const CallbackName = String

struct CallbackList
    allowable::Vector{CallbackName}
    callbacks::Dict{CallbackName, Vector{Any}}
end

function checkallowable(cblist::CallbackList)
    for key in keys(cblist.callbacks)
        if !(key in cblist.allowable)
            throw(InvalidStateException("Callback does not correspond to a registered signal - $key"))
        end
    end
    true
end

function addcallback!(cblist::CallbackList, name::CallbackName, callback)
    if !(name in keys(cblist.callbacks))
        cblist.callbacks[name] = Vector{Any}()
    end
    if callback in cblist.callbacks[name]
        throw(ArgumentError("Callback has already been added to that signal - $name"))
    end
    push!(cblist.callbacks[name], callback)
    cblist
end

function getcallbacks(cblist::CallbackList, name::CallbackName)
    (cblist[name]...,)
end

end
