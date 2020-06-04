using Test

# ExprC types
struct NumC
    num::Number
end

struct StrC
    str::String
end

struct IfC
    test
    then
    els
end

struct AppC
    funexpr
    args::Array{Any}
end

struct LamC
    body
    args::Array{String}
end

struct IdC
    id::String
end

ExprC = Union{NumC, StrC, IfC, AppC, LamC, IdC}

# Value Types
struct NumV
    val :: Real
end

struct BoolV
    val :: Bool
end

struct StrV
    val :: String
end

struct ClosV
    args :: Array{String}
    body :: ExprC
    env
end

struct PrimV
    op :: String
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
Env("error", PrimV("error"), 
nothing)))))))))

function extend_env(args :: Array{String}, vals :: Array{Value}, env :: Environment)
    if length(args) != length(vals)
        error("AQSE: Mismatched arity!")
    end
    for i = 1:length(args)
        env = Env(args[i], vals[i], env)
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
        return NumV(args[1].val + args[2].val)
    elseif op == "-"
        check_numeric_binop_valid_args(args)
        return NumV(args[1].val - args[2].val)
    elseif op == "*"
        check_numeric_binop_valid_args(args)
        return NumV(args[1].val * args[2].val)
    elseif op == "/"
        check_numeric_binop_valid_args(args)
        if args[2].val == 0
            error("AQSE: arithmetic error: cannot divide by zero")
        end
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
        if length(args) != 1
            error("AQSE: bad syntax: error invalid arguments")
        end
        error("AQSE: error: $(args[1].val)")
    else
        error("AQSE: invalid primop")
    end
end

function interp(expr :: ExprC, env :: Environment) :: Value
    if isa(expr, NumC)
        return NumV(expr.num)
    elseif isa(expr, StrC)
        return StrV(expr.str)
    elseif isa(expr, IdC)
        return find_in_environment(expr.id, env)
    elseif isa(expr, LamC)
        return ClosV(expr.args, expr.body, env)
    elseif isa(expr, IfC)
        testVal = interp(expr.test, env)
        if !isa(testVal, BoolV)
            error("AQSE: test expression must evaluate to a boolean type")
        elseif testVal.val
            return interp(expr.then, env)
        else
            return interp(expr.els, env)
        end
    elseif isa(expr, AppC)
        clos :: Value = interp(expr.funexpr, env)
        argvals :: Array{Value} = map(arg -> interp(arg, env), expr.args)
        if isa(clos, ClosV)
            new_env = extend_env(clos.args, argvals, env)
            return interp(clos.body, new_env)
        elseif isa(clos, PrimV)
            interp_primop(clos.op, argvals)
        else
            error("AQSE: Not a function or primop")
        end
    end
end

function serialize(v :: Value) :: String
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
    serialize(interp(expr, topEnvironment))
end

# test find_in_environment
@test find_in_environment("true", topEnvironment) == BoolV(true)
@test_throws ErrorException("AQSE 404 : identifier not found") find_in_environment("does not exist", topEnvironment)

# test extend_env
@test extend_env(["abc"], convert(Array{Value}, [StrV("abc")]), nothing) == Env("abc", StrV("abc"), nothing)
@test_throws ErrorException("AQSE: Mismatched arity!") extend_env(["a", "b"], convert(Array{Value}, [NumV(10)]), topEnvironment)

# test check_numeric_binop_valid_args
@test check_numeric_binop_valid_args(convert(Array{Value}, [NumV(10), NumV(20)])) === nothing
@test_throws ErrorException("AQSE: bad syntax: primop invalid arguments") check_numeric_binop_valid_args(convert(Array{Value}, [NumV(10), NumV(20), NumV(30)]))
@test_throws ErrorException("AQSE: bad syntax: primop invalid arguments") check_numeric_binop_valid_args(convert(Array{Value}, [NumV(10)]))
@test_throws ErrorException("AQSE: bad syntax: primop invalid arguments") check_numeric_binop_valid_args(convert(Array{Value}, [NumV(10), StrV("20")]))

# test interp_primop
@test interp_primop("+", convert(Array{Value}, [NumV(10), NumV(20)])) == NumV(30)
@test interp_primop("-", convert(Array{Value}, [NumV(10), NumV(20)])) == NumV(-10)
@test interp_primop("*", convert(Array{Value}, [NumV(10), NumV(20)])) == NumV(200)
@test interp_primop("/", convert(Array{Value}, [NumV(10), NumV(20)])) == NumV(1/2)
@test interp_primop("<=", convert(Array{Value}, [NumV(10), NumV(20)])) == BoolV(true)
@test interp_primop("equal?", convert(Array{Value}, [NumV(10), NumV(20)])) == BoolV(false)
@test interp_primop("equal?", convert(Array{Value}, [NumV(10), NumV(10)])) == BoolV(true)
@test interp_primop("equal?", convert(Array{Value}, [BoolV(true), BoolV(false)])) == BoolV(false)
@test interp_primop("equal?", convert(Array{Value}, [BoolV(false), BoolV(false)])) == BoolV(true)
@test interp_primop("equal?", convert(Array{Value}, [StrV("abc"), StrV("def")])) == BoolV(false)
@test interp_primop("equal?", convert(Array{Value}, [StrV("abc"), StrV("abc")])) == BoolV(true)
@test_throws ErrorException("AQSE: bad syntax: equal? invalid arguments") interp_primop("equal?", convert(Array{Value}, [NumV(10), NumV(20), NumV(20)]))
@test_throws ErrorException("AQSE: bad syntax: error invalid arguments") interp_primop("error", convert(Array{Value}, [StrV("abc"), StrV("def")]))
@test_throws ErrorException("AQSE: error: abc") interp_primop("error", convert(Array{Value}, [StrV("abc")]))
@test_throws ErrorException("AQSE: arithmetic error: cannot divide by zero") interp_primop("/", convert(Array{Value}, [NumV(10), NumV(0)]))

# test interp
@test interp(NumC(7), topEnvironment) == NumV(7)
@test interp(NumC(9), topEnvironment) == NumV(9)
@test interp(StrC("abc"), topEnvironment) == StrV("abc")
@test interp(StrC("End"), topEnvironment) == StrV("End")
@test interp(IdC("+"), topEnvironment) == PrimV("+")
@test interp(IdC("true"), topEnvironment) == BoolV(true)
@test_throws ErrorException("AQSE 404 : identifier not found") interp(IdC("DNE"), topEnvironment)

@test interp(IfC(IdC("true"), NumC(9), NumC(3)), topEnvironment) == NumV(9)
@test interp(IfC(IdC("false"), NumC(9), NumC(3)), topEnvironment) == NumV(3)
@test_throws ErrorException("AQSE: test expression must evaluate to a boolean type") interp(IfC(NumC(10), NumC(9), NumC(3)), topEnvironment)

test_expr = interp(LamC(NumC(9), ["x", "y"]), Env("x", NumV(9), nothing))
@test typeof(test_expr) == ClosV
@test test_expr.args == ["x", "y"]
@test test_expr.body == NumC(9)
@test test_expr.env == Env("x", NumV(9), nothing)

test_expr = interp(LamC(StrC("hello there"), ["o", "b"]), Env("z", StrV("hello"), nothing))
@test typeof(test_expr) == ClosV
@test test_expr.args == ["o", "b"]
@test test_expr.body == StrC("hello there")
@test test_expr.env == Env("z", StrV("hello"), nothing)

@test interp(AppC(LamC(NumC(10), []), []), topEnvironment) == NumV(10)
@test interp(AppC(LamC(AppC(IdC("*"), [IdC("+"), IdC("+")]), ["+"]), [NumC(3)]), topEnvironment) == NumV(9)
@test_throws ErrorException("AQSE: error: 10") interp(AppC(IdC("error"), [NumC(10)]), topEnvironment)
@test_throws ErrorException("AQSE: Not a function or primop") interp(AppC(NumC(10), []), topEnvironment)

# test serialize
@test serialize(NumV(6)) == "6"
@test serialize(NumV(30)) == "30"
@test serialize(BoolV(true)) == "true"
@test serialize(BoolV(false)) == "false"
@test serialize(StrV("Hello")) == "Hello"
@test serialize(StrV("World")) == "World"
@test serialize(ClosV(["a", "b", "c"], NumC(90), topEnvironment)) == "#<procedure>"
@test serialize(ClosV(["z", "y", "x"], StrC("Nope"), topEnvironment)) == "#<procedure>"
@test serialize(PrimV("*")) == "#<primop>"
@test serialize(PrimV("+")) == "#<primop>"

# test top_interp
@test top_interp(NumC(7)) == "7"
@test top_interp(NumC(16)) == "16"
@test top_interp(StrC("It's")) == "It's"
@test top_interp(StrC("Alive!")) == "Alive!"

@test top_interp(IfC(IdC("true"), NumC(19), NumC(17))) == "19"
@test top_interp(IfC(IdC("false"), StrC("Goodbye"), StrC("Hello"))) == "Hello"
@test top_interp(LamC(StrC("hello there"), ["o", "b"])) == "#<procedure>"
@test top_interp(LamC(NumC(9), ["x", "y"])) == "#<procedure>"
@test top_interp(AppC(LamC(NumC(10), []), [])) == "10"
@test top_interp(AppC(LamC(AppC(IdC("*"), [IdC("+"), IdC("+")]), ["+"]), [NumC(3)])) == "9"
@test top_interp(IdC("+")) == "#<primop>"
@test top_interp(IdC("-")) == "#<primop>"

@test top_interp(
    AppC(LamC(AppC(IdC("pow"), [IdC("pow"), NumC(2), NumC(10)]),
            ["pow"]),
        [LamC(IfC(AppC(IdC("equal?"), [IdC("power"), NumC(0)]),
                NumC(1),
                AppC(IdC("*"),
                    [IdC("base"), 
                    AppC(IdC("self"), 
                        [IdC("self"),
                        IdC("base"),
                        AppC(IdC("-"), [IdC("power"), NumC(1)])])])),
            ["self", "base", "power"])])) == "1024"
