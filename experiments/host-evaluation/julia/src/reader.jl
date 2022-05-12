module LispReader end

struct BufferedStream
    stream
    buffer::Vector{Char}
end

function read1(s::BufferedStream)
    if length(s.buffer) > 0
       return popfirst!(s.buffer)
    else
        return read1(s.stream)
    end
end

function unread1(s::BufferedStream, c::Char)
    pushfirst!(s.buffer, c)
end

struct ReaderOptions
    until
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

function splitsymbolic(x::String)
    parts = split(x, '/')
    if length(parts) === 1
        return [nil, parts[1]]
    elseif length(parts) > 2
        throw :bob
    end
    return [parts[1], parts[2]]
end

function readkeyword(x)
    p = splitsymbolic(x[2:end])
    LispKeyword(p[1], p[2])
end

function readsymbol(x)
    p = splitsymbolic(x)
    LispSymbol(p[1], p[2])
end

function interpret(x::String)
    if startswith(x, ':')
        return readkeyword(x)
    end
    try
        return LispNumber(parse(Int, x))
    catch ArgumentError
    end

    return readsymbol(x)
end

function readsubforms(stream, until)
    forms = []
    while true
        t = lispreader(stream, ReaderOptions(until))
        if t === nothing
            break
        else
            push!(forms, t)
        end
    end
    return forms
end

function readlist(stream, opts)
    ArrayList(readsubforms(stream, ')'))
end

function readvector(stream, opts)
    ArrayVector(readsubforms(stream, ']'))
end

function readstring(stream, opts)
    ""
end

function readmap(stream, opts)
    elements = readsubforms(stream, '}')
    @assert length(elements) % 2 === 0 "a map literal must contain an even number of entries"

    entries = []
    for i in 1:div(length(elements), 2)
       push!(entries, LispMapEntry(popfirst!(elements), popfirst!(elements)))
    end
    return ArrayMap(entries)
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

delimiter = r"[({\[]"

function istokenbreak(c)
    iswhitespace(c) ||  match(delimiter, string(c)) !== nothing
end

function readtoken(stream, opts)
    out = ""

    while true
        c = read1(stream)
        if istokenbreak(c) || c === opts.until
            unread1(stream, c)
            break
        else
            out = out*c
        end
    end

    return out
end

function lispreader(stream, opts)
    c = nothing
    try
        c = firstnonwhitespace(stream)
    catch EOFError
        return nothing
    end

    if opts.until !== nothing && c === opts.until
        return nothing
    end

    sub = Base.get(dispatch, c, nothing)

    if sub === nothing
        unread1(stream, c)
        return interpret(readtoken(stream, opts))
    else
        return sub(stream, opts)
    end
end

function test()
    lispreader(BufferedStream(stdin, []), ReaderOptions(nothing))
end
