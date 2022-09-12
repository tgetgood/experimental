include("../modules.jl")

# module Runtime

import Main.DataStructures as ds

# We always need a buffer of at least one for stateful nodes. Without buffering,
# a node that emits to itself would deadlock.
#
# REVIEW: There might be a better way to achieve this with input collectors.
defaultchannelbuffer = 1

function mapo(f)
    function (emit)
        function (x)
            emit(f(x))
        end
    end
end

v = ds.transduce(ds.prepend(ds.vec(1,2,3)), ds.conj, ds.vec(0,0,0))

v2 = ds.transduce(ds.prepend(ds.vec(1,2,3)) ∘ ds.dup ∘ ds.map(x -> x + 5), ds.conj, ds.vec(0,0,0))
