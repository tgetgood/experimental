# Transduction separates operation on collections into 4 distinct pieces:
# 1) A stream of values
# 2) Transformations on that stream (transducers)
# 3) the function that integrates novelty into the aggregate (reducing function)
# 4) the aggregate of computation so far executed (the collection)
#
# When the stream of values have all been consumed by the aggregator, the
# aggregate so far is the answer.
#
# The reducing function must form a monoid, which is to say it must have an
# identity. If, in addition, it has algebraic properties (associativity,
# commutativity, etc.) then these can be used simplify computations.
#
# Because transducers are intended to compose, we need to worry about interwoven
# concerns: A reducting function called with no arguments by convention returns
# its identity, and so a transducer called with no args must call its reducing
# fn with no args to make sure values flow. Similarly when a computation is
# finished (no more input values will be presented) a stateful transducer might
# have extra data to flush from its state to the reducing function. But every
# transducer must deal with this possibility, even though the majority to not
# keep state that must be dealt with in this way. Finally, there are situations
# where transduction can detect early termination conditions --- say we're
# multiplying a long sequence of numbers and see a zero --- and so every
# transducer must deal with this scenario and short-circuit. Sometimes a
# transducer will have something to add on short-circuit, but again most will
# not.
#
# So the problem before us is to construct a runtime that separates the 4 main
# components of transduction and provides hooks for flushing, short-circuiting,
# etc., but handles them mostly automatically.
#
# The method taken in Clojure of a transducer being a function that given a
# reducer, returns a function with 3 arities to handle different cases is well
# optimised for the JVM (avoids boxing, static call sites, etc.). However, for
# our purposes it will simplify things if we separate transformation from
# aggregation.
#
# A reducer is something that folds. This is a known entity. If a reducer is
# given no arguments, it returns the identity. As a degenerate case we can
# assume that all reducers, given just a collection and nothing to add to it,
# return the collection unchanged.
#
# The reducer is applied directly to a stream of values. It isn't called by
# transducers, so transducers don't need to know about short circuiting. There
# does need to be back pressure though so that when a reducer short circuits,
# any computations feeding it are also terminated.
#
# A transducer is just a stream transformer. That is for every value in the
# input stream, a transducer puts zero or more values into the output stream.
#
# For now we're going to model this as always returning a list and hope we can
# avoid boxing and extra allocation by compiler shennanigans.
#
# But this looses composbility which is one of the most valuable aspects of
# transducers, so we're back to the drawing board.
abstract type Reducer end

abstract type Transducer end

abstract type SimpleTransducer <: Transducer end

struct MapTransducer <: SimpleTransducer
    fn
end

struct FilterTransducer <: SimpleTransducer
    fn
end


"""Represents a binary operation with identity"""
struct MonoidReducer <: Reducer
    identity
    fn
end

conj = MonoidReducer([], (acc, next) ->
                     begin
                     acc2 = copy(acc)
                     push!(acc2, next)
                     return acc2
                     end)

function map(f)
    x -> emit(f(x))
end

function filter(p)
    x -> if p(x) === true emit(x) end
end

function identity(rf::MonoidReducer)
    rf.identity
end

function flush(rf::MonoidReducer, acc)
    acc
end

function flush(t::Any, acc)
    acc
end

function apply(rf::MonoidReducer, acc, next)
    rf.fn(acc, next)
end

function apply(t::MapTransducer, rf::Reducer, acc, next)
    apply(rf, acc, t.fn(next))
end

function apply(t::FilterTransducer, rf::Reducer, acc, next)
    if t.fn(next) === true
        apply(rf, acc, next)
    else
        acc
    end
end

function transducer(t::Transducer)
    function (rf)
        function inner()
            monoididentity(rf)
        end
        function inner(acc)
            flush(rf, acc)
        end
        function inner(acc, next)
            apply(t, rf, acc, next)
        end
        return inner
    end
end

function runsimple(in, out, f, choice)
    while true
        x = take!(in)
        if x === nothing
            break
        end
        put!(out, choice(f, x))
    end
end
