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

function transduce(xform, f, from)
    g = xform(f)
    g(reduce(g, g(), from))
end

function into()
    vector()
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
    vector()
end

function conj(x)
    x
end

function concat(xs, ys)
    into(xs, ys)
end

function cat()
    function(emit)
        function inner()
            emit()
        end
        function inner(result)
            emit(result)
        end
        function inner(result, next)
            reduce(emit, result, next)
        end
        function inner(result, next::Base.Vector)
            Base.reduce(emit, next, init=result)
        end
        return inner
    end
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

function map(f, xs)
    into(vector(), map(f), xs)
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

function filter(p, xs)
    into(vector(), filter(p), xs)
end

function interpose(delim)
    function(emit)
        started = false
        function inner()
            emit()
        end
        function inner(res)
            emit(res)
        end
        function inner(res, next)
            if started
                return emit(emit(res, delim), next)
            else
                started = true
                return emit(res, next)
            end
        end
        return inner
    end
end

function partition(n)
    acc = vector()
    function(emit)
        function inner()
            emit()
        end
        function inner(result)
            if count(acc) > 0
                emit(result, acc)
            else
                emit(result)
            end
        end
        function inner(result, next)
            acc = conj(acc, next)
            if count(acc) == n
                t = acc
                acc = vector()
                emit(result, t)
            else
                emit(result)
            end
        end
        return inner
    end
end

function partition(n, xs)
    into(vector(), partition(n), xs)
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

function prepend(head)
    function (emit)
        function inner()
            reduce(emit, emit(), head)
        end
        function inner(res)
            emit(res)
        end
        function inner(res,next)
            emit(res, next)
        end
    end
end
