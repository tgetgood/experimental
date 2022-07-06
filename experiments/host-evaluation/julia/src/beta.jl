# module Operators

import Base: string

import Main.DataStructures: vec, map, nil, assoc, emptymap, hashmap, MapEntry, Map, into, first, rest, keyword, transduce, conj, reduce, merge, Keyword, name, empty, Vector, emptyvector, count, get, vals

state = keyword("state")
in    = keyword("in")
out   = keyword("out")

struct Beta
    ins
    outs
    lambda
end

# In order to be able to link up βs into a graph, we need to know what the in
# and out channels are right now. There's nothing stopping us from replacing a β
# with a new one which can emit to more places, but that's a new entity.
function beta(in, out, body)
    Beta(in, out, body)
end

function string(x::Beta)
    string(hashmap(keyword("in"), x.ins, keyword("out"), x.outs, keyword("body"), x.lambda))
end

function network(m, ws)
    hashmap(keyword("networks"), m, keyword("wires"), ws)
end

function network(n::Keyword, β::Beta)
    network(hashmap(n, β), vec())
end


function ln(body)
    network(
        hashmap(
            keyword("main"),
            beta(vec(in), vec(out), e -> x -> e(reduce(conj, vec(out), body(get(x, in)))))
        ),
    vec()
    )
end

emptynetwork = network(emptymap, emptyvector)

# function emptyp(x::Network)
#     x == emptynetwork
# end

struct Source
    out
    seq
end

function string(x::Source)
    "#Source"*string(hashmap(keyword("ch"), x.out, keyword("vals"), x.seq))
end

function source(out, seq::Vector)
    Source(out, seq)
end

struct Sink
    in
    body
end

function collector()
    Sink(in, nil)
end


function βmap(λ)
    ln(e -> x -> e(λ(x)))
end

βid = βmap(identity)

function extendnamespace(x::Keyword, name)
    if x.namespace === nil
        keyword(name, x.name)
    else
        keyword(name*"."*x.namespace, x.name)
    end
end

function extendnamespace(x::MapEntry, name)
    MapEntry(extendnamespace(x.key, name), x.value)
end

function extendnamespace(x::Map, name)
    into(empty(x), map(x -> extendnamespace(x, name)), x)
end

function extendnamespace(x::Vector, name)
    into(empty(x), map(x -> extendnamespace(x, name)), x)
end

# function extendnamespace(net::Network, name)
#     Network(
#         extendnamespace(net.βs, name),
#         into(vec(), map(x -> extendnamespace(x, name)), net.wires)
#     )
# end

function extendnamespace(x::MapEntry)
    extendnamespace(x.value, name(x.key))
end

# function mergenetworks1(a::Network, b::Network)
#     Network(merge(a.βs, b.βs), into(a.wires, b.wires))
# end

# function mergenetworks1(x::Network)
#     x
# end

# function mergenetworks1()
#     emptynetwork
# end

# function mergenetworks(netmap::Map)
#     transduce(map(extendnamespace), mergenetworks1, emptynetwork, netmap)
# end

################################################################################
# Simple Networks (transducer analogues)
################################################################################

function pbody(n)
    function(e)
        function(inputs)
            s = get(inputs, state)
            x = get(inputs, in)
            s2 = push!(copy(s), copy(x))
            if length(s2) === n
                e(vec(out, s2), vec(state, []))
            else
                e(vec(state, s2))
            end
        end
    end
end

function partition(n)
    network(
        hashmap(
            keyword("main"), beta(vec(in, state), vec(out, state), pbody(n)),
            keyword("state"), βmap(identity),
            keyword("init-state"), source(keyword("state"), vec(vec()))
        ),
        vec(
            # REVIEW: :main/state here refers to both the in and out channels of
            # the main partition transducer. There's no ambiguity since wires
            # are directed, but is there a communication problem?
            #
            # I guess we can always wait and see if I get confused...
            vec(keyword("main", "state"), keyword("state", "in")),
            vec(keyword("state", "out"), keyword("main", "state")),
            vec(keyword("init-state", "state"), keyword("state", "in"))
        )
    )
end

function interposebody(delim)
    function(e)
        function(i)
            s = get(i, keyword("state"))
            x = get(i, keyword("in"))
            if x === nil && s != keyword("uninitialised")
                # When a stream ends, the `nil` marker gets passed as a
                # value. This is the only time a nil can appear in a stream.
                #
                # REVIEW: I don't like this convention. I don't like magic
                # tokens in general, but I don't presently have a better
                # solution.
                emit(vec(keyword("out"), s))
            elseif s == keyword("uninitialised")
                emit(vec(keyword("state"), x))
            else
                emit(
                    vec(keyword("state"), x),
                    vec(keyword("out"), s, delim)
                )
            end
        end
    end
end

function interpose(delim)
    network(
        hashmap(
            keyword("main"), beta(vec(in, state), vec(out, state), interposebody(delim)),
            keyword("state"), βmap(identity),
            keyword("init-state"), source(keyword("state"), vec(keyword("uninitialised")))
        ),
        vec(
            vec(keyword("main", "state"), keyword("state", "in")),
            vec(keyword("state", "out"), keyword("main", "state")),
            vec(keyword("init-state", "state"), keyword("main", "state"))
        )
    )
end

dup = ln(e -> x -> e(x, x))


function βfilter(p)
    function inner(x)
        if p(x)
            e(x)
        end
    end
    ln(inner)
end

function append(xs)
    function inner(x)
        # only does something at end of input stream
        if x === nil
            e(xs)
        end
    end
    ln(inner)
end

function prepend(xs)
    function inner(e)
        function(x)
            if get(x, state) == keyword("uninitialised")
                e(reduce(conj, vec(out), xs), vec(state, "finished"))
            end
        end
    end

    network(
        hashmap(
            keyword("main"), beta(vec(in, state), vec(out, state), inner),
            keyword("init-state"), source(out, vec(keyword("uninitialised")))
        ),
        vec(
            vec(keyword("init-state", "out"), keyword("main", "state"))
        )
    )
end

##### Getting data in and out of networks

# Good question...
function βtransduce(n)
end

################################################################################
# Example Networks
################################################################################

"""Composition is now a matter not just of f and g, but of connecting the
various outputs of one to the various inputs of the other (and perhaps vice
versa)."""
# REVIEW: This has some of the character of the ugly compositions in
# multivariate calculus. Is that just a superficial similarity?
#
#####
# Networks must be named before they can be merged because it is assumed that
# different instances of the same β are *different* and thus cannot be
# unified. In fact, nothing can be unified, so really we build a tree of named
# networks.
#
# if we represent a network as a map with 2 keys, :networks, and :wires, where
# :networks is a map from name (keyword) to network, then we don't actually have
# to merge the networks, but can simply walk the tree.
#
# I think that will massively simplify the language and runtime. The tree is
# very much akin to how the runtime is intended to isolate execution, so that's
# promising.
#####
function compose(netmap, wires)
    hashmap(
        keyword("networks"), netmap,
        keyword("wires"), wires
    )
end

tx1 = compose(
    hashmap(
        keyword("prepend"), prepend(vec(1,2,3)),
        keyword("dup"), dup,
        keyword("append"), append(vec(7,8,9))
    ),
    vec(
        vec(keyword("prepend.main", "out"), keyword("dup.main", "in")),
        vec(keyword("dup.main", "out"), keyword("append.main", "in"))
    )
)

# appends the output of `net` to the `to` stream.
# `net` must be a linear transducer for this to make sense. That means that
# there is only one "external" input and one "external" output.
# <net, in, out> is a triple. It's a mode of interpretation of the network. A
# sort of partial application, really.
function into(net, in, out, to, from)
    ret = collector()
    inet = compose(
        hashmap(
            keyword("to"), prepend(to),
            keyword("xform"), net,
            keyword("output"), ret,
            keyword("input"), source(out, from)
        ),
        vec(
            vec(keyword("to.main", "out"), keyword("output", "in")),
            vec(keyword("input", "out"), extendnamespace(in, "xform")),
            vec(extendnamespace(out, "xform"), keyword("to.main", "in"))
        )
    )
    run(inet)
    collect(collector)
end


# transduce(prepend([1,2,3]) ∘ dup ∘ append([7,8,9]), conj, [0], [4,5,6])
# should return [0,1,1,2,2,3,3,4,4,5,5,6,6,7,8,9]
#
# Can these networks express the `to` collection? `into` will be `prepend(to)`
# applied to a source. That seems fine, the inefficiencies of reemitting the
# collection element by element aside.

# Newfangled API
# The idea of exposed wires is conventional. Is there any advantage to encoding
# the current convention into the API? probably not. We can just as easily
# create an "exposed" function which figures out what we would have encoded in
# the data format.

################################################################################
# Runtime
#
# Considerations:
#
# Starvation is a big one. The runtime needs to impose fairness, in the same
# sense as an operation system does. Without that, a couple of spammy βs can
# overwhelm the system easily.
#
# Backpressure is another. Queues cannot grow indefinitely, and even if they
# could, progress will grind to a halt as the message queues grow since we can
# only run a fixed number of β computations in parallel. Is that true? If the
# number of β nodes in the network is fixed, queue length shouldn't effect
# progress, if you define progress as number of messages popped per time
# interval.
#
# Basic algorithm:
#
# Sort messages by some fairness criterion into a single queue. Have a
# threadpool pinned to the number of cores available, each thread running an
# identical process. When a thread is free, it takes the first message on the
# queue, and looks at its target. If the target is currently executing, put the
# message back and look at the next one. Otherwise apply the message to its
# target. If the target is ready to run, run it and put all output messages into
# the queue. If the target it not ready, pin the message to it (how?) and go
# back to the next message in the central queue.
#
# Make sure the central queue is threadsafe and the sorting mechanism scales
# well.

# To initialise a network, start with an empty queue, walk the network for all
# sources and enqueue their contents.
#
# Nope, that won't work. Sources can be infinite. Even when finite, sources may
# not have any messages at the moment, but will later.
#
# Variation:
#
# Queue of all message producers which have messages ready. This includes
# sources and βs which have emitted. If a β emits to multiple channels, then
# those are separate entries on the queue.
#
# The same algorithm applies, but we iterate over channels instead of
# messages. If one of the output channels of a β has emitted and is waiting for
# that message to be processed, then that β counts as executing for the purposes
# of the previous algorithm.
#
# This provides us with both a lazy read and a backpressure mechanism in one. A
# β cannot runaway and produce millions of messages because it will block if
# nothing is reading those messages.
#
# We still need to worry about one very busy thread of message processing
# (signal processor, I suppose) stealing all of the available compute resources,
# so fairness sorting needs to go into the selection of the next emission to be
# passed along.
################################################################################

function sources(n::Source)
    vec(n)
end

function sources(n::Map)
    subs = get(n, keyword("networks"))
    if subs === nil
        vec()
    else
        transduce(map(sources), into, vec(), vals(subs))
    end
end

function sources(n::Beta)
    vec()
end

"""Returns a representation of a network conducive to walking as a graph."""
function tograph(net::Map)

end

function step(net::Map)
end
