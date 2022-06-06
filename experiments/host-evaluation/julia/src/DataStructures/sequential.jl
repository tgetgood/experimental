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
    reduce(xform(f), to, from)
end

function into(from, to)
    reduce(conj, from, to)
end

function into(from, xform, to)
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
