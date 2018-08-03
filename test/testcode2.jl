function circle!(res, x, y)
    res[1] = x[1]^2 + (y[1] - 1)^2 - 1
end

function plane!(res, x, z)
    res[1] = x[1] + z[1]
end

function hyper!(x, z)
    x[1]^2 - z[1]^2
end

x = EmbeddedFunctions.StateVar("x", [0.9])
y = EmbeddedFunctions.StateVar("y", [1.1])
z = EmbeddedFunctions.StateVar("z", [-1.1])

z1 = EmbeddedFunctions.ZeroFunction(circle!, [x, y], 1)
z2 = EmbeddedFunctions.ZeroFunction(plane!, [x, z], 1)
m1 = EmbeddedFunctions.MonitorFunction(hyper!, [x, z], "hyper", true)

cl = EmbeddedFunctions.ClosedEmbeddedFunctions([z1, z2], [m1])

u = zeros(4)  # includes continuation parameters (μ)
EmbeddedFunctions.pullu!(u, cl)  # doesn't include continuation parameters *at the moment*

res = zeros(3)
EmbeddedFunctions.rhs!(res, cl, u)
