@testset "EmbeddedProblems" begin

function circle!(res, u)
    res[1] = u[1]^2 + (u[2] - 1)^2 - 1
end

function plane!(res, u)
    res[1] = u[1] + u[2]
end

function hyper!(res, u)
    res[1] = u[1]^2 - u[2]^2
end

@test_throws ArgumentError L.ZeroProblem(circle!, u0=Any[0.9, 1.1], dim=1)
@test_throws ArgumentError L.ZeroProblem(circle!, dim=1)
@test_throws MethodError L.ZeroProblem(circle!, u0=[0.9, 1.1])
z1 = L.ZeroProblem(circle!, u0=[0.9, 1.1], dim=1)
@test_throws ArgumentError L.ZeroProblem(plane!, deps=[(z1, [1,3]),], u0=[-1.1], dim=1)
z2 = L.ZeroProblem(plane!, deps=[(z1, 1),], u0=[-1.1], dim=1)
@test_throws ArgumentError L.MonitorFunction(hyper!, pnames=[:p], active=false)
@test_throws ArgumentError L.MonitorFunction(hyper!, deps=[(z1, 1), (z2, [1,2])], pnames=[:p], active=false)
@test_throws ArgumentError L.MonitorFunction(hyper!, deps=[(z1, 1), (z2, 1)], pnames=[:p], active=[false, false])
m1 = L.MonitorFunction(hyper!, deps=[(z1, 1), (z2, 1)], pnames=[:p], active=false)

@test_throws ArgumentError L.closeproblem([z2], [m1])
@test_throws ArgumentError L.closeproblem([z1, z2, z1], [m1])
@test_throws ArgumentError L.closeproblem([z1], [m1])
@test_throws ArgumentError L.closeproblem([z1, z2], [m1, m1])
prob = L.closeproblem([z1, z2], [m1])

u = zeros(3)
L.pullu!(u, prob) == [0.9, 1.1, -1.1]
@test u == [0.9, 1.1, -1.1]
L.pushu!(prob, 1:3)
@test (z1.u == [1.0, 2.0]) && (z2.u == [1.0, 3.0]) && (m1.u == [1.0, 3.0])

res = zeros(3)
@test L.evaluate!(res, prob, u) ≈ [-0.18, -0.2, -0.4]
@test res ≈ [-0.18, -0.2, -0.4]

end
