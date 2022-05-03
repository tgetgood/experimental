################################################################################
##### Tokenise
################################################################################

"""There's got to be a better way to do this"""
function append(v, t)
    push!(copy(v), t)
end

# This is going to be so inefficient...
function append(v, t, rest...)
    reduce(append, rest, init=append(v, t))
end

delimiters = "()[]{}"

whitespace = " \t\r\n,"

function parsetoken(s)
    f(c) = contains(whitespace, c) || contains(delimiters, c)
    d = findfirst(f, s) - 1
    s[begin:begin+d-1], s[begin+d:end]
end

function t1(tokens, s)
    ## TODO: read strings properly

    if length(s) === 0
        return tokens
    else
        c = s[begin:begin]
        tail = s[begin+1:end]
        if contains(delimiters, c)
            t1(append(tokens, c), tail)
        elseif contains(whitespace, c)
            t1(tokens, tail)
        elseif c === "\""
            close = findfirst(x -> x === '"', tail)
            t1(append(tokens, "\"", s[begin+1:close-1], "\""), s[close+1:end])
        else
            (t, rest) = parsetoken(s)
            t1(append(tokens, t), rest)
        end
    end
end

function tokenise(s::String)
    t1([], s)
end

function digit(s)
    try
        parse(UInt, s)
        return true
    catch Error
        return false
    end
end

################################################################################
#### Sexp tree construction
##
## This sorts the stream of tokens into a tree of tokens, with types branches
## for different kinds of collections
################################################################################

struct delim
    open
    close
    mode
end

struct pos
    delim
    action
end

delims = [
    delim("(", ")", :list),
    delim("[", "]", :vector),
    delim("{", "}", :map)
]

collections = reduce(merge,
                     map(x -> Dict(
                         x.open => pos(x, :open),
                         x.close => pos(x, :close)
                     ), delims),
                     init=Dict("\"" => pos(delim("\"", "\"", :string), :both)))
                     
function tree(acc, mode, tokens)
    if length(tokens) === 0
        @assert mode === :root "Unexpected end of input"
        return acc
    end
    
    head = tokens[begin]
    tail = tokens[begin+1:end]

    p = get(collections, head, nothing)

    if p === nothing
        tree(append(acc, head), mode, tail)
    else
        if p.action === :close 
        @assert mode === p.delim.mode "mismatched delimiters. got " *
            p.delim.close *
            " to terminate a " *
            String(mode)
        return (acc, tail)
            
        elseif p.action === :open 
            (sub, subtail) = tree([], p.delim.mode, tail)
            tree(append(acc, [p.delim.mode, sub]), mode, subtail)
        elseif p.action === :both
            if mode === p.delim.mode
                return (acc, tail)
            else
                (sub, subtail) = tree([], p.delim.mode, tail)
                tree(append(acc, [p.delim.mode, sub]), mode, subtail)
            end
        else
        end
    end
end        
    
function buildtree(tokens)
    first(tree([], :root, tokens))
end

################################################################################
##### building Sexp Types
################################################################################

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

Sexp = Union{Vec, Map, Set, Symbol, Keyword, String, Number}

function dequalifyname(s::String)
end

function buildatom(s::String)
    if s[1] === ':'
        ns, name = dequalifyname(s[begin+1:end])
        return Keyword(ns, name)
    end

    try
        return parse(Int, s)
    catch
        nothing
    end

    ns, name = dequalifyname(s)

    return Symbol(ns, name)
end

function buildsexp(tree)
end

################################################################################
##### Assemblage
################################################################################

"""Very basic lisp reader"""
function read()
    buildsexp(buildtree(tokenise(readline())))
end


## C interop test

cc = (:LLVMContextCreate, "libLLVM")

mutable struct llvmContext
end
