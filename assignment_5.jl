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

Sexp = Union{Array, Real, String}

function parse_AQSE(expr :: Sexp) :: ExprC
    if isa(expr, Real)
        NumC(expr)
    elseif isa(expr, String)
        if expr[1] == "'"
            IdC(expr)
        else
            StrC(expr)
        end
    elseif isa(expr, Array)
        if expr[1] == "'if"
            if length(expr) == 4
                IfC(parse_AQSE(expr[2]), parse_AQSE(expr[3]), parse_AQSE(expr[4]))
            else
                error("AQSE wrong arity for if")
            end
        elseif expr[1] == "'lam"
            if length(expr) == 3
                LamC(parse_AQSE(expr[3]), expr[2])
            else
                error("AQSE wrong arity for lam")
            end
        else
            AppC(parse_AQSE(expr[1]), getindex(expr, 2:length(expr)))
        end
    end
end

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