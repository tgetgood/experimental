function extend(env::Map, binding::Symbol, val)
    update(env, syms, assoc, binding, val)
end

function extend(env::Map, bindings::Vector, vals)
    @assert isa(vals, Vector) || isa(vals, List) "Cannot destructure a " *
        string(typeof(vals)) *
        " as a Vector."
    @assert count(bindings) <= count(vals) "Insufficient values for destructuring"

    for i in 1:count(bindings)
        s = first(bindings)
        if s == symbol("&")
             env = extend(env, first(rest(bindings)), vals)
            break
        else
            env = extend(env, s, first(vals))
            bindings = rest(bindings)
            vals = rest(vals)
        end
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
            # REVIEW: This binds namespaced keywords to namespaced (local)
            # symbols. In theory this could lead to weird shadowing, but in
            # practice I think it might be the right thing to do. We'll see...
            (env, s) -> extend(env, s, get(val, keyword(s))),
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
