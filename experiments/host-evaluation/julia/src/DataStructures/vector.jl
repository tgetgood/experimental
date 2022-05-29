abstract type Vector end

abstract type PersistentVector <: Vector end

nodelength = 32

struct VectorLeaf <: PersistentVector
    last::UInt8
    elements::Base.Vector
end

struct VectorNode <: PersistentVector
    last::UInt8
    elements::Base.Vector
    count::Unsigned
end

emptyvector = PersistentVector(0, VectorLeaf(0, []))

function empty(x::PersistentVector)
    emptyvector
end

function empty(x::typeof(Vector))
    emptyvector
end

function count(v::VectorLeaf)
    v.last
end

function count(v::VectorNode)
    v.count
end

function fullp(v::VectorLeaf)
    v.last == nodelength
end

function fullp(v::VectorNode)
    v.last == nodelength && fullp(v.elements[v.last])
end

function emptyp(x::PersistentVector)
    count(x) == 0
end

function conj(v::VectorLeaf, x)
    if fullp(v)
        return VectorNode(2, [v, VectorLeaf(1, [x])], nodelength + 1)
    else
        e = copy(v.elements)
        push!(e, x)
        return VectorLeaf(v.last + 1, e)
    end
end

function conj(v::VectorNode, x)
    if fullp(v)
        return VectorNode(2, [v, VectorLeaf(1, [x])], v.total + 1)
    end

    elements = copy(v.elements)
    tail = elements[v.last]

    if fullp(tail)
        push!(elements, VectorLeaf(1, [x]))
        return VectorNode(v.last + 1, elements)
    else
        newtail = conj(tail, x)
        elements[v.last] = newtail
        return VectorNode(v.last, elements)
    end
end

function conj(v::PersistentVector, x)
    PersistentVector(v.length + 1, conj(v.root, x))
end

function first(v::PersistentVector)
    if emptyp(v)
        nothing
    else
        first(v.root)
    end
end

function first(v::VectorLeaf)
    if v.last > 0
        v.elements[1]
    else
        nothing
    end
end

function first(v::VectorNode)
    if v.last > 0
        first(v.elements[1])
    else
        nothing
    end
end

function nth(v::PersistentVector, n::Unsigned)
