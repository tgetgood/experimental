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

function emptyp(q::PersistentQueue)
    count(q.front) == 0 && count(q.back) == 0
end

## Closed Queues

struct ClosedQueue <: Queue
    elements
end

closedempty = ClosedQueue(emptyqueue)

function closedp(q::ClosedQueue)
    true
end

function close(q::PersistentQueue)
    ClosedQueue(concat(q.front, q.back))
end

function close(q::ClosedQueue)
    q
end

function first(q::ClosedQueue)
    first(q.elements)
end

function rest(q::ClosedQueue)
    ClosedQueue(rest(q.elements))
end

function count(q::ClosedQueue)
    count(q.elements)
end

function emptyp(q::ClosedQueue)
    count(q) == 0
end

function string(q::PersistentQueue)
    # TODO: limit printing on large structures
    "<-<" * transduce(interpose(", "), *, "", concat(q.front, q.back)) * "<-<"
end

## (Semi) Mutable Queues
#
# These are something of an odd beast. We want immutable semantics when reading
# queues, but not when writing. Consequently I've implemented `first`/`rest` to
# work as expected, but these queues do not support `conj`. Rather they have a
# method `put!` which extends the (possibly) shared tail of a queue.
#
# To avoid confusion, you can't call `put!` directly on a queue, so they appear
# to be read-only. Only by having a reference to the tail of the queue can you
# extend it.
#
# Of course these queues have references to their tails (it's conceivable that
# they could be engineered so as to have no knowledge of their tails, but I've
# yet to be that clever), which lets you hack around that. So I need discipline.

struct MutableTail
    lock::ReentrantLock
    queue::Base.Vector
    listeners::Base.Vector{WeakRef}
end

function readyp(t::MutableTail)
    length(t.queue) > 0
end

function rotateinternal(tail::MutableTail)
    for q in tail.listeners
        if q.value === nothing
            continue
        else
            q = q.value
            q.front = Base.reduce(conj, tail.queue, init=q.front)
        end
    end

    # Clean up GCed listeners
    Base.filter!(x -> x.value !== nothing, tail.listeners)

    empty!(tail.queue)
end

function rotate!(tail::MutableTail)
    lock(() -> rotateinternal(tail), tail.lock)
end

function listen!(tail::MutableTail, x)
    lock(() -> push!(tail.listeners, WeakRef(x)), tail.lock)
end

function put!(tail::MutableTail, v)
    lock(() -> push!(tail.queue, v), tail.lock)
end

mutable struct MutableTailQueue <: Queue
    front::Vector
    tail::MutableTail
end

# Multiple Queues can share a mutable tail.
#
# Unfortunately, this requires some complexity
function mtq(f, t)
    q = MutableTailQueue(f, t)
    listen!(t, q)
    return q
end

function mtq()
    mtq(emptyvector, MutableTail(ReentrantLock(), [], []))
end

function close(q::MutableTailQueue)
    xs = lock(() -> Base.reduce(conj, q.tail.queue, init=q.front), q.tail.lock)
    ClosedQueue(xs)
end

function emptyp(q::MutableTailQueue)
    # A queue with a mutable tail is never empty, since it's always *possible*
    # more data will be written to it. We're not concerned with what happens to
    # be enqueued just now.
    false
end

function first(q::MutableTailQueue)
    if emptyp(q.front)
        if !readyp(q.tail)
            # TODO: park
            throw("unimplemented")
        else
            rotate!(q.tail)
        end
    end
    return first(q.front)
end

function rest(q::MutableTailQueue)
    if emptyp(q.front)
        rotate!(q.tail)
    end
    mtq(rest(q.front), q.tail)
end


##### Streams

abstract type Stream end

struct ContinuationStream
    queue::MutableTailQueue
    receiver
end

function stream()
    q = mtq()
    function writer(v)
        put!(q.tail, v)
    end

    ContinuationStream(q, writer)
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
    if containsp(x.streams, k)
        get(x.streams, k).writer(v)
    else
        s = stream()
        s.writer(v)
        # I'm not sure this will work...
        StreamCable(assoc(x.streams, k, s))
    end
end

# function val(c::ValueCable)
#     c.value
# end

# function val(c::StreamCable)
#     get(c, :default)
# end

function aux(c::ValueCable)
    StreamCable(c.streams)
end

function aux(c::StreamCable)
    StreamCable(dissoc(c.streams, :default))
end
