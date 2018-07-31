module EmbeddedFunctions

#--- Dependencies

import Base: resize!

#--- State variables

struct StateVar{T <: Number}
    name::String  # name of the state variable
    u::Vector{T}  # initial state (mutable)
end

#--- Zero functions (otherwise known as zero problems)

struct ZeroFunction{T <: Number, F}
    f::F  # underlying function
    u::Vector{StateVar{T}}  # underlying state variables
    m::Base.RefValue{Int}  # number of output values
end
ZeroFunction(f, u, m::Int) = ZeroFunction(f, u, Ref(m))

#--- Monitor functions

struct MonitorFunction{T <: Number, F}
    f::F  #underlying function
    u::Vector{StateVar{T}}  # underlying state variables
    μ::String  # name of the continuation parameter
    active::Bool  # whether the continuation parameter is active initially
end

#--- Closed functions (for computational speed)

const SimpleView{T} = SubArray{T, 1, Array{T, 1}, Tuple{UnitRange{Int}}, true} where T

struct ClosedEmbeddedFunctions{T <: Number,
                               F <: Tuple,
                               FU <: Tuple,
                               G <: Tuple,
                               GU <: Tuple}
    u::Vector{StateVar{T}}
    uᵢ::Vector{Tuple{Int, Int}}
    uᵥ::Vector{SimpleView{T}}  # view cache; should be same size as u
    Φ::F
    Φᵤ::FU
    Φᵢ::Vector{Tuple{Int, Int}}
    μ::Vector{T}
    μᵢ::Vector{Int}
    𝕁::Vector{Bool}  # 𝕁 denotes active continuation parameters (i.e., continuation parameters that vary)
    Ψ::G
    Ψᵤ::GU
    Ψᵢ::Vector{Int}
end

"""
    ClosedEmbeddedFunctions(Φ::Vector{ZeroFunction}, Ψ::Vector{MonitorFunction})

A ClosedEmbeddedFunctions structure is an optimised structure that allows fast
execution of the embedded zero and monitor functions within the problem,
avoiding dynamic dispatch.

This function generates a ClosedEmbeddedFunctions structure from a vector of
zero functions and a vector of monitor functions. Any state variables referenced
will be automatically included in the closed problem.
"""
function ClosedEmbeddedFunctions(
        Φ::Vector{ZeroFunction{T, F} where F},
        Ψ::Vector{MonitorFunction{T, F} where F}
        ) where T <: Number
    # Check for uniqueness
    if !allunique(Φ)
        throw(ArgumentError("Some zero functions are included multiple times"))
    end
    if !allunique(Ψ)
        throw(ArgumentError("Some monitor functions are included multiple times"))
    end
    # Get the necessary state variables
    u = Vector{StateVar{T}}()
    Φᵤ = []  # a vector of tuples of different lengths
    for ϕ in Φ
        ϕᵤ = Int[]
        for uu in ϕ.u
            if !(uu in u)
                push!(u, uu)
            end
            push!(ϕᵤ, findfirst(isequal(uu), u))
        end
        push!(Φᵤ, (ϕᵤ...,))
    end
    Φᵢ = Vector{Tuple{Int, Int}}(undef, length(Φ))
    Ψᵤ = []  # a vector of tuples of different lengths so needs to be Any
    𝕁 = Bool[]
    for ψ in Ψ
        ψᵤ = Int[]
        for uu in ψ.ϕ.u
            if !(uu in u)
                push!(u, uu)
            end
            push!(ψᵤ, findfirst(isequal(uu), u))
        end
        push!(𝕁, ψ.active)
        push!(Ψᵤ, (ψᵤ...,))
    end
    Ψᵢ = Vector{Int}(undef, length(Ψ))
    uᵢ = Vector{Tuple{Int, Int}}(undef, length(u))
    uᵥ = Vector{SimpleView{T}}(undef, length(u))
    μ = Vector{T}(undef, length(Ψ))
    μᵢ = Vector{Int}(undef, length(μ))
    closed = ClosedEmbeddedFunctions(u, uᵢ, uᵥ, (Φ...,), (Φᵤ...,), Φᵢ, μ, μᵢ, 𝕁, (Ψ...,), (Ψᵤ...,), Ψᵢ)
    resize!(closed)
end

"""
    resize!(closed::ClosedEmbeddedFunctions)

Update the indices within `closed` to reflect changes in the sizes of the
underlying state variables and the dimensions of the zero functions.
"""
function resize!(closed::ClosedEmbeddedFunctions)
    # State variables
    idx = 1
    for i = 1:length(closed.u)
        n = length(closed.u[i].u)
        closed.uᵢ[i] = (idx, idx + n - 1)
        idx += n
    end
    for i = 1:length(closed.μ)
        if closed.𝕁[i]
            closed.μᵢ[i] = idx
            idx += 1
        else
            closed.μᵢ[i] = 0
        end
    end
    # Zero and monitor functions
    idx = 1
    for i = 1:length(closed.Φ)
        m = closed.Φ[i].m[]
        closed.Φᵢ[i] = (idx, idx + m - 1)
        idx += m
    end
    for i = 1:length(closed.Ψ)
        closed.Ψᵢ[i] = idx
        idx += 1
    end
    closed
end

@generated function rhs!(
        res::AbstractVector{T},
        closed::ClosedEmbeddedFunctions{T, F, FU, G, GU},
        u::AbstractVector{T}
        ) where {T <: Number, F, FU, G, GU}
    body = quote
        # Views on the state variables get reused, so precompute them
        for i = 1:length(closed.uᵢ)
            (i0, i1) = closed.uᵢ[i]
            closed.uᵥ[i] = view(u, i0:i1)
        end
    end
    for i in 1:length(FU.parameters)
        # Construct function calls of the form Φ[i](resᵥ[i], uᵥ[Φᵤ[i][1]], ..., uᵥ[Φᵤ[i][n]])
        push!(body.args, :(closed.Φ[$i].f(view(res, closed.Φᵢ[$i][1]:closed.Φᵢ[$i][2]), $((:(closed.uᵥ[closed.Φᵤ[$i][$j]]) for j in 1:length(FU.parameters[i].parameters))...))))
    end
    push!(body.args, :res)
    body
end

function pullu!(u::AbstractVector{T}, closed::ClosedEmbeddedFunctions{T}) where T <: Number
    for i = 1:length(closed.u)
        u[closed.uᵢ[i][1]:closed.uᵢ[i][2]] .= closed.u[i].u
    end
    for i = 1:length(closed.μ)
        if closed.𝕁[i]
            u[closed.μᵢ[i]] = closed.μ[i]
        end
    end
    u
end
pullu!(closed::ClosedEmbeddedFunctions{T}) where {T <: Number} = pullu!(zeros(T, closed.μᵢ[end]), closed)

function pushu!(closed::ClosedEmbeddedFunctions{T}, u::AbstractVector{T}) where T <: Number
    for i = 1:length(closed.u)
        closed.u[i].u .= u[closed.uᵢ[i][1]:closed.uᵢ[i][2]]
    end
end

end  # module
