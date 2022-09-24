include("../modules.jl")

# module Runtime

using PrettyPrint
import Main.DataStructures as ds
import Main.Networks as beta

# We always need a buffer of at least one for stateful nodes. Without buffering,
# a node that emits to itself would deadlock.
#
# REVIEW: There might be a better way to achieve this with input collectors.
defaultchannelbuffer = 1

function map(f)
    function (emit)
        function (x)
            emit(f(x))
        end
    end
end

function filter(p)
    function(e)
        function(x)
            if p(x)
                e(x)
            end
        end
    end
end

abstract type Node end

struct Network
    networks
    wires
end

struct Beta <: Node
    in
    out
    lambda
end

struct Source <: Node
    out
    vals
end

struct Sink <: Node
    in
    f
end

function sink(f)
    Sink(:in, f)
end

function source(xs)
    Source(:out, xs)
end

function network(vs::Pair...)
    Network(Dict(vs), Dict())
end

function network(nets, wires)
    Network(nets, wires)
end

function linearbeta(tx)
    function wrap(e)
        function(x)
           tx(x -> reduce(append!, x, init=[:out]))(x[:in])
        end
    end
    network(
        :main => Beta([:in], [:out], wrap)
    )
end

function interpb(sep)
    function(e)
        function(x)
            if x[:state] == true
                e([:out, sep, x])
            else
                e([:state true], [:out x])
            end
        end
    end
end

function interpose(sep)
    network(
        Dict(
            :main => Beta([:in, :state], [:out, :state], interpb),
            :initstate => source([false])
        ),
        Dict(
            [:main, :state] => [:main, :state],
            [:initstate, :out] => [:main, :state]
        )
    )
end

testnet = network(
    Dict(
        :map => linearbeta(map(x -> x^2)),
        :filter => linearbeta(filter(x -> x % 2 == 0)),
        :interpose => interpose(0),
        :out => sink(println),
        :in => source([1,2,3,4,5,6])
    ),
    Dict(
        [:in, :out] => [:map, :main, :in],
        [:map, :main, :out] => [:filter, :main, :in],
        [:filter, :main, :out] => [:interpose, :main, :in],
        [:interpose, :main, :out] => [:out, :in]
    )
)

abstract type Topology end

struct StaticTopology <: Topology
    nodes
    wires
end

struct RunningTopology <: Topology
    nodes
    wires
    messages
end

function mergetopo(n1::Topology, n2::Topology)
    StaticTopology(merge(n1.nodes, n2.nodes), merge(n1.wires, n2.wires))
end

function topology(x::Node)
    StaticTopology(Dict([] => x), Dict())
end

function topology(n::Network)
    subnets = Base.map(
        (k, v) -> nesttopology(k, topology(v)),
        keys(n.networks),
        values(n.networks)
    )

    flat = reduce(mergetopo, subnets)

    StaticTopology(flat.nodes, merge(n.wires, flat.wires))
end

function dmap(f, d)
    v = Base.map(f, keys(d), values(d))
    if v == nothing
        Dict()
    else
        Dict(v)
    end
end

function nesttopology(prefix::Symbol, t::Topology)
    nodes = dmap((k,v) -> vcat([prefix], k) => v, t.nodes)

    wires = dmap((k, v) -> vcat([prefix], k) => vcat([prefix], v), t.wires)

    StaticTopology(nodes, wires)
end
