abstract type Queue end

struct PersistentQueue <: Queue
    front
    back
end

emptyqueue = PersistentQueue(emptyvector, emptyvector)

function queue(seq)
    PersistentQueue(seq, emptyqueue)
end

function count(q::PersistentQueue)
    return count(q.front) + count(q.back)
end

function emptyp(q::Queue)
    return count(q) == 0
end

function conj(q::PersistentQueue, x)
    if emptyp(q)
        return PersistentQueue(vector(x), emptyvector)
    else
        return PersistentQueue(q.front, conj(q.back, x))
    end
end

function rest(q::PersistentQueue)
    nf = rest(q.front)
    if emptyp(nf)
        return PersistentQueue(q.back, emptyvector)
    else
        return PersistentQueue(nf, q.back)
    end
end

function first(q::PersistentQueue)
    first(q.front)
end

function closedp(q::PersistentQueue)
    false
end

## Closed Queues

struct ClosedQueue <: Queue
    elements
end

closedempty = ClosedQueue(emptyqueue)

function closedp(q::ClosedQueue)
    true
end

function close(q::Queue)
    ClosedQueue(concat(q.front, q.back))
end

function first(q::ClosedQueue)
    first(q.elements)
end

function rest(q::ClosedQueue)
    ClosedQueue(rest(q.elements))
end

function string(q::PersistentQueue)
    # TODO: limit printing on large structures
    "<-<" * transduce(interpose(", "), *, "", concat(q.front, q.back)) * "<-<"
end

##### Cables

abstract type Cable end

struct StreamCable
    streams::Map
end

struct ValueCable
    value
    streams::Map
end

function get(x::StreamCable, k)
    get(x.streams, k)
end

function containsp(x::StreamCable, k)
    containsp(x.streams, k)
end

function closedp(x::StreamCable, k)
    @assert containsp(x, k) "Cannot check status of nonextant cable: " * k

    closedp(get(x, k))
end

# REVIEW: Maybe cables ought only be constructed in the interpreter methods.
function emit!(x::StreamCable, k, v)
    StreamCable(update(x.streams, k, conj, v))
end
