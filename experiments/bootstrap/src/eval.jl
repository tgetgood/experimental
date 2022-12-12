using DataStructures
using DataStructures: Symbol, Vector, Map, List, first, get, map, count, reduce
import DataStructures: string

syms = keyword("symbols")
meta = keyword("metadata")

##### Interpreter internals

struct Fn
    slots::Vector
    env::Map
    body
end

function string(x::Fn)
    "#Fn" * string(hashmap(
        keyword("slots"), x.slots,
        keyword("env"), x.env,
        keyword("body"), x.body))
end

struct Macro
    slots::Vector
    env::Map
    body
end

function string(x::Fn)
    "#Macro" * string(hashmap(
        keyword("slots"), x.slots,
        keyword("env"), x.env,
        keyword("body"), x.body))
end

##### Primitives

struct PrimitiveMacro
    jlfn
end

struct PrimitiveFn
    jlfn
end

struct ModEnv
    env
    val
end

function xprlmacro(env, args)
    Macro(first(args), env, first(rest(args)))
end

function xprlfn(env, args)
    Fn(first(args), env, first(rest(args)))
end

function xprldef(env, args)
    sym = first(args)
    args = rest(args)
    if typeof(first(args)) == String
        doc = first(args)
        form = first(rest(args))
    else
        doc = nothing
        form = first(args)
    end

    env = assoc(env, syms, assoc(get(env, syms), sym, form))
    if doc !== nothing
        env = assoc(env, meta, assoc(get(env, meta), sym,
                                     assoc(emptymap, keyword("doc"), doc)))
    end

    return ModEnv(env, sym)
end

function xprlif(env, args)
    if eval(env, first(args)) == true
        eval(env, first(rest(args)))
    else
        eval(env, first(rest(rest(args))))
    end
end

##### Environment manipulation

function extend(env::Map, lhs, rhs)
    # TODO: general destructuring

    s = get(env, syms)
    while count(lhs) > 0
        s =  assoc(s, first(lhs), first(rhs))
        lhs = rest(lhs)
        rhs = rest(rhs)
    end

    return assoc(env, syms, s)
end

##### Initial environment

# Mappings in the initial environment are effectively built-in functions.

# They *can* be overridden, though probably shouldn't.

# These functions are *primitive*, in the sense that they cannot be implemented
# in the language they implement.


initenv = hashmap(
    syms, hashmap(
        symbol("def"), PrimitiveMacro(xprldef),
        symbol("fn"), PrimitiveMacro(xprlfn),
        symbol("quote"), PrimitiveMacro((env, x) -> first(x)),
        symbol("macro"), PrimitiveMacro(xprlmacro),
        symbol("if"), PrimitiveMacro(xprlif),
        symbol("+"), PrimitiveFn(+),
        symbol("-"), PrimitiveFn(-),
        symbol("*"), PrimitiveFn(*),
        symbol("="), PrimitiveFn(==),
        symbol(">"), PrimitiveFn(>),
        symbol("<"), PrimitiveFn(<),
        symbol("list"), PrimitiveFn(list),
        symbol("get"), PrimitiveFn(get),
        symbol("contains?"), PrimitiveFn(containsp),
        symbol("empty?"), PrimitiveFn(emptyp),
        symbol("first"), PrimitiveFn(first),
        symbol("take"), PrimitiveFn(take),
        symbol("rest"), PrimitiveFn(rest),
        symbol("assoc"), PrimitiveFn(assoc)
    ),
    meta, hashmap()
)

function lookup(env, symbol)
    v = get(get(env, syms), symbol)
    @assert v != nil "Unresolved symbol: " * string(symbol)
    return v
end

##### eval

function eval(env, form)
    form
end

function eval(env, form::Symbol)
    lookup(env, form)
end

function eval(env, form::Vector)
    into(emptyvector, map(x -> eval(env, x)), form)
end

function eval(env, form::List)
    # N.B.: `apply` is called with unevaluated forms.
    apply(env, first(form), rest(form))
end

##### Apply

function apply(env, s::Symbol, args)
    apply(env, eval(env, s), args)
end

function apply(env, m::PrimitiveMacro, args)
    m.jlfn(env, args)
end

function apply(env, f::PrimitiveFn, args)
    f.jlfn(into(emptyvector, map(x -> eval(env, x)), args)...)
end

function apply(env, form::List, args)
    apply(env, eval(env, form), args)
end

function apply(env, f::Fn, args)
    vals = into(emptyvector, map(x -> eval(env, x)), args)

    evenv = extend(f.env, f.slots, vals)

    eval(evenv, f.body)
end

function apply(env, m::Macro, args)
    e = extend(m.env, m.slots, args)
    eval(env, eval(e, m.body))
end
