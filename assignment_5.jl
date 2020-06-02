using Test

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

# me
struct AppC
    funexpr
    args::Array{Any}
    AppC(body, args) = new(body, args)
end
# end me

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


function find_in_environment(id::String, env::Environment)::Union{Value, Nothing}
    if env === nothing
        return nothing
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

@test find_in_environment("true", topEnvironment) == BoolV(true)
@test find_in_environment("does not exist", topEnvironment) === nothing

searlize(v :: Value) =
if isa(v, NumV)
    "$(v.val)"
end

function extend_env(args :: Array{String}, vals :: Array{Value}, env :: Environment)
    if length(args) != length(vals)
        error("AQSE: Mismatched arity!")
    end
    for i = 1:length(args)
        env = Environment(args[i], vals[i], env)
    end
    return env
end

function check_numeric_binop_valid_args(args :: Array{Value})
    if length(args) != 2
        error("AQSE: bad syntax: primop invalid arguments")
    end
    arg1 = args[1]
    arg2 = args[2]
    if !isa(arg1, NumV) || !isa(arg2, NumV)
        error("AQSE: bad syntax: primop invalid arguments")
    end
end

function interp_primop(op :: String, args :: Array{Value})
    if op == "+"
        check_numeric_binop_valid_args(args)
        return args[0].val + args[1].val
    elseif op == "-"
        check_numeric_binop_valid_args(args)
        return args[0].val - args[1].val
    elseif op == "*"
        check_numeric_binop_valid_args(args)
        return args[0].val * args[1].val
    elseif op == "/"
        check_numeric_binop_valid_args(args)
        return args[0].val / args[1].val
    elseif op == "<="
        check_numeric_binop_valid_args(args)
        return args[0].val <= args[1].val
    elseif op == "equal?"
        if length(args) != 2
            error("AQSE: bad syntax: equal? invalid arguments")
        end
        return args[0] == args[1]
    elseif op == "error"
        if length(args < 1) || !isa(args[1], String)
            error("AQSE: bad syntax: error invalid arguments")
        end
        error("AQSE: error: $(args[1].val)")
    else
        error("AQSE: invalid primop")
    end
end

function interp(expr :: ExprC, env :: Environment) :: Value
    if isa(expr, AppC)
        clos :: Value = interp(expr.funexpr, env)
        argvals :: Array{Value} = map(arg -> interp(arg, env), expr.args)
        if isa(clos, ClosV)
            new_env = extend_env(clos.args, argvals, env)
            return interp(clos.body, new_env)
        elseif isa(clos, PrimV)
            interp_primop(clos.op, env)
        else
            error("AQSE: Not a function or primop")
        end
    end
end
