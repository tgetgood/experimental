struct Context
end

struct Λ
    args::LispVector
    body::Sexp
end

function λ(form::LispList)
    # What should sig be? fn? lambda? it shouldn't be a symbol at all. but then
    # what?
    #
    # It should be a ref to interned code. Interned jl code, which makes it a
    # special form. That's the only difference.
    #
    # Our interned forms are like words in forth... I think.
    #
    # λ –> HashRef -> code that expects two args and returns something
    # representing a lambda.
    return Λ(head(form), head(tail(form)))
end

function intern(form::Sexp)
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
    return (hashref, contextref)
end

function lookup(ref)
end
