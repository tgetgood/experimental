module DataStructures

import Base: string,hash,==,length

# How many bits of hash are used at each level of the HAMT?
hashbits = 5
nodelength = 2^hashbits
nil = nothing

include("./values.jl")
include("./sequential.jl")
include("./vector.jl")
include("./map.jl")
include("./queue.jl")

# Sequential
export first, rest, take, drop, reduce, transduce, into, map, filter, interpose, dup

# Vectors
export  emptyvector, nth, vec

# Maps
export emptymap, assoc, dissoc, containsp, hashmap, merge, keys, vals

# Queues
export Queue, queue, emptyqueue

# Generic
export conj, get, count, empty, emptyp, nil, keyword, name

# Types
export Keyword, Symbol, Map, Vector, MapEntry

end
