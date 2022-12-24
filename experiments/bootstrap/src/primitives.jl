##### Interpreter internals

struct ModEnv
    env
    val
end

struct Fn
    name
    slots::Vector
    env::Map
    body
end

function string(x::Fn)
    "#Fn" * string(hashmap(
        keyword("name"), x.name,
        keyword("slots"), x.slots,
        keyword("env"), "...elided...",
        keyword("body"), x.body))
end

struct Macro
    slots::Vector
    env::Map
    body
end

function string(x::Macro)
    "#Macro" * string(hashmap(
        keyword("slots"), x.slots,
        keyword("env"), "...elided...",
        keyword("body"), x.body))
end

##### Primitives

struct PrimitiveMacro
    jlfn
end

struct PrimitiveFn
    jlfn
end

function xprlmacro(env, args)
    Macro(first(args), env, first(rest(args)))
end

function xprlfn(env, args)
    if length(args) == 3
        name, slots, body = args
    else
        slots, body = args
        name = nil
    end
    Fn(name, slots, env, body)
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

    env = extend(env, sym, eval(env, form))
    if doc !== nothing
        env = withmeta(env, sym, keyword("doc"), doc)
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
