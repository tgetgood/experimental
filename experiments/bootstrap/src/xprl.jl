##### Initial environment

# Mappings in the initial environment are effectively built-in functions.

# They *can* be overridden, though probably shouldn't.

# These functions are *primitive*, in the sense that they cannot be implemented
# in the language they implement.

initenv = hashmap(
    syms, hashmap(
        symbol("def"), PrimitiveMacro(xprldef),
        symbol("fn"), PrimitiveMacro(xprlfn),
        symbol("quote"), PrimitiveMacro((env, x) -> first(x)),
        symbol("macro"), PrimitiveMacro(xprlmacro),
        symbol("if"), PrimitiveMacro(xprlif),
        symbol("+"), PrimitiveFn(+),
        symbol("-"), PrimitiveFn(-),
        symbol("*"), PrimitiveFn(*),
        symbol("="), PrimitiveFn(==),
        symbol(">"), PrimitiveFn(>),
        symbol("<"), PrimitiveFn(<),
        symbol("list"), PrimitiveFn(list),
        symbol("get"), PrimitiveFn(get),
        symbol("contains?"), PrimitiveFn(containsp),
        symbol("empty?"), PrimitiveFn(emptyp),
        symbol("first"), PrimitiveFn(first),
        symbol("into"), PrimitiveFn(into),
        symbol("map"), PrimitiveFn(map),
        symbol("filter"), PrimitiveFn(filter),
        symbol("partition"), PrimitiveFn(partition),
        symbol("reduce"), PrimitiveFn(reduce),
        symbol("take"), PrimitiveFn(take),
        symbol("rest"), PrimitiveFn(rest),
        symbol("count"), PrimitiveFn(count),
        symbol("assoc"), PrimitiveFn(assoc),
        symbol("conj"), PrimitiveFn(conj),
        symbol("type"), PrimitiveFn(typeof)
    ),
    meta, hashmap()
)
