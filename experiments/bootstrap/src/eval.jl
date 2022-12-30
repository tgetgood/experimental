##### continuation management

function set_emit(env, emit)
    assoc(env, emitsym, emit)
end

function emitter(env)
    e = get(env, emitsym)
    (ch, v) -> e(ch, v)
end

function argemit(env, c)
    return function(ch, v)
        if ch == :default
            put!(c, v)
        else
            emitter(env)(ch, v)
        end
    end
end

function eval_arg(env, arg)
    ch = Channel()
    @async eval(set_emit(env, argemit(env, ch)), arg)
    return take!(ch)
end

function eval_args(env, args)
    argcs = []

    for arg in args
        ch = Channel()
        push!(argcs, ch)
        @async eval(set_emit(env, argemit(env, ch)), arg)
    end

    Base.reduce((acc, x) -> conj(acc, take!(x)), argcs, init=emptyvector)
    end

function with_default_stream(env, form)
    s = emptystream()
    function emit(ch, v)
        if ch == :default
            put!(s.tail, v)
        else
            emitter(env)(ch, v)
        end
    end

    task(with_emit, env, emit, form)
    return s
end


##### eval

function eval(env, form)
    emitter(env)(:default, form)
end

function eval(env, form::Symbol)
    emitter(env)(:default, lookup(env, form))
end

function eval(env, form::Vector)
    vals = eval_args(env, form)
    emitter(env)(:default, vals)
end

function eval(env, form::Map)
    ks = eval_args(env, keys(form))
    vs = eval_args(env, vals(form))

    emitter(env)(
        :default,
        into(
            emptymap,
            map(e -> MapEntry(first(e), first(rest(e)))),
            zip(ks, vs)
        )
    )
end

function eval(env, form::List)
    if count(form) == 0
        # The empty list is a value
        emitter(env)(:default, form)
    else
        # N.B.: `apply` is called with unevaluated forms.
        apply(env, first(form), rest(form))
    end
end

##### apply

function apply(env, s::Symbol, args)
    s = eval_arg(env, s)
    apply(env, s, args)
end

# We need to leave it up to macros to continue as they see fit.
function apply(env, m::PrimitiveMacro, args)
    m.jlfn(env, args)
end

# But functions are often just proxies of jl fns at the moment, so they won't
function apply(env, f::PrimitiveFn, args)
    emitter(env)(
        :default,
        f.jlfn(eval_args(env, args)...)
    )
end

function apply(env, form::List, args)
    f = eval_arg(env, form)
    apply(env, f, args)
end

function apply(env, f::Fn, args)
    evenv = extend(f.env, f.slots, eval_args(env, args))

    # If f has a name, bind that name to f in the env in which f will be
    # invoked.
    # This allows basic recursion without cyclic references in the env.
    if f.name !== nothing
        evenv = extend(evenv, f.name, f)
    end

    # Lexical bindings, dynamic continuation
    evenv = set_emit(evenv, emitter(env))

    v = eval(evenv, f.body)

    if v !== nothing
        emitter(evenv)(:default, v)
    end
end

function apply(env, m::Macro, args)
    evenv = extend(m.env, m.slots, args)

    expansion = eval_arg(evenv, m.body)

    eval(env, expansion)
end
