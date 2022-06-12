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

function fullp(v::VectorLeaf)
    count(v) == nodelength
end

function fullp(v::VectorNode)
    count(v) == nodelength && fullp(v.elements[end])
end

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
    if n > count(v)
        throw("Index out of bounds")
    else
        return v.elements[n]
    end
end

function nth(v::VectorNode, n)
    if n > count(v)
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

# FIXME: This method of iterating a vector doesn't allow the head to be
# collected and so will use more memory than expected when used in idiomatic
# lisp fashion. That should be fixed.
struct VectorSeq
    v
    i
end

function count(v::VectorSeq)
    count(v.v) - v.i + 1
end

function rest(v::Vector)
    VectorSeq(v, 2)
end

function first(v::VectorSeq)
    nth(v.v, v.i)
end

function rest(v::VectorSeq)
    VectorSeq(v.v, v.i + 1)
end

function get(v::Vector, i)
    nth(v, i)
end

function reduce(f, init::Vector, coll::VectorLeaf)
    Base.reduce(f, coll.elements, init=init)
end

function reduce(f, init::Vector, coll::VectorNode)
    Base.reduce(
        (acc, x) -> Base.reduce(f, x, init=acc),
        coll.elements,
        init=init
    )
end

function vec(args...)
    Base.reduce(conj, args, init=emptyvector)
end
