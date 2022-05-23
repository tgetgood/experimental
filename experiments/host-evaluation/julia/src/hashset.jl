struct Context <: Sexp
    hashset
    symbolmap
end

import Base.copy

function copy(c::Context)
    Context(copy(c.hashset), copy(c.symbolmap))
end

abstract type Ref <: Sexp end

struct FixedHashRef <: Ref
    hash
end

function intern(context::Context, form)
    # Now the question: What do we hash?
    #
    # We can't just hash the text, or whatever the binary format happens to
    # be. We need a stable intermediate which allows us to take equivalence
    # before hashing.
    #
    # I think that means we need a stable binary wire format. I have some ideas
    # about what that should be, but this is yet another rabbit hole.
    #
    # What's curious is that all of these rabbit holes I'm getting trapped in
    # are ones I've explored in the past — in fact they're ones that I've been
    # completely derailed exploring in the past — and they all have the status
    # of open research questions...
    #
    # 1) define a binary format to represent our data structures
    # 2) define some way for that format to refer to messages not native to our
    # format (source code from other languages), could be just strings or blobs.
    # 3) λ creates three things. One is the args & body normalised, Two is the
    # metadata which says what specialisation will convert the normalised form
    # into that provided by the programmer, and three is something that just
    # points to both as the desired whole.
    #
    # How we normalise lambdas is an orthogonal question, is it not?
    hashset = context.hashset

    k = FixedHashRef(hash(form))
    if haskey(hashset, k)
        if form === hashset[k]
            return (k, context)
        else
            throw("Hash collision in evaluation context. Time to write the hashset.")
        end
    else
        c2 = copy(context)
        c2.hashset[k] = form
        return (k, c2)
    end
end

function intern(context::Context, sym::LispSymbol, ref)
    @assert haskey(context.hashset, ref) "You can't name something that doesn't exist. Not here, anyway."

    c2 = copy(context)
    c2.symbolmap[sym] = ref
    return (ref, c2)
end

function resolve(context::Context, ref::Ref)
    context.hashset[ref]
end

function resolve(context::Context, ref::LispSymbol)
    context.symbolmap[ref]
end

function hashbytes(f, n::UInt8)
    @assert n <= 8 "Hashes longer than 8 bytes not currently supported"
    hash(f) >> ((8 - n) << 3)
end
