module Operators

struct Beta
    channels::Dict{Symbol, Channel}
    lambda
end

## As it stands, the set of channels a β may emit on is dynamically
## defined. This means that a β can learn about new channels and emit to them at
## runtime, which makes it difficult to ask "What channels might this β emit
## messages on?". Runtime instrumentation can help, but it won't prove anything.
##
## I guess we'll see how important that is as we go.
function beta(chs, body)
end

# TODO: How do we tell the runtime that the `:state` in channel receives from
# the `:state` out channel? just using the names with magic conventions isn't an
# appealing solution.
function pbody(e)
    function(s, x)
        s2 = push!(copy(s), copy(x))
        if length(s2) === 2
            e((:out, s2), (:state, []))
        else
            e((:state, s2))
        end
    end
end

partition = beta([:state, :in], pbody)


function dupi(e)
    function (x)
        e((:out, x, x))
    end
end

dup = beta([:in], dupi)

end
