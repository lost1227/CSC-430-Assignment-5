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

@test find_in_environment("true", topEnvironment) == BoolV(true)
@test_throws ErrorException("AQSE 404 : identifier not found") find_in_environment("does not exist", topEnvironment) === nothing

searlize(v :: Value) =
if isa(v, NumV)
    "$(v.val)"
end

function extend_env(args :: Array{String}, vals :: Array{Value}, env :: Environment)
    if length(args) != length(vals)
        error("AQSE: Mismatched arity!")
    end
    for i = 1:length(args)
        env = Env(args[i], vals[i], env)
    end
    return env
end

@test extend_env(["abc"], convert(Array{Value}, [StrV("abc")]), nothing) == Env("abc", StrV("abc"), nothing)

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

@test check_numeric_binop_valid_args(convert(Array{Value}, [NumV(10), NumV(20)])) === nothing
@test_throws ErrorException("AQSE: bad syntax: primop invalid arguments") check_numeric_binop_valid_args(convert(Array{Value}, [NumV(10), NumV(20), NumV(30)]))
@test_throws ErrorException("AQSE: bad syntax: primop invalid arguments") check_numeric_binop_valid_args(convert(Array{Value}, [NumV(10)]))
@test_throws ErrorException("AQSE: bad syntax: primop invalid arguments") check_numeric_binop_valid_args(convert(Array{Value}, [NumV(10), StrV("20")]))

function interp_primop(op :: String, args :: Array{Value})
    if op == "+"
        check_numeric_binop_valid_args(args)
        return NumV(args[1].val + args[2].val)
    elseif op == "-"
        check_numeric_binop_valid_args(args)
        return NumV(args[1].val - args[2].val)
    elseif op == "*"
        check_numeric_binop_valid_args(args)
        return NumV(args[1].val * args[2].val)
    elseif op == "/"
        check_numeric_binop_valid_args(args)
        return NumV(args[1].val / args[2].val)
    elseif op == "<="
        check_numeric_binop_valid_args(args)
        return BoolV(args[1].val <= args[2].val)
    elseif op == "equal?"
        if length(args) != 2
            error("AQSE: bad syntax: equal? invalid arguments")
        end
        return BoolV(args[1] == args[2])
    elseif op == "error"
        if length(args) != 1 || !isa(args[1], StrV)
            error("AQSE: bad syntax: error invalid arguments")
        end
        error("AQSE: error: $(args[1].val)")
    else
        error("AQSE: invalid primop")
    end
end

@test interp_primop("+", convert(Array{Value}, [NumV(10), NumV(20)])) == NumV(30)
@test interp_primop("-", convert(Array{Value}, [NumV(10), NumV(20)])) == NumV(-10)
@test interp_primop("*", convert(Array{Value}, [NumV(10), NumV(20)])) == NumV(200)
@test interp_primop("/", convert(Array{Value}, [NumV(10), NumV(20)])) == NumV(1/2)
@test interp_primop("<=", convert(Array{Value}, [NumV(10), NumV(20)])) == BoolV(true)
@test interp_primop("equal?", convert(Array{Value}, [NumV(10), NumV(20)])) == BoolV(false)
@test_throws ErrorException("AQSE: bad syntax: equal? invalid arguments") interp_primop("equal?", convert(Array{Value}, [NumV(10), NumV(20), NumV(20)]))
@test_throws ErrorException("AQSE: bad syntax: error invalid arguments") interp_primop("error", convert(Array{Value}, [NumV(10)]))
@test_throws ErrorException("AQSE: bad syntax: error invalid arguments") interp_primop("error", convert(Array{Value}, [StrV("abc"), StrV("def")]))
@test_throws ErrorException("AQSE: error: abc") interp_primop("error", convert(Array{Value}, [StrV("abc")]))

function interp(expr :: ExprC, env :: Environment) :: Value
    if isa(expr, NumC)
        NumV(expr.num)
    elseif isa(expr, StrC)
        StrV(expr.str)
    elseif isa(expr, IdC)
        find_in_environment(expr.id, env)
    elseif isa(expr, AppC)
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

function searlize(v :: Value) :: String
    if isa(v, NumV)
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

function top_interp(expr :: ExprC) :: String
    searlize(interp(expr, topEnvironment))
end
