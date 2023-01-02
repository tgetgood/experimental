using DataStructures
using DataStructures: Symbol, Vector, Map, List, first, rest, get, map, count, reduce,  conj, keys, vec, filter, partition, zip
import DataStructures: string

emitsym = symbol("emit")
syms = keyword("symbols")
meta = keyword("metadata")

default = keyword("xprl.streams", "default")
closed = keyword("xprl.streams","close")

include("./rt.jl")
include("./env.jl")
include("./primitives.jl")
include("./xprl.jl")
include("./read.jl")
include("./eval.jl")

function message(e::EOFError)
    println("Goodbye")
end

# FIXME: *e, but with memory leakage
traces = []

function message(e)
    trace = stacktrace(catch_backtrace())

    push!(traces, trace)

    @error "Error in process: " * Base.string(e) *
        "\n" *
        Base.reduce(*, Base.map(x -> string(x) * "\n", trace))
end

function emit_println(ch, v)
    if v !== nothing
        println(string(v))
    end
end


function temit(ch, x)
    println(string(x) * " on " * string(ch))
end



function readloopuntilend(env, stream)
    # This is a bit of a hack
    function ground_emit(ch, v)
        if ch == keyword("env")
            env = v
        elseif ch == keyword("error")
            @error v
        elseif ch == default
            println(string(v))
        else
            # I'd like to log this, but that's probably a security error.
            @warn "Message on <" * string(ch) * "> not handled in repl."
        end
    end

    while true
        try
            form = read(stream)
            if form !== nothing
                eval(set_emit(env, ground_emit), form)
            end
        catch e
            message(e)
            if typeof(e) == EOFError
                return env
            end
        end
    end
end

function readfile(env, filename)
    fs = tostream(open(filename))

    readloopuntilend(env, fs)
end

function repl(env)
    readloopuntilend(env, Base.stdin)
    nothing
end

# Test it out

env = readfile(initenv, "../xprl/core.xprl")

println("")

e2 = readfile(env, "../xprl/advent-2020-1.xprl")
