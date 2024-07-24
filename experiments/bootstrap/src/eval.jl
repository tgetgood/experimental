the_event_queue = emptyqueue

function schedule(events)
    # Needs locking as currently set up
    enqueue(rest(events))
    yeildTo(first(events))
end

##### eval

function eval(env, form)
    emitter(env)(default, form)
end

function eval(env, s::Symbol)
    emitter(env)(default, lookup(env, s))
end

function eval(env, form::List)
    apply(env, first(form), rest(form))
end

#####

function apply(env, f::Symbol, args)
    default_emit(
        env,
        e -> eval(e, f),
        val -> apply(env, val, args)
    )
end

function appy(env, f::PrimitiveMacro, args)
    f.jlfn(env, args)
end

function apply(env, f::PrimitiveFn, args)
    default_emit(
        env,
        e -> map(x -> eval(e, x), args),
        v -> f.jlfn(v...)
    )
end
