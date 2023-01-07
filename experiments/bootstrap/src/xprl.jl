##### Initial environment

# Mappings in the initial environment are effectively built-in functions.

# They *can* be overridden, though probably shouldn't.

# These functions are *primitive*, in the sense that they cannot be implemented
# in the language they implement.

function defaultemit(ch, v)
    @warn "Message received on " *
        string(ch) *
        " which is not connected to anything."
end

initenv = hashmap(
    syms, hashmap(
        # Lisp 101
        symbol("def"), PrimitiveMacro(xprldef),
        symbol("fn"), PrimitiveMacro(xprlfn),
        symbol("quote"), PrimitiveMacro(xprlquote),
        symbol("macro"), PrimitiveMacro(xprlmacro),
        symbol("if"), PrimitiveMacro(xprlif),

        # wires & streams
        symbol("ground"), PrimitiveMacro(ground),
        symbol("wire"), PrimitiveMacro(wire),
        symbol("emit"), PrimitiveMacro(xprlemit),
        symbol("default"), default,
        symbol("recur"), PrimitiveMacro(xprlrecur),
        symbol("stream"), PrimitiveMacro(xprlstream),

        # Standard library
        # Most of these should be bootstrapped
        symbol("not"), PrimitiveFn(!),
        symbol("+"), PrimitiveFn(+),
        symbol("-"), PrimitiveFn(-),
        symbol("*"), PrimitiveFn(*),
        symbol("/"), PrimitiveFn(/),
        symbol("="), PrimitiveFn(==),
        symbol(">"), PrimitiveFn(>),
        symbol("<"), PrimitiveFn(<),
        symbol("list"), PrimitiveFn(list),
        symbol("get"), PrimitiveFn(get),
        symbol("contains?"), PrimitiveFn(containsp),
        symbol("empty?"), PrimitiveFn(emptyp),
        symbol("first"), PrimitiveFn(first),
        symbol("take"), PrimitiveFn(take),
        symbol("rest"), PrimitiveFn(rest),
        symbol("count"), PrimitiveFn(count),
        symbol("assoc"), PrimitiveFn(assoc),
        symbol("conj"), PrimitiveFn(conj),
        symbol("type"), PrimitiveFn(typeof),
    ),
    meta, hashmap(),
    keyword("current-ns"), keyword("xprl", "user"),
    emitsym, defaultemit
)
