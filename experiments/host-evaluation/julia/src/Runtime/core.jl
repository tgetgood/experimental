include("../modules.jl")

# module Runtime

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

# ex = map(f) ∘ filter(p) ∘ interpose(t)

# in = ds.keyword("in")
# out = ds.keyword("out")

# mapper = ds.hashmap(
#     in, [in],
#     out, [out],
#     ds.keyword("body"), map(x -> x + 1)
# )

function network(tx)
    in = Channel(1)
    out = Channel(1)

    function emit(xs...)
        for x in xs
            put!(out, x)
        end
    end

    action = tx(emit)
    @async begin
        action(take!(in))
    end

    return [in, out]
end
