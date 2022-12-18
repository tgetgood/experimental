abstract type List end

# This is just laziness, but lists aren't a performance sensitive
# datastructure. That is to say: you shouldn't be using lists if you want
# performance.

struct VectorList <: List
    contents
end

function count(x::List)
    count(x.contents)
end

function length(x::List)
    count(x)
end

function first(x::List)
    first(x.contents)
end

function rest(x::List)
    VectorList(rest(x.contents))
end

# REVIEW: Should I even define `conj` for lists? Lists will come full cloth for
# the most part. Let's see how far I get without it.

function list(xs...)
    tolist(xs)
end

function tolist(xs)
    VectorList(vec(xs))
end

function vec(args::List)
    reduce(conj, emptyvector, args)
end

function string(x::List)
    "(" * transduce(interpose(" ") ∘ map(string), *, "", x) * ")"
end

function iterate(v::List)
    first(v), rest(v)
end

function iterate(v::List, state)
    if count(state) == 0
        nothing
    else
        first(state), rest(state)
    end
end
