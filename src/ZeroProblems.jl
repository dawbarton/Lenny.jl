module ZeroProblems

using ..Lenny: AbstractContinuationProblem

#--- Forward definitions

"""
	name(x)

Return the name of a variable or zero problem as a Symbol.
"""
function name end

"""
	dependencies(x)

Return the variable dependencies of a zero problem as a Tuple.
"""
function dependencies end

#--- Variables that zero problems depend on

"""
	Var

A placeholder for a continuation variable. As a minimum it comprises a name and
length (in units of the underlying numerical type). Optionally it can include a
parent variable and offset into the parent variable (negative offsets represent
the offset from the end).

# Example

```
coll = Var(:collocation, 20)  # an array of 20 Float64 (or other numerical type)
x0 = Var(:x0, 1, coll, 0)  # a single Float64 at the start of the collocation array
x1 = Var(:x1, 1, coll, -1)  # a single Float64 at the end of the collocation array
```
"""
mutable struct Var
	name::Symbol
	len::Int
	parent::Union{Var, Nothing}
	offset::Int
end

Var(name::Symbol, len::Integer) = Var(name, len, nothing, 0)

name(u::Var) = u.name
Base.length(u::Var) = u.len

#--- ZeroSubproblem

# For simple subproblems the ZeroSubproblem type can be used to define a
# subproblem and its associated variable dependencies.

# For more complicated subproblems (or subproblems that require access to the
# full problem structure) you should inherit from AbstractZeroSubproblem.

abstract type AbstractZeroSubproblem end

name(ϕ::AbstractZeroSubproblem) = ϕ.name
dependencies(ϕ::AbstractZeroSubproblem) = ϕ.deps

struct ZeroSubproblem{F} <: AbstractZeroSubproblem
	name::Symbol
	deps::Vector{Var}
	f!::F
end

@inline (z::ZeroSubproblem)(res, prob::AbstractContinuationProblem, u...) = z.f!(res, u...)
@inline (z::ZeroSubproblem)(res, u...) = z.f!(res, u...)

#--- ZeroProblem - the full problem structure

struct ZeroProblem{D, U, Φ}
	u::U
	ui::Vector{UnitRange{Int}}
	ϕ::Φ
	ϕi::Vector{UnitRange{Int}}
	ϕdeps::Vector{Tuple{Vararg{Int, N} where N}}
end

ZeroProblem() = ZeroProblem{Nothing, Vector{Var}, Vector{Any}}(Vector{Var}(), Vector{UnitRange{Int}}(), Vector{Any}(), Vector{UnitRange{Int}}())

function Base.push!(zp::ZeroProblem{Nothing}, u::Var)
	if !(u in zp.u)
		if u.parent === nothing
			last = maximum(maximum.(zp.ui))
			push!(zp.u, u)
			push!(zp.ui, last + 1:last + length(u))
		else
			idx = findfirst(isequal(u.parent), zp.u)
			start = (u.offset < 0) ? (zp.ui[idx][end] + u.offset + 1) : (zp.ui[idx][1] + u.offset)
			push!(zp.u, u)
			push!(zp.ui, start:start + length(u) - 1)
		end
	end
	return zp
end

function Base.push!(zp::ZeroProblem{Nothing}, subprob::AbstractZeroSubproblem)
	if subprob in zp.ϕ
		throw(ArgumentError("Subproblem is already part of the zero problem"))
	end
	depidx = Vector{Int}()
	for dep in dependencies(subprob)
		push!(zp, dep)
		push!(depidx, findfirst(isequal(dep), zp.u))
	end
	last = maximum(maximum.(zp.ϕi))
	push!(zp.ϕ, ϕ)
	push!(zp.ϕi, last + 1:last + length(ϕ))
	push!(zp.ϕdeps, (depidx...,))
	return zp
end

function specialize(zp::ZeroProblem)
	u = (zp.u...,)
	ui = zp.ui
	ϕ = (zp.ϕ...,)
	ϕi = zp.ϕi
	ϕdeps = zp.ϕdeps
	return ZeroProblem{(ϕdeps...,), typeof(u), typeof(ϕ)}(u, ui, ϕ, ϕi, ϕdeps)
end

function residual!(res, zp::ZeroProblem{Nothing}, prob::AbstractContinuationProblem, u)
	# TODO: implement anyway?
	throw(ArgumentError("Specialize the zero problem before calling residual!"))
end

@generated function residual!(res, zp::ZeroProblem{D, U, Φ}, prob::AbstractContinuationProblem, u) where {D, U <: Tuple, Φ <: Tuple}
	body = quote
		# Construct views into u for each variable
		uv = ($((:(view(u, zp.ui[$i])) for i in eachindex(U.parameters))...),)
		# Construct views into res for each subproblem
		resv = ($((:(view(res, zp.ϕi[$i])) for i in eachindex(Φ.parameters))...),)
	end
	# Call each of the subproblems
	for i in eachindex(D)
        if length(D[i]) == 0
            # No dependencies means pass everything
            push!(body.args, :(zp.ϕ[$i](resv[$i], prob, u)))
        else
            push!(body.args, :(zp.ϕ[$i](resv[$i], prob, $((:(uv[$(D[i][j])]) for j in eachindex(D[i]))...))))
        end
	end
	# Return res
    push!(body.args, :res)
    @show body
    body
end

end
