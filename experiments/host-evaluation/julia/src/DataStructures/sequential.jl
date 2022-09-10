abstract type Sequence end

function reduce(f, coll)
    reduce(f, f(), coll)
end

# General reduce for anything sequential
function reduce(f, init, coll)
    if emptyp(coll)
        init
    else
        reduce(f, f(init, first(coll)), rest(coll))
    end
end

function transduce(xform, f, to, from)
    g = xform(f)
    # Don't forget to flush state after input terminates
    g(reduce(g, to, from))
end

function into()
    vec()
end

function into(x)
    x
end

function into(to, from)
    reduce(conj, to, from)
end

function into(to, xform, from)
    transduce(xform, conj, to, from)
end

function drop(n, coll)
    if n == 0
        coll
    else
        drop(n - 1, rest(coll))
    end
end

function take(n, coll)
    out = emptyvector
    s = coll
    for i in 1:n
        f = first(s)
        if f === nothing
            break
        else
            out = conj(out, f)
            s = rest(s)
        end
    end
    return out
end

function conj()
    vec()
end

function conj(x)
    x
end

function concat(xs, ys)
    into(xs, ys)
end

function map(f)
    function(emit)
        function inner()
            emit()
        end
        function inner(result)
            emit(result)
        end
        function inner(result, next)
            emit(result, f(next))
        end
        inner
    end
end

function filter(p)
    function(emit)
        function inner()
            emit()
        end
        function inner(result)
            emit(result)
        end
        function inner(result, next)
            if p(next) == true
                emit(result, next)
            else
                result
            end
        end
        inner
    end
end

function interpose(delim)
    function(emit)
        lag = nothing
        function inner()
            emit()
        end
        function inner(res)
            if lag !== nothing
                t = lag
                lag = nothing
                emit(res, t)
            else
                emit(res)
            end
        end
        function inner(res, next)
            if lag === nothing
                lag = next
                return emit(res)
            else
                t = lag
                lag = next
                return emit(emit(res, t), delim)
            end
        end
        return inner
    end
end

function dup(emit)
    function inner()
        emit()
    end
    function inner(acc)
        emit(acc)
    end
    function inner(acc, next)
        emit(emit(acc, next), next)
    end
    return inner
end
