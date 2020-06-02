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
    args::Array{String}
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
    if isa(expr, NumC)
        NumV(expr.num)
    elseif isa(expr, StrC)
        StrV(expr.str)
    elseif isa(expr, IdC)
        find_in_environment(expr.id, env)
    elseif isa(exp, LamC)
        return ClosV(exp.args, exp.body, env)
    elseif isa(exp, IfC)
        testVal = interp(exp.test, env)
        if !isa(testVal, BoolV)
            error("AQSE: test expression must evaluate to a boolean type")
        elseif testVal.val
            return interp(exp.then, env)
        else
            return interp(exp.els, env)
        end
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

@test interp(NumC(7), topEnvironment) == NumV(7)
@test interp(NumC(9), topEnvironment) == NumV(9)
@test interp(StrC("Bad"), topEnvironment) == StrV("Bad")
@test interp(StrC("End"), topEnvironment) == StrV("End")
@test interp(IdC("+"), topEnvironment) == PrimV("+")
@test interp(IdC("true"), topEnvironment) == BoolV(true)

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

@test searlize(NumV(6)) == "6"
@test searlize(NumV(30)) == "30"
@test searlize(BoolV(true)) == "true"
@test searlize(BoolV(false)) == "false"
@test searlize(StrV("Hello")) == "Hello"
@test searlize(StrV("World")) == "World"
@test searlize(ClosV(["a", "b", "c"], NumC(90), topEnvironment)) == "#<procedure>"
@test searlize(ClosV(["z", "y", "x"], StrC("Nope"), topEnvironment)) == "#<procedure>"
@test searlize(PrimV("*")) == "#<primop>"
@test searlize(PrimV("+")) == "#<primop>"

  
function top_interp(expr :: ExprC) :: String
    searlize(interp(expr, topEnvironment))
end

@test top_interp(NumC(7)) == "7"
@test top_interp(NumC(16)) == "16"
@test top_interp(StrC("It's")) == "It's"
@test top_interp(StrC("Alive!")) == "Alive!"