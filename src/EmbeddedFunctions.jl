module EmbeddedFunctions

#--- State variables

struct StateVar{T <: Number}
    name::String  # name of the state variable
    u::Vector{T}  # underlying state (mutable)
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
    ϕ::ZeroFunction{T, F}  # the underlying zero function g(u) - μ = 0
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
    resᵢ::Vector{Tuple{Int, Int}}
    Φ::F
    Φᵤ::FU
    μ::Vector{T}
    𝕀::Vector{Bool}
    Ψ::G
    Ψᵤ::GU
end

function ClosedEmbeddedFunctions(
        Φ::Vector{ZeroFunction{T, F} where F},
        Ψ::Vector{MonitorFunction{T, F} where F}
        ) where T <: Number
    # Check for uniqueness
    if !allunique(ϕ)
        throw(ArgumentError("Some zero functions are included multiple times"))
    end
    if !allunique(ψ)
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
    Ψᵤ = []  # a vector of tuples of different lengths
    for ψ in Ψ
        ψᵤ = Int[]
        for uu in ψ.ϕ.u
            if !(uu in u)
                push!(u, uu)
            end
            push!(ψᵤ, findfirst(isequal(uu), u))
        end
        push!(Ψᵤ, (ψᵤ...,))
    end
    # TODO: finish this off
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
        push!(body.args, :(closed.Φ[$i].f(view(res, closed.resᵢ[$i][1]:closed.resᵢ[$i][2]), $((:(closed.uᵥ[closed.Φᵤ[$i][$j]]) for j in 1:length(FU.parameters[i].parameters))...))))
    end
    push!(body.args, :res)
    body
end


end
