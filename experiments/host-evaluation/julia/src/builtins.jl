struct Λ <: Sexp
    args::LispVector
    body::Sexp
end

function subwalker(subs, x)
    x
end

function subwalker(subs, x::LispSymbol)
    if haskey(subs, x)
        subs[x]
    else
        x
    end
end

function substitute(Λ, args)
    ## Automatic currying wouldn't be too hard to add here.
    ## One can see why features creep.
    @assert length(args) === length(Λ.args)
    kvs = []
    begin
        for i in range(1, length(args))
            push!(kvs, get(Λ.args, i) => get(args, i))
        end
    end

    subs = Dict(kvs)

    postwalk(x -> subwalker(subs, x), Λ.body)
end

function apply(f::Λ, args::ArrayList)
    eargs = map(eval, args)

    eval(substitute(f, eargs))
end

abstract type Flub <: Sexp end

struct BuiltinFn <: Flub
    fn
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

function internbuiltins(context)
    (h, c1) = intern(context, BuiltinFn(λ))
    c2 = intern(c1, LispSymbol(nil, "λ"), h)
    LispSymbol(nil, "export")
    return c2
end
