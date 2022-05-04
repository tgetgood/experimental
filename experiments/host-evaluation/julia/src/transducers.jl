abstract type Transducer end

struct SimpleTransducer <: Transducer
    input::AbstractChannel
    output::AbstractChannel
    fn
    task::Task
end

function runsimple(in, out, f)
    while true 
        x = take!(in)
        if x === nothing
            break
        end
        put!(out, f(x))
    end
end

function mapt(f)
    in = Channel()
    out = Channel()
    t = Task(() -> runsimple(in, out, f))
    schedule(t)
    SimpleTransducer(in, out, f, t)
end

    
