################################################################################
##### Tokenise
################################################################################

"""There's got to be a better way to do this"""
function append(v, t)
    push!(copy(v), t)
end

delimiters = "()[]{}\""

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
    delim("{", "}", :map),
    delim("\"", "\"", :string)
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
        tree(append(acc, head), mode, tail)
    else
        if p.action === :close || mode === :string && head === "\""
        @assert mode === p.delim.mode "mismatched delimiters. got " *
            p.delim.close *
            " to terminate a " *
            String(mode)
        return (acc, tail)
            
        elseif p.action === :open 
            (sub, subtail) = tree([], p.delim.mode, tail)
            tree(append(acc, [p.delim.mode, sub]), mode, subtail)
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

"""Tries to parse an atom into an Int64, returns nothing if it can't """
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
