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

##### Example transducers that should play nicely together

function map(f)
    function (emit)
        function (x)
            emit(f(x))
        end
    end
end

function filter(p)
    function (emit)
        function (x)
            if p(x) === true
                emit(x)
            else
                emit()
            end
        end
    end
end

function dup()
    function (emit)
        function (x)
            emit(x, x)
        end
    end
end

## Once we start getting into state and pre/post actions, we start needing a new
## form of polymorphism. Something kind of CLOSy: functions that are polymorphic
## based on context of invocation. I don't know how else to put that. There's
## probably a better pattern for this.

## These are marker types that allow us to hack composability into what are
## really maps, by dispatching polymorphically on pseudo-values.
#
# I don't really like this yet, but let's get it working and see if it's even
# something to improve.
struct Post end
struct Pre end

function partition(n)
    state = []
    function (emit)
        function f(x)
            push!(state, x)
            if length(state) === n
                res = copy(state)
                state = []
                emit(res)
            else
                emit()
            end
        end
        # FIXME: This is what I want.
        function f(switch::Post)
            if length(state) > 0
                emit(state)
            else
                emit()
            end
        end
        return f
    end
end

"""Appends xs to the end of transduced stream."""
function append(xs)
    function (emit)
        function f(x)
            emit(x)
        end
        function f(switch::Post)
            emit(xs)
        end
        return f
    end
end

#####
