module Solvers

#--- Dependencies

import ..Lenny: close!

#--- Exports

# Exported types
export AbstractSolver, NLsolve

# Exported functions
export DefaultSolver

#--- Base solver type

abstract type AbstractSolver{T <: Number} end

close!(prob, solver::AbstractSolver) = solver

#--- Integrated solvers

struct NLsolve{T <: Number} <: AbstractSolver{T} end

DefaultSolver(T::DataType) = NLsolve{T}()

end  # module
