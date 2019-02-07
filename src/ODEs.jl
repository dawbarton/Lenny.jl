module ODEs

using ..ZeroProblems: Var, AbstractZeroSubproblem

# TODO: General question about Symbols or Strings for names (or a union??)

#--- General ODE problems

# Need to make this interoperable with DifferentialEquations.jl (and any other packages...)

struct ODE{IP, F, DFDX, DFDP}
	name::Symbol
	f::F
	dfdx::DFDX
	dfdp::DFDP
	pnames::Vector{Symbol}
end

function ODE(f; inplace=true, name=:ode, dfdx=nothing, dfdp=nothing, pnames=Symbol[])
	# TODO: default to inplace=nothing and check for methods with the correct number of arguments
	if pnames isa Vector{Symbol}
		_pnames = pnames
	else
		_pnames = [Symbol(p) for p in pnames]
	end
	return ODE{inplace, typeof(f), typeof(dfdx), typeof(dfdp)}(name, f, dfdx, dfdp, _pnames)
end

#--- Equilibrium problems

struct Equilibrium{O, T} <: AbstractZeroSubproblem 
	name::Symbol
	deps::Vector{Var}
	ode::O
	x0::Vector{T}
	p0::Vector{T}
end

function Equilibrium(ode, x0, p0; name=:ep)
	xdim = length(x0)
	pdim = length(p0)
	u = Var(name, xdim + pdim)
	x = Var(:x, xdim, u, 0)
	p = Var(:p, pdim, u, -pdim)
	return Equilibrium(name, )
end






end  # end module
