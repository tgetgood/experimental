# module Operators

import Base: string

import Main.DataStructures: vec, map, nil, assoc, emptymap, hashmap, MapEntry, Map, into, first, rest, keyword, transduce, conj, reduce, merge, Keyword, name, empty, Vector, emptyvector, count

struct Beta
    ins
    outs
    lambda
end

function string(x::Beta)
    string(hashmap(keyword("in"), x.ins, keyword("out"), x.outs, keyword("body"), x.lambda))
end

struct Network
    βs
    wires
end

emptynetwork = Network(emptymap, emptyvector)

function emptyp(x::Network)
    x == emptynetwork
end

function string(x::Network)
    string(hashmap(keyword("βs"), x.βs, keyword("wires"), x.wires))
end

struct Source
    out
    seq
end

function source(out, seq::Vector)
    Source(out, seq)
end

struct Sink
    in
    body
end

state = keyword("state")
in    = keyword("in")
out   = keyword("out")

# In order to be able to link up βs into a graph, we need to know what the in
# and out channels are right now. There's nothing stopping us from replacing a β
# with a new one which can emit to more places, but that's a new entity.
function beta(in, out, body)
    Beta(in, out, body)
end

function βmap(λ)
    function inner(e)
        function(x)
            e(out, λ(get(x, in)))
        end
    end

    Beta(vec(in), vec(out), inner)
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

function extendnamespace(net::Network, name)
    Network(
        extendnamespace(net.βs, name),
        into(vec(), map(x -> extendnamespace(x, name)), net.wires)
    )
end

function extendnamespace(x::MapEntry)
    extendnamespace(x.value, name(x.key))
end

function mergenetworks(a::Network, b::Network)
    Network(merge(a.βs, b.βs), into(a.wires, b.wires))
end

function mergenetworks(x::Network)
    x
end

function mergenetworks()
    emptynetwork
end

function mergenetworks(netmap::Map)
    transduce(map(extendnamespace), mergenetworks, emptynetwork, netmap)
end

function wire(n, newwire)
    Network(n.βs, conj(n.wires, newwire))
end

function pbody(n)
    function(e)
        function(inputs)
            s = get(inputs, state)
            x = get(inputs, in)
            s2 = push!(copy(s), copy(x))
            if length(s2) === n
                e((out, s2), (state, []))
            else
                e((state, s2))
            end
        end
    end
end

function partition(n)
    Network(
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
    Network(
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

################################################################################
# Example Networks
################################################################################



################################################################################
# Runtime
################################################################################



# end
