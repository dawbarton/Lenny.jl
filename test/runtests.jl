if VERSION < v"0.7.0-beta"
    using Base.Test
else
    using Test
end

using Lenny

const L = Lenny

include("test_EmbeddedFunctions.jl")
include("test_Callbacks.jl")
include("test_FSMs.jl")
