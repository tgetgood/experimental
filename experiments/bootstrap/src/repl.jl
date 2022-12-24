using DataStructures
using DataStructures: Symbol, Vector, Map, List, first, rest, get, map, count, reduce,  conj, keys, vec, filter, partition, zip
import DataStructures: string

include("./primitives.jl")
include("./env.jl")
include("./xprl.jl")
include("./read.jl")
include("./eval.jl")

function interpret(env, v)
    env, v
end
function interpret(_, v::ModEnv)
    v.env, v.val
end

function step(env, stream)
    form = read(stream)
    interpret(env, eval(env, form))
end

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

function readloopuntilend(env, stream)
    while true
        try
            env, val = step(env, stream)
            if val !== nothing
                println(string(val))
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
    fs = stream(open(filename))

    readloopuntilend(env, fs)
end

function repl(env)
    readloopuntilend(env, Base.stdin)
    nothing
end

# Test it out

env = readfile(initenv, "../xprl/core.xprl")

println("")

#e2 = readfile(env, "../xprl/advent-2020-1.xprl")
