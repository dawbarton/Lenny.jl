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

prob = ContinuationProblem()
for a in [z1, z2, m1]
    add!(prob, a)
end

prob1 = Lenny.close!(prob)
