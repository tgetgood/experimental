# Scheduling and task coordination

xprlIO = Dict(
    keyword("stdout") => println,
    keyword("stderr") => x -> @error x,
    keyword("stdin") => nil
)

function task(f, args...)
    schedule(Task(() -> f(args...)))
end
