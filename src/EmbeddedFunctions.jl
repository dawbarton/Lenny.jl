module EmbeddedFunctions

#--- Dependencies

import Base: resize!

#--- Exports

# Exported types
export StateVar, ZeroFunction, MonitorFunction, ClosedEmbeddedFunctions

# Exported functions
export getu, getu!, setu!, getmu, getmu!, setmu!, getvars, getvars!,
    setvars!, muidx, active, active!, dim_u, dim_mu, dim_phi, dim_psi,
    mu_idx, mu_name, eval_efuncs!, eval_mfuncs!

#--- State variables

struct StateVar{T <: Number}
    name::String  # name of the state variable
    u::Vector{T}  # initial state (may be changed during continuation)
    t::Vector{T}  # initial tangent (may be changed during continuation)
end
StateVar(name::String, u::Vector{T}) where {T <: Number} = StateVar(name, u, Vector{T}())

#--- Zero functions (otherwise known as zero problems)

struct ZeroFunction{T <: Number, F}
    f::F  # underlying function
    u::Vector{StateVar{T}}  # underlying state variables
    res::Vector{T}  # output vector
end
ZeroFunction(f, u::Vector{StateVar{T}}, m::Integer) where T <: Number = ZeroFunction(f, u, Vector{T}(undef, m))

#--- Monitor functions

struct MonitorFunction{T <: Number, F}
    f::F  #underlying function
    u::Vector{StateVar{T}}  # underlying state variables
    μ_name::String  # name of the continuation parameter
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
    μₛ::Dict{String, Int}
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
function ClosedEmbeddedFunctions(Φ::Vector{<: ZeroFunction{T}}, Ψ::Vector{<: MonitorFunction{T}}) where T <: Number
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
    μₛ = Dict{String, Int}()
    for i = eachindex(Ψ)
        ψ = Ψ[i]
        ψᵤ = Int[]
        for uu in ψ.u
            if !(uu in u)
                push!(u, uu)
            end
            push!(ψᵤ, findfirst(isequal(uu), u))
        end
        push!(𝕁, ψ.active)
        push!(Ψᵤ, (ψᵤ...,))
        push!(μₛ, ψ.μ_name => i)
    end
    Ψᵢ = Vector{Int}(undef, length(Ψ))
    uᵢ = Vector{Tuple{Int, Int}}(undef, length(u))
    uᵥ = Vector{SimpleView{T}}(undef, length(u))
    μ = Vector{T}(undef, length(Ψ))
    μᵢ = Vector{Int}(undef, length(μ))
    closed = ClosedEmbeddedFunctions(u, uᵢ, uᵥ, (Φ...,), (Φᵤ...,), Φᵢ, μ, μᵢ, μₛ, 𝕁, (Ψ...,), (Ψᵤ...,), Ψᵢ)
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
    for i = eachindex(closed.u)
        n = length(closed.u[i].u)
        closed.uᵢ[i] = (idx, idx + n - 1)
        idx += n
    end
    # Continuation parameters
    for i = eachindex(closed.μ)
        if closed.𝕁[i]
            closed.μᵢ[i] = idx
            idx += 1
        else
            closed.μᵢ[i] = 0
        end
    end
    # Zero and monitor functions
    idx = 1
    for i = eachindex(closed.Φ)
        m = length(closed.Φ[i].res)
        closed.Φᵢ[i] = (idx, idx + m - 1)
        idx += m
    end
    for i = eachindex(closed.Ψ)
        closed.Ψᵢ[i] = idx
        idx += 1
    end
    closed
end

@generated function eval_efuncs!(
        res::AbstractVector{T},
        closed::ClosedEmbeddedFunctions{T, F, FU, G, GU},
        prob,
        u::AbstractVector{T}
        ) where {T <: Number, F, FU, G, GU}
    body = quote
        # Views on the state variables get reused, so precompute them
        for i = eachindex(closed.uᵢ)
            (i0, i1) = closed.uᵢ[i]
            closed.uᵥ[i] = view(u, i0:i1)
        end
        # Copy any active continuation parameter values into the μ variable
        for i = eachindex(closed.μ)
            if closed.𝕁[i]
                closed.μ[i] = u[closed.μᵢ[i]]
            end
        end
    end
    for i in eachindex(FU.parameters)
        # Construct function calls of the form Φ[i](resᵥ[i], uᵥ[Φᵤ[i][1]], ..., uᵥ[Φᵤ[i][n]])
        if length(FU.parameters[i].parameters) == 0
            # No dependencies means pass everything
            push!(body.args, :(closed.Φ[$i].f(view(res, closed.Φᵢ[$i][1]:closed.Φᵢ[$i][2]), prob, u)))
        else
            push!(body.args, :(closed.Φ[$i].f(view(res, closed.Φᵢ[$i][1]:closed.Φᵢ[$i][2]), prob, $((:(closed.uᵥ[closed.Φᵤ[$i][$j]]) for j in eachindex(FU.parameters[i].parameters))...))))
        end
    end
    for i in eachindex(GU.parameters)
        # Construct function calls of the form res[Ψᵢ[i]] = Ψ[i](uᵥ[Ψᵤ[i][1]], ..., uᵥ[Ψᵤ[i][n]]) - μ[i]
        # Uses the return value of Ψ in contrast to Φ since it is assumed to be ℝ rather than ℝⁿ
        if length(GU.parameters[i].parameters) == 0
            # No dependencies means pass everything
            push!(body.args, :(res[closed.Ψᵢ[$i]] = closed.Ψ[$i].f(prob, u) - closed.μ[$i]))
        else
            push!(body.args, :(res[closed.Ψᵢ[$i]] = closed.Ψ[$i].f(prob, $((:(closed.uᵥ[closed.Ψᵤ[$i][$j]]) for j in eachindex(GU.parameters[i].parameters))...)) - closed.μ[$i]))
        end
    end
    push!(body.args, :res)
    body
end

@generated function eval_mfuncs!(
        res::AbstractVector{T},
        closed::ClosedEmbeddedFunctions{T, F, FU, G, GU},
        prob,
        u::AbstractVector{T}
        ) where {T <: Number, F, FU, G, GU}
    body = quote
        # Views on the state variables get reused, so precompute them
        for i = eachindex(closed.uᵢ)
            (i0, i1) = closed.uᵢ[i]
            closed.uᵥ[i] = view(u, i0:i1)
        end
    end
    for i in eachindex(GU.parameters)
        # Construct function calls of the form res[i] = Ψ[i](uᵥ[Ψᵤ[i][1]], ..., uᵥ[Ψᵤ[i][n]])
        # Uses the return value of Ψ in contrast to Φ since it is assumed to be ℝ rather than ℝⁿ
        if length(GU.parameters[i].parameters) == 0
            # No dependencies means pass everything
            push!(body.args, :(res[$i] = closed.Ψ[$i].f(prob, u)))
        else
            push!(body.args, :(res[$i] = closed.Ψ[$i].f(prob, $((:(closed.uᵥ[closed.Ψᵤ[$i][$j]]) for j in eachindex(GU.parameters[i].parameters))...))))
        end
    end
    push!(body.args, :res)
    body
end

"""
    mu_idx(closed::ClosedEmbeddedFunctions, μ::String)

Return the index in the continuation parameter vector of the specified
continuation parameter `μ`.
"""
mu_idx(closed::ClosedEmbeddedFunctions, μ::String) = closed.μₛ[μ]
mu_idx(closed::ClosedEmbeddedFunctions, μ::Integer) = μ

"""
    mu_name(closed::ClosedEmbeddedFunctions, μ::Integer)

Return the name of the specified continuation parameter `μ`.
"""
mu_name(closed::ClosedEmbeddedFunctions, μ::Integer) = closed.Ψ[μ].μ_name

"""
    active(closed::ClosedEmbeddedFunctions)

Return the number of active continuation parameters.
"""
active(closed::ClosedEmbeddedFunctions) = sum(closed.𝕁)

"""
    active(closed::ClosedEmbeddedFunctions, μ)

Return whether the specified continuation parameter `μ` is active or not.
"""
active(closed::ClosedEmbeddedFunctions, μ) = closed.𝕁[muidx(closed, μ)]

"""
    active!(closed::ClosedEmbeddedFunctions, μ, active::Bool)

Set the specified continuation parameter `μ` to be active or not.
"""
active!(closed::ClosedEmbeddedFunctions, μ, active::Bool) = (closed.𝕁[muidx(closed, μ)] = active)

"""
    dim_u(closed::ClosedEmbeddedFunctions)

Return the total number of state variables.
"""
dim_u(closed::ClosedEmbeddedFunctions) = closed.uᵢ[end][end]

"""
    dim_mu(closed::ClosedEmbeddedFunctions)

Return the total number of continuation parameters.
"""
dim_mu(closed::ClosedEmbeddedFunctions) = length(closed.μ)

"""
    dim_phi(closed::ClosedEmbeddedFunctions)

Return the number of output dimensions of the set of zero functions.
"""
dim_phi(closed::ClosedEmbeddedFunctions) = closed.Φᵢ[end][end]

"""
    dim_psi(closed::ClosedEmbeddedFunctions)

Return the number of output dimensions of the set of monitor functions.
"""
dim_psi(closed::ClosedEmbeddedFunctions) = length(closed.Ψ)

function getu!(u::AbstractVector{T}, closed::ClosedEmbeddedFunctions{T}) where T <: Number
    for i = eachindex(closed.u)
        u[closed.uᵢ[i][1]:closed.uᵢ[i][2]] .= closed.u[i].u
    end
    u
end
getu(closed::ClosedEmbeddedFunctions{T}) where {T <: Number} = getu!(zeros(T, dim_u(closed)), closed)

function setu!(closed::ClosedEmbeddedFunctions{T}, u::AbstractVector{T}) where T <: Number
    for i = eachindex(closed.u)
        closed.u[i].u .= u[closed.uᵢ[i][1]:closed.uᵢ[i][2]]
    end
end

function getmu!(μ::AbstractVector{T}, closed::ClosedEmbeddedFunctions{T}; mu=:all) where T <: Number
    if mu == :all
        μ .= closed.μ
    elseif mu == :active
        i = 1
        for j = eachindex(closed.μ)
            if closed.𝕁[j]
                μ[i] = closed.μ[j]
                i += 1
            end
        end
    elseif mu == :inactive
        i = 1
        for j = eachindex(closed.μ)
            if !closed.𝕁[j]
                μ[i] = closed.μ[j]
                i += 1
            end
        end
    else
        throw(ArgumentError("Invalid option for mu; valid options are :all, :active, and :inactive"))
    end
    μ
end

function getmu(closed::ClosedEmbeddedFunctions{T}; mu=:all) where T <: Number
    if mu == :all
        return getmu!(zeros(T, length(closed.μ)), closed)
    elseif mu == :active
        return getmu!(zeros(T, sum(closed.𝕁)), closed)
    elseif mu == :inactive
        return getmu!(zeros(T, sum(.!closed.𝕁)), closed)
    else
        throw(ArgumentError("Invalid option for mu; valid options are :all, :active, and :inactive"))
    end
end

function setmu!(closed::ClosedEmbeddedFunctions{T}, μ::AbstractVector{T}; mu=:all) where T <: Number
    if mu == :all
        closed.μ .= μ
    elseif mu == :active
        i = 1
        for j = eachindex(closed.μ)
            if closed.𝕁[j]
                closed.μ[j] = μ[i]
                i += 1
            end
        end
        if i != length(μ) + 1
            throw(DimensionMismatch("μ is the wrong size"))
        end
    elseif mu == :inactive
        i = 1
        for j = eachindex(closed.μ)
            if !closed.𝕁[j]
                closed.μ[j] = μ[i]
                i += 1
            end
        end
        if i != length(μ) + 1
            throw(DimensionMismatch("μ is the wrong size"))
        end
    else
        throw(ArgumentError("Invalid option for mu; valid options are :all, :active, and :inactive"))
    end
    μ
end

function getvars!(v::AbstractVector{T}, closed::ClosedEmbeddedFunctions{T}) where T <: Number
    for i = eachindex(closed.u)
        v[closed.uᵢ[i][1]:closed.uᵢ[i][2]] .= closed.u[i].u
    end
    for i = eachindex(closed.μ)
        if closed.𝕁[i]
            v[closed.μᵢ[i]] = closed.μ[i]
        end
    end
    v
end

function getvars(closed::ClosedEmbeddedFunctions{T}) where T <: Number
    getvars!(zeros(T, closed.uᵢ[end][end] + sum(closed.𝕁)), closed)
end

function setvars!(closed::ClosedEmbeddedFunctions{T}, v::AbstractVector{T}) where T <: Number
    for i = eachindex(closed.u)
        closed.u[i].u .= v[closed.uᵢ[i][1]:closed.uᵢ[i][2]]
    end
    for i = eachindex(closed.μ)
        if closed.𝕁[i]
            closed.μ[i] = v[closed.μᵢ[i]]
        end
    end
    v
end

end  # module
