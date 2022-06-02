abstract type Vector end

abstract type PersistentVector <: Vector end

nodelength = 32

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

function empty(x::typeof(Vector))
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

function emptyp(x::PersistentVector)
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
        return VectorNode([v, VectorLeaf([x])], v.total + 1)
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

function nth(v::VectorLeaf, n::Int)
    if n > count(v)
        throw("Index out of bounds")
    else
        return v.elements[n]
    end
end

function nth(v::VectorNode, n::Int)
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
