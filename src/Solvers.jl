module Solvers

#--- Dependencies

import ..Lenny: close!

#--- Exports

# Exported types
export AbstractSolver, AbstractNLSolver, NLsolve, AbstractLinSolver, LinSolve

# Exported functions
export DefaultNLSolver, DefaultLinSolver

#--- Base solver types

abstract type AbstractSolver{T <: Number} end
abstract type AbstractNLSolver{T <: Number} <: AbstractSolver{T} end
abstract type AbstractLinSolver{T <: Number} <: AbstractSolver{T} end

close!(prob, solver::AbstractSolver) = solver

#--- Integrated nonlinear solvers

struct NLSolve{T <: Number} <: AbstractNLSolver{T} end

DefaultNLSolver(T::DataType) = NLSolve{T}()

#--- Integrated linear solvers

struct LinSolver{T <: Number} <: AbstractLinSolver{T} end

DefaultLinSolver(T::DataType) = LinSolver{T}()

end  # module
