module Coverings

#--- Dependencies

using ..Lenny: AbstractCovering
import ..Lenny: initialise

using ..ZeroProblems: dimdeficit, zeroproblem


#--- DefaultCovering - automatically selects an appropriate covering depending on the dimensionality deficit
struct DefaultCovering{T} <: AbstractCovering{T}
end

function initialise(cov::DefaultCovering{T}, prob) where T
	# Choose a covering based on the dimensionality deficit
	dimdef = dimdeficit(zeroproblem(prob))
	if dimdef == 0
		return initialise(Covering0d{T}(), prob)
	elseif dimdef == 1
		return initialise(Covering1d{T}(), prob)
	else
		error("DefaultCovering can only compute 0 or 1 dimensional manifolds")
	end
end


#--- 0 dimensional covering code
struct Covering0d{T} <: AbstractCovering{T}
end

function initialise(cov::Covering0d{T}, prob) where T
	# grab any necessary options from the problem structure
	return cov
end


#--- 1 dimensional covering code
struct Covering1d{T} <: AbstractCovering{T}
end

function initialise(cov::Covering1d{T}, prob) where T
	# grab any necessary options from the problem structure
	return cov
end


end # end module
