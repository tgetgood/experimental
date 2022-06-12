module DataStructures

import Base: string,hash,==,length

# How many bits of hash are used at each level of the HAMT?
hashbits = 5
nodelength = 2^hashbits
nil = nothing

include("./DataStructures/values.jl")
include("./DataStructures/sequential.jl")
include("./DataStructures/vector.jl")
include("./DataStructures/map.jl")

export first, rest, nth, assoc, dissoc, conj, get, reduce, empty, emptyp, containsp, emptyvector, emptymap, take, drop, into, map, filter, transduce, nil, vec, Keyword, Symbol, transduce, count

end
