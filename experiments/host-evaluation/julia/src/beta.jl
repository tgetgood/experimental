# module Operators

import Base: string
import Main.DataStructures: vec, map, nil, assoc, emptymap, hashmap, MapEntry, Map, into, first, rest, keyword, transduce, conj, reduce, merge, Keyword, interpose, name, empty, Vector, emptyvector, count


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

state = keyword("state")
in    = keyword("in")
out   = keyword("out")

# In order to be able to link up βs into a graph, we need to know what the in
# and out channels are right now. There's nothing stipping us from replacing a β
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

function pbody(e)
    function(inputs)
        s = get(inputs, state)
        x = get(inputs, in)
        s2 = push!(copy(s), copy(x))
        if length(s2) === 2
            e((out, s2), (state, []))
        else
            e((state, s2))
        end
    end
end

partition = Network(
    hashmap(
        keyword("main"), beta(vec(in, state), vec(out, state), pbody),
        keyword("state"), βmap(identity)
        ),
    vec(
        # REVIEW: :main/state here refers to both the in and out channels of the
        # main partition transducer. There's no ambiguity since wires are
        # directed, but is there a communication problem?
        #
        # I guess we can always wait and see if I get confused...
        vec(keyword("main", "state"), keyword("state", "in")),
        vec(keyword("state", "out"), keyword("main", "state"))
    )
)

function dupi(e)
    function (x)
        e((out, x, x))
    end
end

dup = beta([in], [out], dupi)

# end
