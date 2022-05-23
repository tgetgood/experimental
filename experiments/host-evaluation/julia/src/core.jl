# module Core

include("datastructures.jl")
include("walk.jl")
include("hashset.jl")
include("builtins.jl")
include("read.jl")
include("print.jl")
include("eval.jl")

""" Creates a new context and fills it with the minimum required to bootstrap a
repl. """
function barecontext()
    c = Context(Dict(), Dict())
    (_, c2) = internbuiltins(c)
    return c2
end

form = lispreader(fs, barecontext())
test = eval(withmeta(form, assoc(emptymap, ck, barecontext()))).content

# end
