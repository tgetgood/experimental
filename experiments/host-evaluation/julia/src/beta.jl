# module Operators

struct LispChannel <: Sexp
    ch::Channel
end

function channel()
    LispChannel(Channel())
end

struct Beta
    ins::LispMap
    outs::LispMap
    lambda
end

# In order to be able to link up βs into a graph, we need to know what the in
# and out channels are right now. There's nothing stipping us from replacing a β
# with a new one which can emit to more places, but that's a new entity.
function beta(in, out, body)
    ins = emptymap
    outs = emptymap

    for x in in
        assoc(ins, x, channel())
    end

    for x in out
        assoc(outs, x, channel())
    end

    return Beta(ins, outs, body)
end

function consumingfeedbackwire(in, out, β)
    ins = copy!(β.ins)
    outs = copy!(β.outs)

    inch = β.ins[in].ch
    ouch = β.outs[out].ch

    @async begin
        while true
            v = take!(inch)
            put!(ouch, v)
        end
    end

    delete!(ins, in)
    delete!(outs, out)

    beta(ins, outs, β.lambda)
end

state = LispKeyword(nil, "state")
in    = LispKeyword(nil, "in")
out   = LispKeyword(nil, "out")

# TODO: How do we tell the runtime that the `:state` in channel receives from
# the `:state` out channel? just using the names with magic conventions isn't an
# appealing solution.
#
# What if we allow transducers to emit to their own inbound channels? That is,
# if :state exists in the list if in channels but not in the out channels, the
# β can emit to it, but normal processes cannot listen to it. Or can they? Being
# able to inspect the state of processes will be invaluable to an inhabited
# system.
#
# So should the self-referential channel be both an in and out channel with the
# same name? Should it be a relation (name, in|out) instead of two sets?
#
# This is all overly complicated. A transduction network with a noop forwarder
# can trivially construct loops.
#
# So a transducer with state is actually two (or more) transducers all but one
# of which are just `(map identity)` looping an output back to an input.
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

id = beta([in], [out], e -> i -> e(get(i, in)))

partition = consumingfeedbackwire(state, state, beta([in, state], [out, state], pbody))

function dupi(e)
    function (x)
        e((out, x, x))
    end
end

dup = beta([in], [out], dupi)

# end
