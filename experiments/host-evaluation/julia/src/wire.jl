# Before we start, a question: Do we need a binary wire format? We need a
# textual format with which to interact with humans, and we need an in-memory
# binary format to compute on, but do we need a third aspect to this
# isomorphism?
#
# With prefix caching + gzip, we can get pretty good performance. We can even
# allow agents to negotiate on tags. We can have an unbounded set of tags since
# we're not restricted to single byte words.
