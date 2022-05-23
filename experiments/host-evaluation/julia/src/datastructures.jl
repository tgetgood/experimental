import Base: string,hash,==,length

abstract type Sexp end

abstract type LispMap <: Sexp end

abstract type LispList <: Sexp end

abstract type LispVector <: Sexp end

abstract type LispSet <: Sexp end

abstract type LispReference <: Sexp end

struct MetaExpr
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

################################################################################
##### Operations on structures
##
## Question: How do we enforce protocols? Do we need to wtih CLOS style
## overloading?
################################################################################

# TODO: Implement conj and constructors. Literal maps should not be able to have
# duplicate keys.

function get(m::LispMap, query::Sexp)
    get(m, query, nil)
end

function get(m::ArrayMap, query::Sexp, default::Sexp)
    for e in m.kvs
        if e.key == query
            return e.value
        end
    end
    return default
end

function get(v::ArrayVector, i::Int)
    v.elements[i]
end

function get(v::ArrayList, i::Int)
    v.elements[i]
end

function head(f::LispList)
    f.elements[1]
end

function tail(f::LispList)
    ArrayList(f.elements[2:end])
end

import Base.map
function map(f, l::LispList)
    ArrayList(map(f, l.elements))
end

function assoc(m::ArrayMap, k, v)
    kvs = copy(m.kvs)

    for e in kvs
        if e.key == k
            e = LispMapEntry(k, v)
            return ArrayMap(kvs)
        end
    end
    push!(kvs, LispMapEntry(k, v))
    return ArrayMap(kvs)
end
