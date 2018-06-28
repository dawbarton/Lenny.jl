using Lenny

const L = Lenny

function circle!(res, u)
    res[1] = u[1]^2 + (u[2] - 1)^2 - 1
end

function plane!(res, u)
    res[1] = u[1] + u[2]
end

function hyper!(res, u)
    res[1] = u[1]^2 - u[2]^2
end

z1 = L.ZeroProblem(circle!, u0=[0.9, 1.1], dim=1)
z2 = L.ZeroProblem(plane!, dep=((z1, 2),), u0=[-1.1], dim=1)
m1 = L.MonitorFunction(hyper!, dep=((z1, 1), (z2, 2)), pnames=[:p], active=false)

prob = L.ContinuationProblem()
L.add(prob, z1)
L.add(prob, z2)
L.add(prob, m1)
