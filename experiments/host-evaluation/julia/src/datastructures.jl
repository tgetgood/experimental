abstract type Sexp end

abstract type LispMap <: Sexp end

abstract type LispList <: Sexp end

abstract type LispVector <: Sexp end

abstract type LispSet <: Sexp end

struct LispString <: Sexp
    val::AbstractString
end

struct LispNumber <: Sexp
    val::Number
end

struct ArrayList <: LispList
    elements::Vector{Sexp}
end

struct ArrayVector <: LispVector
    elements::Vector{Sexp}
end

struct LispMapEntry
    key::Sexp
    value::Sexp
end

struct ArrayMap <: LispMap
    kvs::Vector{LispMapEntry}
end

struct Nil <: Sexp end

nil = Nil()

struct LispKeyword <: Sexp
    namespace
    name
end

struct LispSymbol <: Sexp
    namespace
    name
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
        if e.key === query
            return e.value
        end
    end
    return default
end

function get(v::ArrayVector, i::Unsigned)
    v.elements[i]
end
