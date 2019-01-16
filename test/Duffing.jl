module Duffing

using OrdinaryDiffEq
using NLsolve
using StaticArrays

function duffing!(dxdt, x, p, t)
	dxdt[1] = x[2]
	dxdt[2] = sin(p.ω*t) - p.c*x[2] - p.k*x[1] - p.β*x[1]^3
	nothing
end

function zeroproblem!(res, x, p)
	c, k, β, ω = p
	prob = ODEProblem(duffing!, x, (0.0, 2π/ω), (c=c, k=k, β=β, ω=ω))
	sol = solve(prob, Tsit5(), dtmax=one(eltype(x))/10)
    res[1:2] .= x[1:2] .- sol[1:2, end]
    nothing
end

function runtest()
	# Generate a brute-force bifurcation diagram
	p = [0.05, 1.0, 0.1, 0.0]
	Ω = range(0.1, stop=4, length=51)
	x = Vector{Vector{Float64}}()
	lastx = [0.0, 0.0]
	for ω in Ω
		p[4] = ω
		sol = nlsolve((res, u) -> zeroproblem!(res, u, p), lastx)
		if converged(sol)
			lastx = sol.zero
			push!(x, lastx)
		else
			@warn "Failed to converge" ω
			break
		end
	end
	(Ω, x)
end

end
