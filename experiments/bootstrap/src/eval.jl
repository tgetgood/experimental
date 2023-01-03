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

function async_eval_send(env, form)
    ch = Channel()
    t = @async eval(set_emit(env, argemit(env, ch)), form)
    bind(ch, t)
    return ch
end

function async_eval_read(env, ch)
    try
        return take!(ch)
    catch e
        @info "Task exited without emitting a value"
        return nothing
    end
end

function eval_async(env, form)
    async_eval_read(env, async_eval_send(env, form))
end

function eval_seq_async(env, args)
    argcs = []

    while count(args) > 0
        arg = first(args)
        args = rest(args)
        push!(argcs, async_eval_send(env, arg))
    end

    ret = emptyvector

    for ch in argcs
        val = async_eval_read(env, ch)
        if val === nothing
            return nothing
        else
            ret = conj(ret, val)
        end
    end
    return ret
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
    vals = eval_seq_async(env, form)
    if vals !== nothing
        emitter(env)(default, vals)
    end
    return nothing
end

function eval(env, form::Map)
    ks = eval_seq_async(env, keys(form))
    if ks !== nothing
        vs = eval_seq_async(env, vals(form))
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
    s = eval_async(env, s)
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
    evargs = eval_seq_async(env, args)
    if evargs !== nothing
        val = f.jlfn(evargs...)
        if val !== nothing
            emitter(env)(default, val)
        end
    end
    return nothing
end

function apply(env, form::List, args)
    f = eval_async(env, form)
    if f !== nothing
        apply(env, f, args)
    end
    return nothing
end

function apply(env, f::Fn, args)
    evargs = eval_seq_async(env, args)
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

        v = eval_async(evenv, f.body)

        if v !== nothing
            emitter(evenv)(default, v)
        end
    end
    return nothing
end

function apply(env, m::Macro, args)
    evenv = extend(m.env, m.slots, args)

    expansion = eval_async(evenv, m.body)

    if expansion !== nothing
        eval(env, expansion)
    end

    return nothing
end
