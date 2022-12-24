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

function eval(env, form::Map)
    into(
        emptymap,
        map(e -> MapEntry(eval(env, e.key), eval(env, e.value))),
        form
    )
end

function eval(env, form::List)
    if count(form) == 0
        # The empty list is a value
        form
    else
        # N.B.: `apply` is called with unevaluated forms.
        apply(env, first(form), rest(form))
    end
end

##### apply

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

    # If f has a name, bind that name to f in the env in which f will be
    # invoked.
    # This allows basic recursion without cyclic references in the env.
    if f.name !== nothing
        evenv = extend(evenv, f.name, f)
    end

    eval(evenv, f.body)
end

function apply(env, m::Macro, args)
    e = extend(m.env, m.slots, args)
    eval(env, eval(e, m.body))
end
