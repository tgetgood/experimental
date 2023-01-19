function set_recursor(env, f)
    assoc(env, recursym, f)
end

function recursor(env, args)
    r = get(env, recursym, nil)
    @assert r !== nil "Can only recur within a function body"
    apply(env, r, args)
end

function set_emit(env, emit)
    assoc(env, emitsym, emit)
end

function emitter(env)
    get(env, emitsym)
end

function argemit(env, c)
    return function(ch, v)
        if ch == default
            put!(c, v)
        else
            emitter(env)(ch, v)
        end
    end
end

##### Interpreter internals

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
            env = updatemeta(env, sym, keyword("doc"), doc)
        end

        emitter(env)(keyword("env"), env)
        emitter(env)(default, sym)
    end
end

function xprlif(env, args)
    p = eval_async(env, first(args))
    if p === true
        eval(env, first(rest(args)))
    elseif count(args) == 3
        if p === false
            eval(env, first(rest(rest(args))))
        else
            @assert false "Only boolean values can be used as predicates."
        end
    else
        return nothing
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

function emit(env, ch, v)
    key = eval_async(env, ch)
    val = eval_async(env, v)
    if val !== nothing
        emitter(env)(key, val)
    end
end

function emit(env, ch, v, more...)
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
    while !emptyp(m)
        e = first(m)
        k = e.key
        for v in e.value
            emit(env, k, v)
        end
        m = rest(m)
    end
end

function emit(env, v::Nothing)
    @assert false "Cannot emit nil."
end


function xprlemit(env, args)
    emit(env, args...)
    return nothing
end

## `recur` is a funny thing here. Emission and recursion are bundled into a
## forking operation. Effectively a normal `emit` where one of the messages goes
## back to the sender's entry point.
##
## That would be the aesthetically pleasing way to implement this, but after
## more false starts than I care to admit, I'm ready do something else before
## trying again.

function xprlrecur(env, args)
    a1 = first(args)
    if first(a1) == emitsym
        emitargs = eval_seq_async(env, rest(a1))

        emit(env, emitargs...)
        args = rest(args)
    end

    recursor(env, args)
end

function debug_arg_emit(env, s)
    return function(ch, v)
        if ch == default
            put!(s, v)
        else
            emitter(env)(ch, v)
        end
    end
end

function xprlstream(env, args)
    body = first(args)

    s = emptystream()
    @async emitter(env)(default, s)

    evenv = set_emit(env, debug_arg_emit(env, s))

    eval(evenv, body)
end
