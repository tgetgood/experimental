#### Literal data

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
### I think soething in between is actually what we want. Lambda's don't get
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
function eval(f::LispList)
    apply(eval(head(f)), tail(f))
end


function apply(f::typeof(λ), t::ArrayList)

end
