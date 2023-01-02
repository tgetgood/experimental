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

function conj(v::Map, e::Nothing)
    v
end

# Clojure uses 8 and I don't want to dig into it just yet.
# Well actually, clojure uses alternating keys and values instead of an array of
# MapEntries which avoids an extra memory indirection. I should do that.
# TODO: Analysis
arraymapsizethreashold = 8

function get(m::Nothing, k)
    nil
end

function get(m::Map, k, default)
    v = get(m, k)
    if v === nothing
        default
    else
        v
    end
end

function get(m::PersistentArrayMap, k)
    for e in m.kvs
        if e != nil && e.key == k
            return e.value
        end
    end
    return nothing
end

function assoc(x::Nothing, k, v)
    assoc(emptymap, k, v)
end

function assoc(m::PersistentArrayMap, k, v)
    if count(m) > arraymapsizethreashold - 1
        return assoc(into(emptyhashnode, m), k, v)
    end

    n = emptyvector
    found = false
    for e in m.kvs
        if e === nil
            continue
        elseif e.key == k
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
    for e in m.kvs
        if e != nil && e.key != k
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

function containsp(m::Map, k)
    get(m, k) !== nothing
end

function nodewalkupdate(m::PersistentHashMap, entry::MapEntry, hash, level)
    i = first(hash) + 1
    node, added = nodewalkupdate(get(m.ht, i), entry, rest(hash), level + 1)
    n = assoc(
        m.ht,
        i,
        node
    )

    return PersistentHashMap(n, m.count + added), added
end

function nodewalkupdate(m::Nothing, entry::MapEntry, hash, level)
    entry, 1
end

function nodewalkupdate(m::MapEntry, entry::MapEntry, hs, level)
    mh = drop(level - 1, hashseq(m.key))
    if m.key == entry.key
        return entry, 0
    elseif first(mh) == first(hs)
        child = nodewalkupdate(emptyhashnode, m, hashseq(m.key), level + 1)
        child = nodewalkupdate(child, entry, hs, level + 1)

        parent = assoc(emptyhashnode.ht, first(mh) + 1, child)

        return PersistentHashMap(parent, 2), 1
    else
        ht = emptyhashnode.ht
        ht = assoc(ht, first(mh) + 1, m)
        ht = assoc(ht, first(hs) + 1, entry)
        return PersistentHashMap(ht, 2), 1
    end
end

function assoc(m::PersistentHashMap, k, v)
    if get(m, k) == v
        return m
    else
        return nodewalkupdate(m, MapEntry(k, v), hashseq(k), 1)[1]
    end
end

function dissoc(m::PersistentHashMap, k)
    throw("not implemented")
end

function seq(m::PersistentHashMap)
    # Produce VectorSeq of leaves
    into(emptyvector, map(seq) ∘ cat(), m.ht)
end

function seq(e::MapEntry)
    # FIXME: This boxing is only necessary because `cat` can't tell sequences
    # from scalars.
    vector(e)
end

function seq(x::Nothing)
    []
end

function first(m::PersistentHashMap)
    first(seq(m))
end

function rest(m::PersistentHashMap)
    rest(seq(m))
end

function update(m::Map, k, f, v...)
    assoc(m, k, f(get(m, k), v...))
end

function hashmap(args...)
    @assert length(args) % 2 == 0
    out = emptymap
    for i in 1:div(length(args), 2)
        out = assoc(out, args[2*i - 1], args[2*i])
    end
    return out
end

function merge(x::Map, y::Map)
    into(x, y)
end

function string(x::MapEntry)
    string(x.key) * " " * string(x.value)
end

function string(m::Map)
    inner = transduce(
        map(string) ∘ interpose(", "),
        *,
        "",
        m
    )
    return "{" * inner * "}"
end

function keys(m::Map)
    into(emptyvector, map(x -> x.key), m)
end

function vals(m::Map)
    into(emptyvector, map(x -> x.value), m)
end
