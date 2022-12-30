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
    emitter(env)(:default, Fn(name, slots, env, body))
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
    if eval(env, first(args)) === true
        eval(env, first(rest(args)))
    else
        eval(env, first(rest(rest(args))))
    end
end

##### continuation manipulating macros

function ground(env, body)
    function emit(ch, v)
       emitter(env, vector(ch, v))
    end
    eval(set_emit(env, emit), body)
end

function wire(env, args)
    m = first(args)
    body = first(rest(args))

    function emit(ch, v)
        listener = get(m, ch, nothing)
        if listener === nothing
            emitter(env)(ch, v)
        else
            eval(env, list(listener, v))
        end
    end
    eval(set_emit(env, emit), body)
end

function xprlemit(env, args)
    arg1 = first(args)
    @assert arg1 !== nil "Cannot emit nil."

    if count(args) == 1
        emitter(env)(:default, eval(env, arg1))
    else
        emitter(env)(arg1, eval(env, first(rest(args))))
    end

    return nothing
end
