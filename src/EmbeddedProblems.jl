module EmbeddedProblems

#--- Exports

# Exported types
export EmbeddedProblem, ZeroProblem, MonitorFunction, ConstructedProblem

# Exported functions
export evaluate!, pullu!, pushu!, constructproblem

#--- Dependencies

using Compat

#--- Embedded problems (i.e., smooth problems)

abstract type EmbeddedProblem{T <: Number} end

#--- Helpers

const DependVar = Union{Symbol, Int, UnitRange}

function getdim end

#--- Zero problems

mutable struct ZeroProblem{T, F}  <: EmbeddedProblem{T}
    f::F  # underlying function f:ℝⁿ→ℝᵐ
    k::Vector{Tuple{ZeroProblem, DependVar}}  # dependencies
    u::Vector{T}  # storage for the input vector
    res::Vector{T}  # storage for output vector
    nₖ::Int  # dimension of the input (dependencies)
    nₙ::Int  # dimension of the input (new variables); n = nₖ + nₙ
    m::Int  # dimension of output
    iₖ::Vector{Int}  # index into master u (dependencies)
    iₙ::Int  # index into master u (new variables)
    iᵣ::Int  # index into master res
end

function ZeroProblem(f;
        deps::AbstractVector{Tuple{T, S}}=Tuple{ZeroProblem, Int}[],
        u0::AbstractVector{R}=[],
        dim::Int=0) where {R, T <: ZeroProblem, S}
    if !(R <: Number)
        if length(u0) != 0
            throw(ArgumentError("u0 must be a numerical array"))
        end
        # Get the type from the dependencies
        if length(deps) == 0
            throw(ArgumentError("deps and u0 are missing - cannot have a function with no arguments as a zero problem"))
        end
        RR = eltype(deps[1][1].u)
    else
        RR = R
    end
    # Get an initial copy of the dependencies and build u (mostly for space allocation)
    u = Vector{RR}()
    newdeps = Vector{Tuple{ZeroProblem, DependVar}}()  # needed because can't autoconvert from Any
    for dep in deps
        if !(dep[2] isa DependVar)
            throw(ArgumentError("Dependencies must be specified as a Symbol, an Int, or a UnitRange"))
        end
        push!(newdeps, dep)
        append!(u, dep[1].u[varindex(dep[1], dep[2])])
    end
    nₖ = length(u)
    append!(u, u0)
    nₙ = length(u0)
    # Get the output dimension if it isn't provided
    if dim == 0
        dim = getdim(f, u)
    end
    res = Vector{RR}(undef, dim)
    # Construct!
    ZeroProblem(f, newdeps, u, res, nₖ, nₙ, dim, zeros(Int, nₖ), 0, 0)
end

#--- Monitor functions

mutable struct MonitorFunction{T, F} <: EmbeddedProblem{T}
    f::F  # underlying function f:ℝⁿ→ℝʳ
    k::Vector{Tuple{ZeroProblem, DependVar}}  # dependencies
    p::Vector{Symbol}  # continuation parameter names (size r; cannot change size)
    active::Vector{Bool}  # whether or not the continuation parameters are active
    u::Vector{T}  # storage for the input vector
    res::Vector{T}  # storage for output vector
    nₖ::Int  # dimension of the input (dependencies)
    r::Int  # number of continuation parameters (= number of outputs)
    iₖ::Vector{Int}  # index into master u (dependencies)
    iᵣ::Int  # index into master res
end

function MonitorFunction(f;
        deps::AbstractVector{Tuple{T, S}}=Tuple{ZeroProblem, Int}[],
        pnames::AbstractVector{Symbol}=Symbol[],
        active::Union{AbstractVector{Bool}, Bool}=Bool[]) where {T <: ZeroProblem, S}
    if length(deps) == 0
        throw(ArgumentError("deps are missing - cannot have a function with no arguments as a monitor function"))
    end
    # Get the type parameter from the first dependency
    RR = eltype(deps[1][1].u)
    # Get an initial copy of the dependencies and build u (mostly for space allocation)
    u = Vector{RR}()
    newdeps = Vector{Tuple{ZeroProblem, DependVar}}()  # needed because can't autoconvert
    for dep in deps
        if !(dep[2] isa DependVar)
            throw(ArgumentError("Dependencies must be specified as a symbol, an Int, or a UnitRange"))
        end
        push!(newdeps, dep)
        append!(u, dep[1].u[varindex(dep[1], dep[2])])
    end
    nₖ = length(u)
    r = length(pnames)
    res = Vector{RR}(undef, r)
    # Check for active being a scalar
    if active isa AbstractVector
        if length(active) != r
            throw(ArgumentError("active should either be a scalar Bool or a vector of Bools of the same length as pnames"))
        end
        _active = active
    else
        _active = fill(active, r)
    end
    MonitorFunction(f, newdeps, pnames, _active, u, res, nₖ, r, zeros(Int, nₖ), 0)
end

#--- Continuation variables and parameters

# Variables exported by problem definitions that can be reused
vars(x) = Symbol[]  # by default don't export any variables (generic fallback)
vars(problem::ZeroProblem) = vars(problem.f)

# varindex ignores dependencies (TODO: docstrings)
function varindex(problem::ZeroProblem, idx::Union{Int, UnitRange})
    # TODO: should this just assume inbounds?
    if any(idx > problem.nₙ)
        throw(ArgumentError("Index requested is larger than the number of state variables (varindex ignores dependencies)"))
    end
    idx
end
varindex(problem::ZeroProblem, sym::Symbol) = varindex(problem.f, sym)

# Parameters exported by problem definitions that can be reused
pars(x) = Symbol[]
pars(problem::MonitorFunction) = problem.p

#--- Constructed problem

mutable struct ConstructedProblem{F, G}
    Φ::F  # Φ:ℝⁿ→ℝᵐ
    Ψ::G  # Ψ:ℝⁿ→ℝʳ
    n::Int  # dimension of (all) state
    m::Int  # dimension of zero problem output
    r::Int  # dimension of monitor function output
end

function pullu!(u::AbstractVector, prob::ConstructedProblem)
    for ϕ in prob.Φ
        j = ϕ.iₙ
        for i = ϕ.nₖ .+ (1:ϕ.nₙ)
            u[j] = ϕ.u[i]
            j += 1
        end
    end
    u
end

function pushu!(prob::ConstructedProblem, u::AbstractVector)
    for ϕ in prob.Φ
        # Dependencies
        i = 1
        for j = ϕ.iₖ
            ϕ.u[i] = u[j]
            i += 1
        end
        # Everything else
        j = ϕ.iₙ
        for i = ϕ.nₖ .+ (1:ϕ.nₙ)
            ϕ.u[i] = u[j]
            j += 1
        end
    end
    for ψ in prob.Ψ
        # Dependencies
        i = 1
        for j = ψ.iₖ
            ψ.u[i] = u[j]
            i += 1
        end
    end
    u
end

function resizeproblem!(prob::ConstructedProblem)
    # Determine the new problem size
    iₙ = 0
    iᵣ = 0
    for ϕ in prob.Φ
        ϕ.iₙ = iₙ+1
        iₙ += ϕ.nₙ
        ϕ.iᵣ = iᵣ+1
        iᵣ += ϕ.m
    end
    prob.n = iₙ
    prob.m = iᵣ
    for ψ in prob.Ψ
        ψ.iᵣ = iᵣ+1
        iᵣ += ψ.r
    end
    # Update the dependencies
    for ϕ in prob.Φ
        resize!(ϕ.iₖ, 0)
        for k in ϕ.k
            # NOTE: varindex ignores dependencies because otherwise it would
            # be possible to construct cyclic dependencies that never end
            append!(ϕ.iₖ, k[1].iₙ - 1 + varindex(k[1], k[2]))
        end
    end
    for ψ in prob.Ψ
        resize!(ψ.iₖ, 0)
        for k in ψ.k
            append!(ψ.iₖ, k[1].iₙ - 1 + varindex(k[1], k[2]))
        end
    end
    prob
end

function constructproblem(zeroproblems, monitorfunctions)
    # Check for unique zeroproblems/monitorfunctions (i.e., no accidental repeats)
    if !allunique(zeroproblems)
        throw(ArgumentError("Some zero problems are included multiple times"))
    end
    if !allunique(monitorfunctions)
        throw(ArgumentError("Some monitor functions are included multiple times"))
    end
    # Get the underlying numerical type
    T = eltype(zeroproblems[1].u)  # this should always be valid due to the outer constructors of ZeroProblem and MonitorFunction
    n = 0
    m = 0
    r = 0
    for ϕ in zeroproblems
        n += ϕ.nₙ
        m += ϕ.m
        for k in ϕ.k
            if !(k[1] in zeroproblems)
                throw(ArgumentError("Dependency is not included in the array of zero problems - $k"))
            end
        end
    end
    for ψ in monitorfunctions
        r += ψ.r
        for k in ψ.k
            if !(k[1] in zeroproblems)
                throw(ArgumentError("Dependency is not included in the array of zero problems - $k"))
            end
        end
    end
    # Construct!
    resizeproblem!(ConstructedProblem((zeroproblems...,), (monitorfunctions...,), n, m, r))
end

function evaluate!(res::AbstractVector{T}, problem::ConstructedProblem, u::AbstractVector{T}) where T
    evaluate!(res, problem.Φ, u)
    evaluate!(res, problem.Ψ, u)
    res
end

@generated function evaluate!(res::AbstractVector{T}, embeddedproblems::Tuple, u::AbstractVector{T}) where T
    # Some nice macro magic to ensure that static dispatch is used - since the
    # problem structure doesn't change very frequently (if at all) the
    # compilation time associated with generated functions is not a problem
    f = quote end
    for i in 1:length(embeddedproblems.parameters)
        push!(f.args, :(evaluate!(res, embeddedproblems[$i], u)))
    end
    f
end

function copydependencies!(em::EmbeddedProblem{T}, u::AbstractVector{T}) where T
    i = 1
    @inbounds for iₖ in em.iₖ
        em.u[i] = u[iₖ]
        i += 1
    end
end

function evaluate!(res::AbstractVector{T}, ϕ::ZeroProblem{T}, u::AbstractVector{T}) where T
    # Copy in the dependencies
    copydependencies!(ϕ, u)
    # Copy in the state
    iₙ = ϕ.iₙ
    @inbounds for i = ϕ.nₖ .+ (1:ϕ.nₙ)
        ϕ.u[i] = u[iₙ]
        iₙ += 1
    end
    # Evaluate the function
    @inbounds @views evaluate!(res[ϕ.iᵣ .- 1 .+ (1:ϕ.m)], ϕ.f, ϕ.u)
    nothing
end

function evaluate!(res::AbstractVector{T}, ψ::MonitorFunction{T}, u::AbstractVector{T}) where T
    # Copy in the dependencies
    copydependencies!(ψ, u)
    # Evaluate the function
    @inbounds @views evaluate!(res[ψ.iᵣ .- 1 .+ (1:ψ.r)], ψ.f, ψ.u)
    # TODO: continuation parameters!
end

# Generic fallback
function evaluate!(res::AbstractVector{T}, zp::Function, u::AbstractVector{T}) where T
    zp(res, u)
end

end
