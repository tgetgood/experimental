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
    in = Channel()
    out = Channel()

    function emit(x)
        put!(out, x)
    end

    action = tx(emit)

    @async begin
        while in.state == :open || isready(in)
            v = take!(in)
            action(v)
        end
        close(out)
    end

    return [in, out]
end

function bogoprof()
    n = network(map(x -> x^2 ))
    sig = Channel()
    top = 1000000
    t0 = time()

    @async begin
        try
            for i = 1:top
                put!(n[1], i)
            end
            close(n[1])
        catch e
            println(e)
        end
    end

    x = []

    for i=1:top
        @async begin
            append!(x, take!(n[2]))
        end
    end

    println(last(x))

    @async put!(sig, x)

    @async begin
        try
            x = take!(sig)
            t1 = time()
            println(last(x))
            println("Time:"* string(t1 - t0))
        catch e
            println(e)
        end
    end

    nothing
end

n = network(map(x -> x * x))

t = @task println(take!(n[2]))

@async begin
    for i = 1:1000
        put!(n[1], i)
    end
end
