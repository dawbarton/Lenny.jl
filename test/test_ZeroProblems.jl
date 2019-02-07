@testset "ZeroProblems" begin

struct MyProb <: zp.AbstractContinuationProblem end

pb = MyProb()

coll = zp.Var(:coll, 20)
x0 = zp.Var(:x0, 1, coll, 0)
x1 = zp.Var(:x1, 1, coll, -1)

u = (coll, x0, x1)
ui = [1:size(coll), 1:1, size(coll):size(coll)]
D = ((1), (2, 3), ())
ϕ = (sum, prod, maximum)
ϕi = [1:1, 2:2, 3:3]	


prob = zp.ZeroProblem{D, length(u), typeof(ϕ)}(u, ui, ϕ, ϕi)

res = zeros(3)
zp.residual!(res, prob, pb, rand(20))

end