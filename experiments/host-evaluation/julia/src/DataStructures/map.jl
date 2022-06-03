abstract type Map end

struct MapEntry
    key::Any
    value::Any
end

struct PersistentArrayMap <: Map
    kvs::Vector
end

emptymap = PersistentArrayMap(emptyvector)

struct PersistentHashMap <: Map
    ht::Vector
    count::Unsigned
end

"""Returns the `n`th chunk of `hashbits` bits in hash of `x`"""
function hashchunk(h, n)
    # When this starts failing, it means we need an extensible hash algo.
    @assert 0 < n < 14

    h << ((n - 1) * hashbits) >> (64 - hashbits)
end

function emptyhashnodef()
    v = emptyvector
    for i in 1:32
        v = conj(v, nil)
    end
    PersistentHashMap(v, 0)
end

emptyhashnode = emptyhashnodef()

function empty(m::PersistentArrayMap)
    emptymap
end

function empty(m::PersistentHashMap)
    emptyhashnode
end

function count(m::PersistentArrayMap)
    count(m.kvs)
end

function count(m::PersistentHashMap)
    m.count
end

function emptyp(m::Map)
    count(m) == 0
end

function conj(v::Map, e::MapEntry)
    assoc(v, e.key, e.value)
end

# Copied from Clojure source without any analysis (clojure stores keys and
# values in alternation as opposed to map entries)
# TODO: Analysis
arraymapsizethreashold = 8

function get(m::PersistentArrayMap, k)
    for e in m.kvs.elements
        if m.key == k
            return m.value
        else
            return nothing
        end
    end
end

function assoc(m::PersistentArrayMap, k, v)
    if count(m) > arraymapsizethreashold - 1
        return assoc(tohashmap(m), k, v)
    end
    n = emptyvector
    found = false
    for e in m.kvs.elements
        if e.key == k
            n = conj(n, MapEntry(k, v))
            found = true
        else
            n = conj(n, e)
        end
    end

    if !found
        n = conj(n, MapEntry(k, v))
    end

    return PersistentArrayMap(n)
end

function nodewalk(node::MapEntry, target, hash, level)
    if node.key == target
        return node.value
    else
        return nothing
    end
end

function nodewalk(node::PersistentHashMap, target, hash, level)
    i = hashchunk(hash, level)
    n = get(node.ht, i)
    if n == nothing || n == undef
        nothing
    else
        nodewalk(n, target, hash, level + 1)
    end
end

function get(m::PersistentHashMap, k)
    nodewalk(m, k, hash(k), 1)
end

function nodewalkupdate(n::Nothing, entry, hash, level)
    entry
end


function assoc(m::PersistentHashMap, k, v)
    nodewalkupdate(m, MapEntry(k, v), hash(k), 1)
end
