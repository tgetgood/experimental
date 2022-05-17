struct Context
end

struct Λ
    args::LispVector
    body::Sexp
end

function λ(form::LispList)
    sig = head(form)
    # What should sig be? fn? lambda? it shouldn't be a symbol at all. but then
    # what?
    #
    # It should be a ref to interned code. Interned jl code, which makes it a
    # special form. That's the only difference.
    #
    # Our interned forms are like words in forth. I think.
    return Λ(head(tail(form)), head(tail(tail(form))))
end

function intern(form::Sexp)
    return (hashref, contextref)
end

function lookup(ref)
end
