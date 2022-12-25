abstract type Vector end

abstract type PersistentVector <: Vector end

struct VectorLeaf <: PersistentVector
    elements::Base.Vector{Any}
end

struct VectorNode <: PersistentVector
    elements::Base.Vector{Any}
    count::Unsigned
end

emptyvector = VectorLeaf([])

function empty(x::PersistentVector)
    emptyvector
end

function count(v::VectorLeaf)
    length(v.elements)
end

function count(v::VectorNode)
    v.count
end

function length(v::Vector)
    count(v)
end

function fullp(v::VectorLeaf)
    count(v) == nodelength
end

function fullp(v::VectorNode)
    count(v) == nodelength && fullp(v.elements[end])
end

""" Returns `true` iff the collection `x` contains no elements. """
function emptyp(x)
    count(x) == 0
end

function conj(v::VectorLeaf, x)
    if fullp(v)
        return VectorNode([v, VectorLeaf([x])], nodelength + 1)
    else
        e = copy(v.elements)
        push!(e, x)
        return VectorLeaf(e)
    end
end

function conj(v::VectorNode, x)
    if fullp(v)
        return VectorNode([v, VectorLeaf([x])], v.count + 1)
    end

    elements = copy(v.elements)
    tail = v.elements[end]

    if fullp(tail)
        push!(elements, VectorLeaf([x]))
        return VectorNode(elements, v.count + 1)
    else
        newtail = conj(tail, x)
        elements[end] = newtail
        return VectorNode(elements, v.count + 1)
    end
end

function last(v::VectorLeaf)
    v.elements[end]
end

function last(v::VectorNode)
    last(v.elements[end])
end

function first(v::VectorLeaf)
    if count(v) > 0
        v.elements[begin]
    else
        nothing
    end
end

function first(v::VectorNode)
    if count(v) > 0
        first(v.elements[begin])
    else
        nothing
    end
end

function nth(v::VectorLeaf, n)
    if n > count(v) || n < 1
        throw("Index out of bounds")
    else
        return v.elements[n]
    end
end

function nth(v::VectorNode, n)
    if n > count(v) || n < 1
        throw("Index out of bounds")
    else
        # FIXME: This should be binary search, but I'm lazy
        for e in v.elements
            if count(e) >= n
                return nth(e, n)
            else
                n = n - count(e)
            end
        end
    end
end

function assoc(v::VectorLeaf, i, val)
    @assert 1 <= i && i <= nodelength "Index out of bounds"

    e = copy(v.elements)
    e[i] = val
    return VectorLeaf(e)
end

function assoc(v::VectorNode, i, val)
    @assert 1 <= i && i <= count(v) "Index out of bounds"

end

function zip(v1::Vector, v2::Vector)
    v = emptyvector
    for i = 1:min(count(v1), count(v2))
        v = conj(v, vector(nth(v1, i), nth(v2, i)))
    end
    return v
end

# FIXME: This method of iterating a vector doesn't allow the head to be
# collected and so will use more memory than expected when used in idiomatic
# lisp fashion. That should be fixed.
struct VectorSeq <: Vector
    v
    i
end

function count(v::VectorSeq)
    count(v.v) - v.i + 1
end

function seq(v::Vector)
    VectorSeq(v, 1)
end

function rest(v::Vector)
    if count(v) < 2
        return emptyvector
    else
        return VectorSeq(v, 2)
    end
end

function first(v::VectorSeq)
    nth(v.v, v.i)
end

function rest(v::VectorSeq)
    if v.i == count(v.v)
        return emptyvector
    else
        return VectorSeq(v.v, v.i + 1)
    end
end

function string(v::VectorSeq)
    "[" * transduce(map(string) ∘ interpose(" "), *, "", v) * "]"
end

function get(v::Vector, i)
    nth(v, i)
end

function reduce(f, init::Vector, coll::VectorLeaf)
    Base.reduce(f, coll.elements, init=init)
end

function reduce(f, init::Vector, coll::VectorNode)
    Base.reduce(
        (acc, x) -> reduce(f, acc, x),
        coll.elements,
        init=init
    )
end

function vector(args...)
    vec(args)
end

function vec(args)
    Base.reduce(conj, args, init=emptyvector)
end

function vec(v::Vector)
    v
end

function reverse(v::Vector)
    r = emptyvector
    for i = count(v):-1:1
        r = conj(r, nth(v, i))
    end
    r
end



function string(v::Vector)
    "[" * transduce(interpose(" ") ∘ map(string), *, "", v) * "]"
end

function iterate(v::Vector)
    first(v), rest(v)
end

function iterate(v::Vector, state)
    if count(state) == 0
        nothing
    else
        first(state), rest(state)
    end
end
