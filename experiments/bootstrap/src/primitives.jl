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
    emitter(env)(default, Macro(first(args), env, first(rest(args))))
end

function xprlquote(env, args)
    emitter(env)(default, first(args))
end

function xprlfn(env, args)
    if length(args) == 3
        name, slots, body = args
    else
        slots, body = args
        name = nil
    end
    emitter(env)(default, Fn(name, slots, env, body))
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

    body = eval_async(env, form)
    if body !== nothing
        env = extend(env, sym, body)
        if doc !== nothing
            env = withmeta(env, sym, keyword("doc"), doc)
        end

        emitter(env)(keyword("env"), env)
        emitter(env)(default, sym)
    end
end

function xprlif(env, args)
    if eval_async(env, first(args)) === true
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

function emit(env, ch::Keyword, v)
    val = eval_async(env, v)
    if val !== nothing
        emitter(env)(ch, val)
    end
end

function emit(env, ch::Keyword, v, more...)
    @assert length(more) % 2 == 0 "emit requires an even number of arguments"

    e = emitter(env)
    e(ch, v)
    for i = 1:2:length(more)
        e(more[i], more[i+1])
    end
end

# The map form of `emit` takes keywords to vectors.
# for each key, each value of the corresponding vector is emitted individually
# and in order.
function emit(env, m::Map)
    for e in m
        k = e.key
        for v in m.value
            emit(env, k, v)
        end
    end
end

function emit(env, v::Nothing)
    @assert false "Cannot emit nil."
end


function xprlemit(env, args)
    emit(env, args...)
    return nothing
end
