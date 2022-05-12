module Operators end

struct Beta
    channels::Dict{Symbol, Channel}
    lambda
end

# I might be getting ahead of myself. Do I really want to define new language
# contructs in julia? I'll have to start dealing with macros.
function beta(chs, body)
end

function pbody(e)
    function(s, x)
        s2 = push!(copy(s), copy(x))
        if length(s2) === 2
            e(:


b = beta([:s, :x], function (s, x)
