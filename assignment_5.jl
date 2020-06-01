# ExprC types
struct NumC
    num::Number
    NumC(num) = new(num)
end

struct StrC
    str::String
    StrC(str) = new(str)
end

struct IfC
    test
    tehn
    els
    IfC(test, then, els) = new(test, then, els)
end

struct AppC
    body
    args::Array{Any}
    AppC(body, args) = new(body, args)
end

struct LamC
    body
    args::Array{Any}
    LamC(body, args) = new(body, args)
end

struct IdC
    id::String
    IdC(id) = new(id)
end

ExprC = Union{NumC, StrC, IfC, AppC, LamC, IdC}
# Value Types
struct NumV
    val :: Real
    NumV(val) = new(val)
end

struct BoolV
    val :: Bool
    BoolV(val) = new(val)
end

struct StrV
    val :: String
    StrV(val) = new(val)
end

struct ClosV
    args :: Array{String}
    body :: ExprC
    env :: Enviroment
    ClosV(args, body, env) = new(args, body, env)
end

struct PrimV
    op :: String
    PrimV(op) = new(op)
end

Value = Union{NumV, BoolV, StrV, ClosV, PrimV}
