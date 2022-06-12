abstract type Sexp end

struct MetaExpr <: Sexp
    metadata::Sexp
    content::Sexp
end

function withmeta(f, m)
    MetaExpr(m, f)
end

struct String <: Sexp
    val::AbstractString
end

struct Number <: Sexp
    val::Base.Number
end

function string(x::Number)
    string(x.val)
end

struct Keyword <: Sexp
    namespace
    name
end

struct Symbol <: Sexp
    namespace
    name
end

function string(x::Symbol)
    if x.namespace === nil
        x.name
    else
        x.namespace*"/"*x.name
    end
end

function hash(x::Symbol)
   hash(string(x))
end

function ==(x::Symbol, y::Symbol)
    ## Strings are *not* interned in Julia
    x.namespace == y.namespace && x.name == y.name
end

function string(x::Keyword)
    if x.namespace === nil
        ":" * x.name
    else
        ":" * x.namespace * "/" * x.name
    end
end

function hash(x::Keyword)
    hash(string(x))
end

function ==(x::Keyword, y::Keyword)
    x.namespace == y.namespace && x.name == y.name
end

# TODO: Intern keywords.
function keyword(name)
    Keyword(nil, name)
end

function keyword(ns, name)
    Keyword(ns, name)
end
