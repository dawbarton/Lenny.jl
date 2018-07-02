module Lenny

using Compat: undef

#--- Embedded problems (i.e., smooth problems)

abstract type EmbeddedProblem{T <: Number} end

#--- Zero problems

const DependVar = Union{Symbol, Int, UnitRange}

mutable struct ZeroProblem{T, F}  <: EmbeddedProblem{T}
    func::F  # underlying function ϕ:ℝⁿ→ℝᵐ
    deps::Vector{Tuple{ZeroProblem, DependVar}}  # dependencies
    u::Vector{T}  # storage for the input vector
    nk::Int  # dimension of the input (dependencies)
    nf::Int  # dimension of the input (new variables); n = nk + nf
    m::Int  # dimension of output
    idxk::Vector{Int}  # index into the master u variable of dependencies
    idxf::Int  # start index into the master u variable of new variables
end

function ZeroProblem(func;
        deps::AbstractVector{Tuple{T, S}}=Tuple{ZeroProblem, Int}[],
        u0::AbstractVector{R}=[],
        dim::Int=0) where {R <: Number, T <: ZeroProblem, S}
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
            throw(ArgumentError("Dependencies must be specified as a symbol, an Int, or a UnitRange"))
        end
        push!(newdeps, dep)
        append!(u, dep[1].u[varindex(dep[1], dep[2])])
    end
    nk = length(u)
    append!(u, u0)
    nf = length(u0)
    # Get the dimension if it isn't provided
    if dim == 0
        dim = getdim(func, u)
    end
    # Construct!
    ZeroProblem(func, newdeps, u, nk, nf, dim, fill(0, nk), 0)
end

#--- Monitor functions

struct MonitorFunction{T, F} <: EmbeddedProblem{T}
    func::F  # underlying function ψ:ℝⁿ→ℝʳ
    deps::Vector{Tuple{ZeroProblem, DependVar}}  # dependencies
    pnames::Vector{Symbol}  # continuation parameter names (size r; cannot change size)
    active::Vector{Bool}  # whether or not the continuation parameters are active
    u::Vector{T}  # storage for the input vector
    idxk::Vector{Int}  # index into the master u variable for dependencies
end

function MonitorFunction(func;
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
    # Check for active being a scalar
    if active isa AbstractVector
        if length(active) != length(pnames)
            throw(ArgumentError("active should either be a scalar Bool or a vector of Bools of the same length as pnames"))
        end
        MonitorFunction(func, newdeps, pnames, active, u, fill(0, length(u)))
    else
        MonitorFunction(func, newdeps, pnames, fill(active, length(pnames)), u, fill(0, length(u)))
    end
end

#--- Continuation variables and parameters

# Variables exported by problem definitions that can be reused
vars(x) = Symbol[]  # by default don't export any variables (generic fallback)
vars(problem::ZeroProblem) = vars(problem.func)

# varindex ignores dependencies (TODO: docstrings)
function varindex(problem::ZeroProblem, idx::Union{Int, UnitRange})
    if any(idx > problem.nf)
        throw(ArgumentError("Index requested is larger than the number of state variables (varindex ignores dependencies)"))
    end
    idx
end
varindex(problem::ZeroProblem, sym::Symbol) = varindex(problem.func, sym)

# Parameters exported by problem definitions that can be reused
pars(x) = Symbol[]
pars(problem::MonitorFunction) = problem.pnames

#--- Constructed problem

struct ConstructedProblem{F, G, T <: Number}
    zeroproblems::F  # ϕ:ℝⁿ→ℝᵐ
    monitorfunctions::G  # ψ:ℝⁿ→ℝʳ
    u::Vector{T}  # dimension n
    μ::Vector{T}  # dimension r
    res::Vector{T}  # dimension m+r
end

function constructproblem(zeroproblems, monitorfunctions)
    # TODO: check for unique zeroproblems/monitorfunctions (i.e., no accidental repeats)
    # Get the underlying numerical type
    T = eltype(zeroproblems[1].u)  # this should always be valid due to the outer constructors of ZeroProblem and MonitorFunction
    # TODO: This should almost entirely go in a resize function
    # Get the total number of continuation variables and update indices of continuation variables
    n = 0
    m = 0
    for zp in zeroproblems
        zp.idxf = n+1
        n += zp.nf
        m += zp.m
    end
    u = Vector{T}(undef, n)
    # Copy u0 and update indices of the dependencies
    for zp in zeroproblems
        for i in 1:zp.nf
            u[i - 1 + zp.idxf] = zp.u[i + zp.nk]
        end
        if length(zp.deps) > 0
            resize!(zp.idxk, 0)
            for dep in zp.deps
                # NOTE: varindex ignores dependencies because otherwise it would
                # be possible to construct cyclic dependencies that never end
                append!(zp.idxk, dep[1].idxf - 1 + varindex(dep[1], dep[2]))
            end
        end
    end
    for mf in monitorfunctions
        resize!(mf.idxk, 0)
        for dep in mf.deps
            append!(mf.idxk, dep[1].idxf - 1 + varindex(dep[1], dep[2]))
        end
    end
    # Get the total number of continuation parameters
    r = 0
    for monitorfunction in monitorfunctions
        r += length(monitorfunction.pnames)
    end
    μ = zeros(T, r)
    res = zeros(T, m+r)
    # Construct!
    ConstructedProblem((zeroproblems...,), (monitorfunctions...,), u, μ, res)
end

function evaluate(prob::ConstructedProblem, u::AbstractVector, μ::AbstractVector)

end

end # module
