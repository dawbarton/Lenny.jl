mutable struct MyLogger
    args::Any
end

function (x::MyLogger)(args...)
    x.args = args
end

@testset "Callbacks" begin

logger1 = MyLogger(nothing)
logger2 = MyLogger(nothing)

cb = L.CallbackSignals()
L.addcallback!(cb, "test1", logger1)
@test_throws ArgumentError L.addcallback!(cb, "test1", logger1)
@test_throws ErrorException isvalid(cb)
L.addsignal!(cb, "test1")
@test isvalid(cb)
@test_throws ArgumentError L.addsignal!(cb, "test1")
@test cb["test1"] == (logger1,)
@test_throws ArgumentError cb["test2"]
@test_throws ArgumentError L.emitsignal(cb, "test2")
L.addsignal!(cb, "test2")
@test cb["test2"] == ()
L.emitsignal(cb, "test1")
@test logger1.args == ()
L.addcallback!(cb, "test1", logger2)
L.emitsignal(cb, "test1", 2, 3)
@test (logger1.args == (2, 3)) && (logger2.args == (2, 3))
L.emitsignal(cb["test1"], "Hello world")
@test (logger1.args == ("Hello world",)) && (logger2.args == ("Hello world",))
@test L.emitsignal(cb, "test2") == nothing

end
