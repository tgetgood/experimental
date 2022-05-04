struct ReaderOptions
    until::Char
end

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

## This will raise an error on EOF. That's normally the right behaviour, but we
## might need a softer try-read sort of fn.
function read1(stream)
    return read(stream, Char)
end

whitespace = r"[\s,]"

iswhitespace(c) = match(whitespace, string(c)) !== nothing

function firstnonwhitespace(stream)
    c::Char = ' '
    while iswhitespace(c)
        c = read1(stream)
    end
    return c
end

function interpret(x)
    x
end

function readlist(stream, opts)
    ArrayList([])
end

function readvector(stream, opts)
    ArrayVector([])
end

function readstring(stream, opts)
    ""
end

function readmap(stream, opts)
    ArrayMap([])
end

indirectdispatch = Dict()

function readdispatch(stream, opts)
end

dispatch = Dict(
    '(' => readlist,
    '[' => readvector,
    '"' => readstring,
    '{' => readmap,
    '#' => readdispatch
)

function readtoken(c, stream)
    out = ""*c

    while !iswhitespace(c)
        c = read1(stream)

function lispreader(stream, opts)
    c = nothing
    try
        c = firstnonwhitespace(stream)
    catch EOFError
        return nothing
    end

    sub = get(dispatch, c, nothing)

    if sub === nothing
        return interpret(readtoken(c, stdin))
    else
        return sub(stream, opts)
    end
end

function test()
    lispreader(stdin, ReaderOptions(')'))
end
