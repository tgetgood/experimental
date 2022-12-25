abstract type Sexp end

struct MetaExpr <: Sexp
    metadata::Sexp
    content::Sexp
end

function withmeta(f, m)
    MetaExpr(m, f)
end

function meta(x)
    nothing
end

function meta(x::MetaExpr)
    x.metadata
end

struct Keyword <: Sexp
    namespace
    name
end

struct Symbol <: Sexp
    namespace
    name
end

function symbol(name::String)
    Symbol(nil, name)
end

function symbol(k::Keyword)
    Symbol(k.namespace, k.name)
end

function symbol(namespace, name)
    Symbol(namespace, name)
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
function keyword(name::String)
    Keyword(nil, name)
end

function keyword(s::Symbol)
    Keyword(s.namespace, s.name)
end


function keyword(ns, name)
    Keyword(ns, name)
end

function name(x::Keyword)
    x.name
end

function name(x::Symbol)
    x.name
end

function name(x::String)
    x
end
