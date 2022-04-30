y = 7

z = y * 5 + 6 

q1(a, s, b) = (s - b)/2*a

function q(a, b ,c)
    s = sqrt(b^2 - 4*a*c)
    q1(a, s, b), q1(a, -s, b)
end

struct Vec
    elements
end

struct List
    elements
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

"""There's got to be a better way to do this"""
function append(v, t)
    push!(copy(v), t)
end

function digit(s)
    try
        parse(UInt, s)
        return true
    catch Error
        return false
    end
end

delimiters = "()[]{}"

whitespace = " \t\r\n"

function parsetoken(s)
    f(c) = contains(whitespace, c) || contains(delimiters, c)
    d = findfirst(f, s) - 1
    s[begin:begin+d-1], s[begin+d:end]
end

function t1(tokens, s)

    if length(s) === 0
        return tokens
    else
        c = s[begin:begin]
        if contains(delimiters, c)
            t1(append(tokens, c), s[begin+1:end])
        elseif contains(whitespace, c)
            t1(tokens, s[begin+1:end])
        else
            (t, rest) = parsetoken(s)
            t1(append(tokens, t), rest)
        end
    end
end

function tokenise(s::String)
    t1([], s)
end

function buildlist(tokens)
    elements = map(buildsexp, tokens)
    return List(elements, length(elements))
end

function buildsexp(input)
    if isa(input, Vector)
        tokens = input
        f = tokens[begin]
        if f === "("
            @assert tokens[end] === ")" "Unbalanced parentheses"
            return ["list", map(buildsexp, tokens[begin+1:end-1])]
        elseif f === "["
            @assert tokens[end] === "]" "Unbalanced brackets"
            return ["vector", map(buildsexp, tokens[begin+1:end-1])]
        elseif f === "{"
            @assert tokens[end] === "}" "Unbalanced braces"
            return ["map", map(buildsexp, tokens[begin+1:end-1])]
        else
            @assert false "unreachable"
        end
    else
        return input
    end
end

buildatom(x) = x

struct delim
    open
    close
    mode
    name
end

struct pos
    delim
    action
end

delims = [
    delim("(", ")", :list, "parens"),
    delim("[", "]", :vector, "brackets"),
    delim("{", "}", :map, "braces")
]

collections = reduce(merge,
                     map(x -> Dict(
                         x.open => pos(x, :open),
                         x.close => pos(x, :close)
                     ), delims))
                     
function tree(acc, mode, tokens)
    if length(tokens) === 0
        @assert mode === :root "Unexpected end of input"
        return acc
    end
    
    head = tokens[begin]
    tail = tokens[begin+1:end]

    p = get(collections, head, nothing)

    if p === nothing
        tree(append(acc, buildatom(head)), mode, tail)
    else
        if p.action === :open
            (sub, subtail) = tree([], p.delim.mode, tail)
            tree(append(acc, [p.delim.mode, sub]), mode, subtail)
        else
        @assert mode === p.delim.mode "mismatched delimiters. got " *
            p.delim.close *
            " to terminate a " *
            String(mode)
        return (acc, tail)
        end
    end
end        
    

"""Very basic lisp reader"""
function read()
    buildsexp(tokenise(readline()))
end


## C interop test

cc = (:LLVMContextCreate, "libLLVM")

mutable struct llvmContext
end
