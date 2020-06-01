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
    env
    ClosV(args, body, env) = new(args, body, env)
end

struct PrimV
    op :: String
    PrimV(op) = new(op)
end

Value = Union{NumV, BoolV, StrV, ClosV, PrimV}

struct Env
    id::String
    data::Value
    next::Union{Env, Nothing}
end
Environment = Union{Env, Nothing}


function find_in_environment(id::String, env::Environment)::Value
    if env === nothing
        error("AQSE 404 : identifier not found")
    elseif env.id == id
        return env.data
    else
        return find_in_environment(id, env.next)
    end
end

topEnvironment = Env("+", PrimV("+"),
Env("-", PrimV("-"),
Env("*", PrimV("*"),
Env("/", PrimV("/"),
Env("<=", PrimV("<="),
Env("equal?", PrimV("equal?"),
Env("true", BoolV(true),
Env("false", BoolV(false),
nothing))))))))

function interp(expr :: ExprC, env :: Environment) :: Value
    if isa(expr, NumC)
        NumV(expr.num)
    elseif isa(expr, StrC)
        StrV(expr.str)
    elseif isa(expr, IdC)
        find_in_environment(expt.id, env)
    end
end

function searlize(v :: Value) :: String
    if  isa(v, NumV)
        "$(v.val)"
    elseif isa(v, BoolV)
        v.val ? "true" : "false"
    elseif isa(v, StrV)
        v.val
    elseif isa(v, ClosV)
        "#<procedure>"
    elseif isa(v, PrimV)
        "#<primop>"
    end
end