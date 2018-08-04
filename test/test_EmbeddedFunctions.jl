@testset "EmbeddedFunctions" begin

function circle!(res, prob, x, y)
    res[1] = x[1]^2 + (y[1] - 1)^2 - 1
end

function plane!(res, prob, x, z)
    res[1] = x[1] + z[1]
end

function hyper(prob, x, z)
    x[1]^2 - z[1]^2
end

x = StateVar("x", [0.9])
y = StateVar("y", [1.1])
z = StateVar("z", [-1.1])

z1 = ZeroFunction(circle!, [x, y], 1)
z2 = ZeroFunction(plane!, [x, z], 1)
m1 = MonitorFunction(hyper, [x, z], "hyper", true)

@test_throws ArgumentError L.ClosedEmbeddedFunctions([z1, z1], [m1])
@test_throws ArgumentError L.ClosedEmbeddedFunctions([z1, z2], [m1, m1])

cl = L.ClosedEmbeddedFunctions([z1, z2], [m1])

u = L.getu(cl)
@test u == [0.9, 1.1, -1.1]
L.setu!(cl, [1.0, 2.0, 3.0])
@test L.getu(cl) == [1.0, 2.0, 3.0]

@test_throws DimensionMismatch L.setmu!(cl, [1.2, 3.2], mu=:all)
L.setmu!(cl, [1.2], mu=:all)
@test L.getmu(cl) == [1.2]
@test L.getmu(cl, mu=:all) == [1.2]
@test L.getmu(cl, mu=:active) == [1.2]
@test L.getmu(cl, mu=:inactive) == Float64[]
L.setmu!(cl, [1.3], mu=:active)
@test L.getmu(cl) == [1.3]
@test_throws DimensionMismatch L.setmu!(cl, [1.3], mu=:inactive)

res = zeros(3)
u = [u; 0]

@test L.rhs!(res, cl, NaN, u) ≈ [-0.18, -0.2, -0.4]
@test res ≈ [-0.18, -0.2, -0.4]

end
