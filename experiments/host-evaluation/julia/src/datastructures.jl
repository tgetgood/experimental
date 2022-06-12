module Sexps


abstract type LispMap <: Sexp end

abstract type LispList <: Sexp end

abstract type LispVector <: Sexp end

abstract type LispSet <: Sexp end

abstract type LispReference <: Sexp end

# REVIEW: Should metadata be infinitely nestable? or does withmeta just
# overwrite the metadata?
#
# Clojure's with-meta clobbers the metadata (functionally) but that's probably
# because metadata is a mutable field in the core data types.
#
# Let's leave metadata nestable for now, make metadata handlers recursive so
# that it shouldn't matter, and see what happens.
#
# function withmeta(f::MetaExpr, m)
#     MetaExpr(m, f.content)
# end
function length(x::ArrayList)
    length(x.elements)
end

struct ArrayVector <: LispVector
    elements::Vector{Sexp}
end

function length(x::ArrayVector)
    length(x.elements)
end

struct LispMapEntry
    key::Sexp
    value::Sexp
end

struct ArrayMap <: LispMap
    kvs::Vector{LispMapEntry}
end

emptymap = ArrayMap([])

struct Nil <: Sexp end

nil = Nil()

## TODO: Intern symbols and keywords


export Keyword

end
