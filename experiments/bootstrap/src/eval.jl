##### continuation management

function set_recursor(env, f)
    assoc(env, recursym, f)
end

function recursor(env)
    r = get(env, recursym, nil)
    @assert r !== nil "Can only recur within a function body"
    args -> apply(env, r, args)
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

function eval_stream(env, form)
    ch = emptystream()
    t = @async eval(set_emit(env, argemit(env, ch)), form)
    bind(ch, t)
    return ch
end

function eval_streams(env, args)
    into(emptyvector, map(v -> eval_stream(env, v)), args)
end

##### eval

function eval(env, form)
    emitter(env)(default, form)
    return nothing
end

function eval(env, form::Symbol)
    sym = lookup(env, form)
    if sym === nothing
        emitter(env)(
            keyword("error"),
            "Symbol " * string(form) * " not defined."
        )
    else
        emitter(env)(default, sym)
    end
    return nothing
end

function eval(env, form::Vector)
    vals = eval_streams(env, form)
    if vals !== nothing
        emitter(env)(default, vals)
    end
    return nothing
end

function eval(env, form::Map)
    ks = eval_streams(env, keys(form))
    if ks !== nothing
        vs = eval_streams(env, vals(form))
        if vs !== nothing
            emitter(env)(
                default,
                into(
                    emptymap,
                    map(e -> MapEntry(first(e), first(rest(e)))),
                    zip(ks, vs)
                )
            )
        end
    end
    return nothing
end

function eval(env, form::List)
    if count(form) == 0
        # The empty list is a value
        emitter(env)(default, form)
    else
        # N.B.: `apply` is called with unevaluated forms.
        apply(env, first(form), rest(form))
    end
    return nothing
end

##### apply

function apply(env, s::Symbol, args)
    s = eval_stream(env, s)
    if s !== nothing
        apply(env, s, args)
    end
    return nothing
end

# We need to leave it up to macros to continue as they see fit.
function apply(env, m::PrimitiveMacro, args)
    m.jlfn(env, args)
    return nothing
end

# But functions are often just proxies of jl fns at the moment, so they won't
function apply(env, f::PrimitiveFn, args)
    evargs = into(emptyvector, map(first), eval_streams(env, args))
    if evargs !== nothing
        val = f.jlfn(evargs...)
        if val !== nothing
            emitter(env)(default, val)
        end
    end
    return nothing
end

function apply(env, form::List, args)
    f = eval_stream(env, form)
    if f !== nothing
        apply(env, f, args)
    end
    return nothing
end

function apply(env, f::Fn, args)
    evargs = eval_streams(env, args)
    if evargs !== nothing
        evenv = extend(f.env, f.slots, evargs)

        # If f has a name, bind that name to f in the env in which f will be
        # invoked.
        # This allows basic recursion without cyclic references in the env.
        if f.name !== nothing
            evenv = extend(evenv, f.name, f)
        end

        # Lexical bindings, dynamic continuation
        evenv = set_emit(evenv, emitter(env))

        # Set the `recur` point whether the fn is named or not
        evenv = set_recursor(evenv, f)

        v = eval_stream(evenv, f.body)

        if v !== nothing
            emitter(evenv)(default, v)
        end
    end
    return nothing
end

function apply(env, m::Macro, args)
    evenv = extend(m.env, m.slots, args)

    expansion = eval_stream(evenv, m.body)

    if expansion !== nothing
        eval(env, expansion)
    end

    return nothing
end
