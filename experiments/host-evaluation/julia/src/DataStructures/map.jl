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

function emptyhashnodef()
    v = emptyvector
    for i in 1:32
        v = conj(v, nil)
    end
    PersistentHashMap(v, 0)
end

emptyhashnode = emptyhashnodef()

struct HashSeq
    hash
    current
end

"""Returns a seq of chunks of `hashbits` bits.
Should be an infinite seq, but in the present implementation runs out after 64
bits."""
function hashseq(x)
    HashSeq(hash(x), 1)
end

function first(s::HashSeq)
    if s.current > 14
        # We could return nothing, but that will just lead to an error when it's
        # used which will be hard to debug unless I remember this...
        throw("FIXME: hash streams not implemented")
    else
        s.hash << ((s.current - 1) * hashbits) >> (64 - hashbits)
    end
end

function rest(s::HashSeq)
    HashSeq(s.hash, s.current + 1)
end

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
        if e.key == k
            return e.value
        else
            return nothing
        end
    end
end

function assoc(m::PersistentArrayMap, k, v)
    if count(m) > arraymapsizethreashold - 1
        return assoc(into(emptyhashnode, m), k, v)
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

function dissoc(m::PersistentArrayMap, k)
    out = emptymap
    for e in m.kvs.elements
        if e.key != k
            out = conj(out, e)
        end
    end
    return PersitentArrayMap(out)
end

function first(m::PersistentArrayMap)
        first(m.kvs)
end

function rest(m::PersistentArrayMap)
    rest(m.kvs)
end

function nodewalk(node::MapEntry, target, hash)
    if node.key == target
        return node.value
    else
        return nothing
    end
end

function nodewalk(node::PersistentHashMap, target, hash)
    # And here I thought I didn't need cardinal indicies...
    i = first(hash) + 1
    n = get(node.ht, i)
    if n === nothing || n == undef
        nothing
    else
        nodewalk(n, target, rest(hash))
    end
end

function get(m::PersistentHashMap, k)
    nodewalk(m, k, hashseq(k))
end

function containsp(m::PersistentHashMap, k)
    get(m, k) !== nothing
end

function nodewalkupdate(m::PersistentHashMap, entry, hash, level)
    i = first(hash) + 1
    n = assoc(
        m.ht,
        i,
        nodewalkupdate(get(m.ht, i), entry, rest(hash), level + 1)
    )
    return PersistentHashMap(n, m.count + 1)
end

function nodewalkupdate(m::Nothing, entry, hash, level)
    entry
end

function nodewalkupdate(m::MapEntry, entry, hs, level)
    mh = drop(level - 1, hashseq(m.key))
    if first(mh) == first(hs)
        boom
    else
        ht = emptyhashnode.ht
        ht = assoc(ht, first(mh) + 1, m)
        ht = assoc(ht, first(hs) + 1, entry)
        return PersistentHashMap(ht, 2)
    end
end

function assoc(m::PersistentHashMap, k, v)
    if get(m, k) == v
        return m
    else
        return nodewalkupdate(m, MapEntry(k, v), hashseq(k), 1)
    end
end

function dissoc(m::PersistentHashMap, k)
    throw("not implemented")
end

function hashmap(args...)
    @assert length(args) % 2 == 0
    out = emptymap
    for i in 1:div(length(args), 2)
        out = assoc(out, args[2*i - 1], args[2*i])
    end
    return out
end
