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

# Sequential
export first, rest, take, drop, reduce, transduce, into, map, filter, interpose

# Vectors
export  emptyvector, nth, vec

# Maps
export emptymap, assoc, dissoc, containsp, hashmap, merge

# Generic
export conj, get, count, empty, emptyp, nil, keyword, symbol, name

# Types
export Keyword, Symbol, Map, Vector, MapEntry

end
