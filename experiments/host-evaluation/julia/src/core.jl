y = 7

z = y * 5 + 6 

q1(a, s, b) = (s - b)/2*a

function q(a, b ,c)
    s = sqrt(b^2 - 4*a*c)
    q1(a, s, b), q1(a, -s, b)
end

Number = Union{UInt32, UInt64}

struct Vec
    elements
    length
end

struct MapEntry
    key
    val
end

struct Map
    elements
    length
end

struct Symbol
    namespace::String
    name::String
end

struct Keyword
    namespace::String
    name::String
end

Sexp = Union{Vec, Map, Symbol, Keyword, String, Number}


function sexp(tokens)
end

function tokenise(s:: String)
    ["(", "symbol", "[", "34", "]", ")"]
end

"""Very basic lisp reader"""
function read()
    sexp(tokenise(readline()))
end

