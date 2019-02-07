module Lenny

#--- Fundamentals

abstract type AbstractContinuationProblem{T} end
abstract type AbstractToolbox{T} end
abstract type AbstractCovering{T} end
abstract type AbstractSolver{T} end
abstract type AbstractZeroProblem{T} end

function initialise end
function finalise end
function toolboxes end
function covering end
function zeroproblem end
function solver end


#--- Modules

include("FiniteStateMachines.jl")
include("Coverings.jl")
include("ZeroProblems.jl")
include("ODEs.jl")


#--- Basic continuation problem structure (user facing)

mutable struct ContinuationProblem{T} <: AbstractContinuationProblem{T}
	options::Dict{String, Any}
	toolboxes::Vector{AbstractToolbox{T}}
	covering::AbstractCovering{T}
	efuncs
	solver::AbstractSolver{T}
end

ContinuationProblem{T}() where T = ContinuationProblem(Dict{String, Any}(), AbstractToolbox{T}[], ZeroProblems.emptyCoverings.DefaultCovering())

Base.push!(prob::ContinuationProblem{T}, tbx::AbstractToolbox{T}) where T = (push!(prob.toolboxes, tbx); prob)
Base.push!(prob::ContinuationProblem{T}, cov::AbstractCovering{T}) where T = (prob.covering = cov; prob)
Base.setindex!(prob::ContinuationProblem, idx, val) = setindex!(prob.options, idx, val)

function initialise(prob::ContinuationProblem{T}) where T
	# Initialise toolboxes
	for i in eachindex(prob.toolboxes)
		prob.toolboxes[i] = initialise(prob.toolboxes[i], prob)
	end
	# Initialise solver
	# prob.solver = initialise(prob.solver, prob)
	# Initialise covering
	prob.covering = initialise(prob.covering, prob)
	# Initialise efuncs
	prob.efuncs = initialise(prob.efuncs, prob)
	# Return the final problem structure (TODO: specialise at this point)
	return prob
end

toolboxes(prob::ContinuationProblem) = prob.toolboxes
covering(prob::ContinuationProblem) = prob.covering
efuncs(prob::ContinuationProblem) = prob.efuncs
solver(prob::ContinuationProblem) = prob.solver

end # module
