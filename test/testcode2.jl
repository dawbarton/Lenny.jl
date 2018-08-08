using Lenny

function circle!(res, x, y)
    res[1] = x[1]^2 + (y[1] - 1)^2 - 1
end

function plane!(res, x, z)
    res[1] = x[1] + z[1]
end

function hyper!(x, z)
    x[1]^2 - z[1]^2
end

x = StateVar("x", [0.9])
y = StateVar("y", [1.1])
z = StateVar("z", [-1.1])

z1 = ZeroFunction(circle!, [x, y], 1)
z2 = ZeroFunction(plane!, [x, z], 1)
m1 = MonitorFunction(hyper!, [x, z], "hyper", true)

cl = EmbeddedFunctions.ClosedEmbeddedFunctions([z1, z2], [m1])

u = zeros(4)  # includes continuation parameters (μ)
EmbeddedFunctions.pullu!(u, cl)  # doesn't include continuation parameters *at the moment*

res = zeros(3)
EmbeddedFunctions.rhs!(res, cl, u)

#---
prob = ContinuationProblem()
push!(prob.Φ, z1)
push!(prob.Φ, z2)
push!(prob.Ψ, m1)

prob1 = Lenny.close!(prob)
