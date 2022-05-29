abstract type Flub <: Sexp end

struct BuiltinFn <: Flub
    fn
end

struct Λ <: Flub
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

function apply(context, f::Λ, args::ArrayList)
    m = assoc(emptymap, ck, context)

    eargs = map(x -> eval(withmeta(x, m)), args)

    eval(withmeta(substitute(f, eargs), m))
end

function numericval(x::MetaExpr)
    numericval(x.content)
end

function numericval(x::LispNumber)
    x.val
end

function myplus(x::LispList)
    LispNumber(reduce(+, map(numericval, x.elements)))
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

struct Def <: Flub
    name
    form
end

function def(args)
    name = head(args)
    form = head(tail(args))

    Def(name, form)
end

function apply(context, f::Def, args)
    (h, c) = intern(context, f.form)
end


function internbuiltins(context)
    (h, c) = intern(context, BuiltinFn(λ))
    (_, c) = intern(c, LispSymbol(nil, "λ"), h)
    (h, c) = intern(c, BuiltinFn(myplus))
    (h, c) = intern(c, LispSymbol(nil, "+"), h)
    (h, c) = intern(c, BuiltinFn(def))
    (h, c) = intern(c, LispSymbol(nil, "def"), h)

    return (h, c)
end
