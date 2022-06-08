# module DataStrutures

abstract type Sexp end

abstract type LispMap <: Sexp end

abstract type LispList <: Sexp end

abstract type LispVector <: Sexp end

abstract type LispSet <: Sexp end

abstract type LispReference <: Sexp end

struct MetaExpr <: Sexp
    metadata::Sexp
    content::Sexp
end

function withmeta(f, m)
    MetaExpr(m, f)
end

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
struct LispString <: Sexp
    val::AbstractString
end

struct LispNumber <: Sexp
    val::Number
end

function string(x::LispNumber)
    string(x.val)
end

struct ArrayList <: LispList
    elements::Vector{Sexp}
end

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

struct LispKeyword <: Sexp
    namespace
    name
end

struct LispSymbol <: Sexp
    namespace
    name
end

function string(x::LispSymbol)
    if x.namespace === nil
        x.name
    else
        x.namespace*"/"*x.name
    end
end

function hash(x::LispSymbol)
   hash(string(x))
end

function ==(x::LispSymbol, y::LispSymbol)
    ## Strings are *not* interned in Julia
    x.namespace == y.namespace && x.name == y.name
end
