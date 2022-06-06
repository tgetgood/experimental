# module DataStructures

import Base: string,hash,==,length

# How many bits of hash are used at each level of the HAMT?
hashbits = 5
nodelength = 2^hashbits
nil = nothing

include("./DataStructures/sequential.jl")
include("./DataStructures/vector.jl")
include("./DataStructures/map.jl")

# end
