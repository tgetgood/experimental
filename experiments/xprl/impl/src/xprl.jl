module xprl

struct Form
  env
  element::Vector
end

##### REPL

# text input is directly (not via any executor) passed to ??? with the return
# and error channels bound to stdout and stderr.

#### Reader

# Do I implement datastructures before I implement the reader? Well I already
# have a halfway decent implementation, but am I going to tie myself down if I
# use it?

# once a form has been read, it will be passed to `compilesend` (name needs
# work), which will break the form into a series of receivers and link them
# together appropriately.

# the initial message to set off the whole graph will then be enqueued on an
# executor. It will be pushed to the bottom of the work dequeue so that new work
# doesn't prevent old work from completing.

end # module xprl
