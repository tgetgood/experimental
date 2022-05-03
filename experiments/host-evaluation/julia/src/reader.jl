## This will raise an error on EOF. That's normally the right behaviour, but we
## might need a softer try-read sort of fn.
function read1(stream)
    return read(stream, Char)
end

struct ReaderOptions
    endchar::Char
end

whitespace = r"[\s,]"

function firstnonwhitespace(stream)
    c::Char = ' '
    while match(whitespace, string(c)) !== nothing
        c = read1(stream)
    end
    return c
end

function interpret(x)
    x
end

function readlist(stream)
end

dispatch = Dict(
    '(' => readlist
###     '[' => readvector,
###     '"' => readstring,
###     '{' => readmap,
###     '#' => readdispatch
)

indirectdispatch = Dict()

function listreader(stream, opts)
    try
        c = firstnonwhitespace(stream)
    catch EOFError
        return nothing
    end

    sub = get(dispatch, c, nothing)

    if sub === nothing
        return interpret(readtoken(c, stdin))
    else
        return sub(stream)
    end
end

function test()
    c = ' '
    out = []
    while c !== 'z'
        c = read1(stdin)
        push!(out, c)
    end
    return out
end
