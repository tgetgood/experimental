syms = keyword("symbols")
meta = keyword("metadata")

# TODO: general destructuring

function extend(env::Map, binding::Symbol, val)
    update(env, syms, assoc, binding, val)
end

function extend(env::Map, bindings::Vector, vals)
    @assert isa(vals, Vector) || isa(vals, List) "Cannot destructure a " *
        typeof(vals) * " as a Vector."
    @assert count(bindings) <= count(vals) "Insufficient values for destructuring"

    for i in 1:count(bindings)
        env = extend(env, first(bindings), first(vals))
        bindings = rest(bindings)
        vals = rest(vals)
    end

    return env
end

function extend(env::Map, binding::Symbol, n::Nothing)
    env
end

function extend(env::Map, bindings::Map, vals::Map)
    reduce(
        (env, entry) -> extend(env, entry, vals),
        env,
        bindings
    )
end

function extend(env::Map, binding::MapEntry, val::Map)
    if binding.key == keyword("as")
        extend(env, binding.value, val)
    elseif binding.key == keyword("keys")
        reduce(
            # FIXME: namespaced keywords!
            (env, s) -> extend(env, s, get(val, keyword(name(s)))),
            env,
            binding.value
        )
    else
        extend(env, binding.key, get(val, binding.value))
    end
end

function setmeta(meta::Nothing, key, value)
    assoc(emptymap, key, value)
end

function setmeta(meta::Map, key, value)
    assoc(meta, key, value)
end

function withmeta(env, sym, key, value)
    update(env, meta, update, sym, setmeta, key, value)
end

function lookup(env, symbol)
    v = get(get(env, syms), symbol)
    @assert v !== nil "Unresolved symbol: " * string(symbol)
    return v
end
