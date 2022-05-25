#### Literal data

ck = LispKeyword(nil, "context")

function eval(f::MetaExpr)
    context = get(f.metadata, ck)
    if hasmethod(eval, (typeof(context), typeof(f.content)))
        eval(get(f.metadata, ck), f.content)
    else
        withmeta(eval(f.content), f.metadata)
    end
end

function eval(f::LispNumber)
    f
end

function eval(f::LispString)
    f
end

function eval(f::LispKeyword)
    f
end

function eval(f::LispMapEntry)
    LispMapEntry(eval(f.key), eval(f.value))
end

function eval(f::LispMap)
    ArrayMap(map(eval, f.kvs))
end

function eval(f::LispVector)
    ArrayVector(map(eval, f.elements))
end

function eval(s::Any)
    @assert false "Unimplemented"
end

function eval(s::LispSymbol)
    @assert false "Unresolved symbol: "*string(s)
end

### Here's a curious scenario: Where do we start with immutable names? I could
### resolve symbols right at first eval, but is that even soon enough? Maybe
### they should be resolved a read time.
###
### I think something in between is actually what we want. Lambda's don't get
### evaled recursively when first read, but only when applied. But references
### should be fixed immediately...
###
### Possible workaround. Don't allow the user to define symbols at all. Have a
### special form `export`, `define`, etc. which takes a keyword and a form and
### interns a symbol pointing to the hash of the given form. This allows us to
### look up symbols at read time, so long as all forms referred to have been
### evalled beforehand.
###
### Or this means that symbols will only exist in unread text source. That means
### that the source text has to define the hash the symbol points to if it's
### going to use the symbol. That's a pretty elegant solution in the end.

# Don't eval the elements of tail just yet, leave that up to apply. Technically
# everything is an M expression at the moment.
function eval(context, f::LispList)
    apply(eval(withmeta(head(f), assoc(emptymap, ck, context))), tail(f))
end

function eval(context::Context, f::Ref)
    withmeta(resolve(context, f), assoc(emptymap, ck, context))
end

################################################################################
##### Apply
################################################################################

function apply(f::MetaExpr, args)
    if hasmethod(apply, (Context, typeof(f.content), typeof(args)))
        apply(get(f.metadata, ck), f.content, args)
    else
        withmeta(apply(f.content, args), f.metadata)
    end
end

function apply(f::BuiltinFn, args)
    f.fn(args)
end
